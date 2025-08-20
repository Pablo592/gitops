{{- define "base_webserver.deploy-body" -}}
- name: {{ .name }}
  image: {{ .Values.image.name }}:{{ .Values.image.tag }}
  imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}

  {{- if .Values.command }}
  command:
    - "{{ .Values.command.container_shell }}"
    - "-c"
  args:
  {{- toYaml .Values.command.args | nindent 4 }}

  {{- end }}

    {{- if .Values.ports }}
  ports:
    - name: {{ .name }}
      containerPort: {{ .targetPort }}
    {{- end }}


    {{- if .Values.env }}
  env:
      {{- range .Values.env }}
    - name: {{ .name }}
      value: {{ .value | quote }}
      {{- end }}
    {{- end }}

    {{- if .Values.environmentFromSecret }}
  envFrom:
      {{- range .Values.environmentFromSecret }}
    - secretRef:
        name: {{ .path | trimPrefix "/" | replace "/" "-" | replace "_" "-" | lower }}-secret
      {{- end }}
    {{- end }}
    {{- if or .Values.volumes .Values.configMaps .Values.fileFromSecret }}
  volumeMounts:
      {{- range .Values.volumes }}
    - name: volume{{ .mount | replace "/" "-" }}
      mountPath: {{ .mount }}
      {{- end }}
      {{- range .Values.configMaps }}
    - name: cfmap-{{ .name | replace "." "-" }}
      mountPath: {{ .path }}
      {{- end }}
      {{- range .Values.fileFromSecret }}
    - name: {{ .path | trimPrefix "/" | replace "/" "-" | replace "_" "-" | lower }}-{{ .secretKey | replace "/" "-" }}
      mountPath: {{ .mount }}
      readOnly: true
      {{- end }}
    {{- end }}

  {{- if .Values.resources }}
  resources:
    requests:
      cpu: {{ .Values.resources.requests.cpu | quote }}
      memory: {{ .Values.resources.requests.memory | quote }}
    limits:
      cpu: {{ .Values.resources.limits.cpu | quote }}
      memory: {{ .Values.resources.limits.memory | quote }}
  {{- end }}

  {{- if or .Values.volumes .Values.configMaps .Values.fileFromSecret }}
volumes:
    {{- range .Values.volumes }}
  - name: volume{{ .mount | replace "/" "-" }}
    persistentVolumeClaim:
      claimName: {{ $.name }}-{{ .mount | replace "/" "-" }}-pvc
    {{- end }}
    
    {{- range .Values.fileFromSecret }}
  - name: {{ .path | trimPrefix "/" | replace "/" "-" | replace "_" "-" | lower }}-{{ .secretKey | replace "/" "-" }}
    secret:
      secretName: {{ .path | trimPrefix "/" | replace "/" "-" | replace "_" "-" | lower }}-secret
      items:
       - key: {{ .secretKey }}
         path: {{ .fileName }}
    {{- end }}
    {{- range .Values.configMaps }}
  - name: cfmap-{{ .name | replace "." "-" }}
    configMap:
      name: cfmap{{ .path | replace "/" "-" }}-{{ .name | replace "." "-" }}
      defaultMode: {{ .chmod | default 493 }}
    {{- end }}
  {{- end }}
{{- end }}
