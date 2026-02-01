# ================================
# Imports
# ================================

import os                     # Leer variables de entorno
from pymongo import MongoClient  # Conexión a MongoDB
import requests               # Llamadas HTTP a API de GitLab
from datetime import datetime, timedelta, timezone  # Manejo de fechas


# ================================
# Variables de entorno (credenciales/configuración)
# Se obtienen desde el contenedor o sistema para no hardcodear secretos
# ================================

DATABASE = os.getenv("DATABASE")
PASSWORD = os.getenv("PASSWORD")
HOST = os.getenv("HOST")
USER = os.getenv("USER")
GITLAB_PASSWORD = os.getenv("GITLAB_PASSWORD")


# ================================
# Diccionarios de traducción
# Se usan para enriquecer los datos y facilitar reportes en Metabase
# ================================

# Número de mes → nombre en español
MONTH_NAMES_ES = {
    1: "Enero",
    2: "Febrero",
    3: "Marzo",
    4: "Abril",
    5: "Mayo",
    6: "Junio",
    7: "Julio",
    8: "Agosto",
    9: "Septiembre",
    10: "Octubre",
    11: "Noviembre",
    12: "Diciembre"
}

# Nombre del día (inglés) → español
DAY_NAMES_ES = {
    "Monday": "Lunes",
    "Tuesday": "Martes",
    "Wednesday": "Miércoles",
    "Thursday": "Jueves",
    "Friday": "Viernes",
    "Saturday": "Sábado",
    "Sunday": "Domingo"
}


# ================================
# Función auxiliar de fechas
# Convierte fecha UTC (GitLab) → hora Argentina (-3)
# Además descompone en campos útiles para BI/Metabase
# ================================

def fecha_3(fecha_UTC_Z):

    # Convierte ISO string (con Z) a datetime UTC
    fecha_UTC_0 = datetime.fromisoformat(fecha_UTC_Z.replace("Z", "+00:00"))

    # Ajusta a zona horaria Argentina (-3h)
    fecha_arg = fecha_UTC_0 - timedelta(hours=3)

    # Extrae componentes temporales
    month_number = fecha_arg.month

    # Día de semana numerado (domingo=1, sábado=7)
    day_number = ((fecha_arg.weekday() + 1) % 7) + 1

    # Semana ISO del año
    week_number = fecha_arg.isocalendar().week

    # Devuelve estructura lista para guardar en Mongo
    return {
        "CreatedAt": fecha_arg.strftime("%Y-%m-%d %H:%M:%S"),
        "Date": fecha_arg.strftime("%Y-%m-%d"),
        "Year": fecha_arg.year,
        "Month": month_number,
        "MonthName": MONTH_NAMES_ES[month_number],
        "Week": week_number,
        "Day": fecha_arg.day,
        "Hour": fecha_arg.hour,
        "DayName": DAY_NAMES_ES[fecha_arg.strftime("%A")],
        "DayNumber": day_number
    }


# Lista donde se almacenarán los registros transformados
salida = []


# ================================
# Conexión a MongoDB
# ================================

mongo_uri = f"mongodb://{USER}:{PASSWORD}@{HOST}:27017/{DATABASE}?authSource=admin"

client = MongoClient(mongo_uri)
db = client[DATABASE]


# ================================
# Obtener último pipeline procesado
# Sirve para procesamiento incremental (evitar reprocesar datos viejos)
# ================================

doc = db.parsedMetrics.find_one(sort=[("CreatedAt", -1)])

if doc and "CreatedAt" in doc:

    fecha = doc["CreatedAt"]

    # Si la fecha está guardada como string, convertir a datetime
    if isinstance(fecha, str):
        fecha = datetime.fromisoformat(fecha.replace("Z", "+00:00"))

    # Asegurar timezone UTC
    if fecha.tzinfo is None:
        fecha = fecha.replace(tzinfo=timezone.utc)

    # Se suma 3h para volver a UTC
    limite = fecha + timedelta(hours=3)

else:
    # Fecha inicial por defecto si es la primera ejecución
    limite = datetime(2026, 1, 23, 0, 0, 0, tzinfo=timezone.utc)

# Se usa luego para búsquedas de pipelines fallidos
limite_mas_3 = limite + timedelta(hours=3)


# ================================
# Traer solo pipelines nuevos desde Mongo
# ================================

registros = list(db.pipelineMetrics.find({"CreatedAt": {"$gte": limite}}))


# ================================
# Cache de proyectos ya conocidos
# Evita reprocesar o repetir proyectos
# ================================

IDs = {
    item["ProjectId"]: {k: v for k, v in item.items() if k != "_id"}
    for item in db.projectsMetrics.find()
}


# ================================
# Procesamiento principal de pipelines
# ================================

for registro in registros:

    # Datos básicos del pipeline
    projectId = registro.get("ProjectId")
    pipelineId = registro.get("PipelineId")
    projectApp = registro.get("Project")
    pipelineName = registro.get("Pipeline")

    # Consulta a GitLab para obtener detalle del pipeline
    url = f"https://gitlab.unc.edu.ar/api/v4/projects/{projectId}/pipelines/{pipelineId}"
    headers = {"Authorization": "Bearer " + GITLAB_PASSWORD}
    data = requests.get(url, headers=headers).json()

    # Si el proyecto ya no existe se elimina de mongo
    if data.get("message") == "404 Project Not Found":
        if projectId in IDs:
            IDs.pop(projectId)
        continue


    # Se transforma la fecha
    f = fecha_3(data["created_at"])


    # ============================
    # Caso 1 → DEPLOY
    # Registra apps habilitadas/actualizadas/deshabilitadas
    # ============================

    if pipelineName == "DEPLOY":

        for enabled in registro.get("EnabledApps", []):
            salida.append({
                "ID": f"{projectId}-{pipelineId}-{enabled.get('app')}",
                "Project": projectApp,
                "Cluster": enabled.get("env"),
                "Status": data.get("status"),
                "CreatedAt": f["CreatedAt"],
                "DurationSeg": data.get("duration"),
                "Action": enabled.get("action"),
                "App": enabled.get("app"),
                "Pipeline": pipelineName,
                **f
            })

        for disabled in registro.get("DisabledApps", []):
            salida.append({
                "ID": f"{projectId}-{pipelineId}-{disabled.get('app')}",
                "Project": projectApp,
                "Cluster": disabled.get("env"),
                "Status": data.get("status"),
                "CreatedAt": f["CreatedAt"],
                "DurationSeg": data.get("duration"),
                "Action": disabled.get("action"),
                "App": disabled.get("app"),
                "Pipeline": pipelineName,
                **f
            })


    # ============================
    # Caso 2 → PUSH-TO-HARBOR
    # Registra creación de imágenes Docker
    # ============================

    elif pipelineName == "PUSH-TO-HARBOR":

        parts = projectApp.split("/")
        Project = parts[-2]
        App = parts[-1]

        # Determina entorno según branch
        ref = data.get("ref")
        env = ref if ref in ("demo", "dev") else "prod"

        for image in registro.get("Images", []):

            # Limpia el nombre de la imagen
            parte = image.split(projectApp)[1].split(":")[0].replace("/", "-")

            salida.append({
                "ID": f"{projectId}-{pipelineId}{parte}",
                "Project": Project,
                "Environment": env,
                "Status": data.get("status"),
                "CreatedAt": f["CreatedAt"],
                "DurationSeg": data.get("duration"),
                "App": App,
                "Image": image,
                "Pipeline": pipelineName,
                **f
            })


    # Se agrega a mongo si es nuevo
    if projectId is not None and projectId not in IDs:
        IDs[projectId] = {
            "PipelineName": pipelineName,
            "ProjectId": projectId,
            "ProjectApp": projectApp
        }


# ================================
# Búsqueda adicional de pipelines fallidos
# Para detectar errores que no quedaron registrados
# ================================

for projectId, info in IDs.items():

    pipelineName = info['PipelineName']
    projectApp = info['ProjectApp']

    url = f"https://gitlab.unc.edu.ar/api/v4/projects/{projectId}/pipelines?status=failed&created_after={limite_mas_3.isoformat()}"
    pipelinesFailed = requests.get(url, headers=headers).json()

    for pipeline in pipelinesFailed:

        detailUrl = f"https://gitlab.unc.edu.ar/api/v4/projects/{projectId}/pipelines/{pipeline['id']}"
        pipelineDetail = requests.get(detailUrl, headers=headers).json()

        f = fecha_3(pipelineDetail["created_at"])


        # Registro de fallos
        if pipelineName == "DEPLOY":
            salida.append({
                "ID": f"{projectId}-{pipeline['id']}",
                "Project": projectApp,
                "Status": pipelineDetail.get("status"),
                "Pipeline": pipelineName,
                **f
            })

        elif pipelineName == "PUSH-TO-HARBOR":

            Project = projectApp.split("/")[-2]
            app = pipelineDetail["web_url"].split("/-/")[0].split("/")[-1]

            ref = data.get("ref")
            env = ref if ref in ("demo", "dev") else "prod"

            salida.append({
                "ID": f"{projectId}-{pipeline['id']}",
                "Project": Project,
                "Environment": env,
                "Status": pipelineDetail.get("status"),
                "App": app,
                "Pipeline": pipelineName,
                **f
            })


# ================================
# Guardado final en Mongo
# ================================

parsed = db.parsedMetrics

# Inserta solo si no existe (evita duplicados)
for item in salida:
    if not parsed.find_one({"ID": item["ID"]}):
        parsed.insert_one(item)


# Guarda proyectos procesados
parsed = db.projectsMetrics

for key, item in IDs.items():
    if not parsed.find_one({"ProjectId": item["ProjectId"]}):
        parsed.insert_one(item)
