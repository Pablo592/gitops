{{- define "base_webserver.deploy-body" -}}
- name: {{ .name }}
  image: {{ .imageName }}:{{ .imageTag }}
  imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}

  {{- if or (and .Values.allowExecutionWithRoot (not .Values.allowExecutionWithRoot.enabled)) (not .Values.allowExecutionWithRoot) }}
  securityContext:
      runAsNonRoot: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
  {{- end }}



  {{- if .command }}
  {{- if .commandEnabled }}
  command:
    - "{{ .command.container_shell }}"
    - "-c"
  args:
{{ toYaml .command.args | nindent 4 }}
  {{- end }}
  {{- end }}

  {{- if .Values.ports }}
  ports:
    - name: {{ .name }}
      containerPort: {{ .targetPort }}
  {{- end }}

  {{- if or (and .Values.env .Values.env.enabled) (and .Values.secrets .Values.secrets.enabled) }}
  env:
    {{- if and .Values.env .Values.env.enabled .Values.env.list }}
    {{- range .Values.env.list }}
    - name: {{ .name }}
      value: {{ .value | quote }}
    {{- end }}
    {{- end }}

    {{- if and .Values.secrets .Values.secrets.enabled .Values.secrets.list }}
    {{- range .Values.secrets.list }}
      {{- $secretName := include "base_webserver.sanitizeName" (printf "%s-secret" .path )}}
    - name: {{ .name }}
      valueFrom:
        secretKeyRef:
          name: {{ $secretName }}
          key: {{ .key }}
    {{- end }}
    {{- end }}
  {{- end }}

  {{- if and .Values.environmentFromSecret .Values.environmentFromSecret.enabled .Values.environmentFromSecret.list }}
  envFrom:
    {{- range .Values.environmentFromSecret.list }}
      {{- $secretBase := include "base_webserver.sanitizeName" (printf "%s-secret" .path) }}
    - secretRef:
        name: {{ $secretBase }}
    {{- end }}
  {{- end }}

  {{- if or (and .Values.volumes .Values.volumes.enabled) 
            (and .Values.configMaps .Values.configMaps.enabled) 
            (and .Values.fileFromSecret .Values.fileFromSecret.enabled)
            (and .Values.podWritePermissions .Values.podWritePermissions.enabled) }}
  volumeMounts:
    {{- if and .Values.volumes .Values.volumes.enabled .Values.volumes.list }}
      {{- range $vol := .Values.volumes.list }}
        {{- $mountsJoined := join "-" $vol.mounts }}
        {{- $volName := include "base_webserver.sanitizeName" (printf "%s-%s-%s-pvc" $.Values.project $mountsJoined $vol.size) }}
        {{- range $mount := $vol.mounts }}
    - name: {{ $volName }}
      subPath: {{ base $mount }}
      mountPath: {{ $mount }}
        {{- end }}
      {{- end }}
    {{- end }}

    {{- if and .Values.podWritePermissions .Values.podWritePermissions.enabled .Values.podWritePermissions.paths }}
      {{- range .Values.podWritePermissions.paths }}
      {{- $volName := include "base_webserver.sanitizeName" (printf "%s" .) }}
    - name: {{ $volName }}
      mountPath: {{ . }}
      {{- end }}
    {{- end }}

    {{- if and .Values.configMaps .Values.configMaps.enabled .Values.configMaps.list }}
      {{- range .Values.configMaps.list }}
        {{- $cmName := include "base_webserver.sanitizeName" (printf "cfmap-%s-%s" .path .name) }}
    - name: {{ $cmName }}
      mountPath: {{ .path }}/{{ .name }}
      subPath: {{ .name }}
      {{- end }}
    {{- end }}

  {{- if and .Values.fileFromSecret .Values.fileFromSecret.enabled .Values.fileFromSecret.list }}
    {{- range .Values.fileFromSecret.list }}
      {{- $volName := include "base_webserver.sanitizeName" (printf "%s-%s-%s" .path .secretKey .fileName) }}
    - name: {{ $volName }}
      mountPath: {{ .mount }}/{{ .fileName }}
      subPath: {{ .fileName }}
      readOnly: true
    {{- end }}
  {{- end }}
  {{- end }}

  {{- if and .Values.probes .Values.probes.enabled }}
  startupProbe:
    httpGet:
      path: {{ .Values.probes.startup.path }}
      port: {{ .Values.port.port }}
    periodSeconds: {{ .Values.probes.startup.periodSeconds }}
    failureThreshold: {{ .Values.probes.startup.failureThreshold }}

  livenessProbe:
    httpGet:
      path: {{ .Values.probes.liveness.path }}
      port: {{ .Values.port.port }}
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
{{- end }}
