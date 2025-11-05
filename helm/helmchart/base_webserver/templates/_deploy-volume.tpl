{{- define "base_webserver.deploy-volume" -}}

  {{- if or (and .Values.volumes .Values.volumes.enabled) 
            (and .Values.configMaps .Values.configMaps.enabled) 
            (and .Values.fileFromSecret .Values.fileFromSecret.enabled)
            (and .Values.podWritePermissions .Values.podWritePermissions.enabled) }}
volumes:
    {{- if and .Values.volumes .Values.volumes.enabled .Values.volumes.list }}
      {{- range $vol := .Values.volumes.list }}
        {{- $mountsJoined := join "-" $vol.mounts }}
        {{- $volName := include "base_webserver.sanitizeName" (printf "%s-%s-%s-pvc" $.Values.project $mountsJoined $vol.size) }}
    - name: {{ $volName }}
      persistentVolumeClaim:
        claimName: {{ $volName }}
      {{- end }}
    {{- end }}

  {{- if and .Values.fileFromSecret .Values.fileFromSecret.enabled .Values.fileFromSecret.list }}
    {{- range .Values.fileFromSecret.list }}
      {{- $volName := include "base_webserver.sanitizeName" (printf "%s-%s-%s" .path .secretKey .fileName) }}
      {{- $volSecret := include "base_webserver.sanitizeName" (printf "%s-secret" .path) }}
    - name: {{ $volName }}
      secret:
        secretName: {{ $volSecret }}
        items:
          - key: {{ .secretKey }}
            path: {{ .fileName }}
      {{- end }}
    {{- end }}
  {{- if and .Values.podWritePermissions .Values.podWritePermissions.enabled .Values.podWritePermissions.paths }}
    {{- range .Values.podWritePermissions.paths }}
      {{- $volName := include "base_webserver.sanitizeName" (printf "%s" .) }}
    - name: {{ $volName }}
      emptyDir: {}
      {{- end }}
    {{- end }}
    {{- if and .Values.configMaps .Values.configMaps.enabled .Values.configMaps.list }}
      {{- range .Values.configMaps.list }}
        {{- $cmName := include "base_webserver.sanitizeName" (printf "cfmap-%s-%s" .path .name) }}
        {{- $cmRef := include "base_webserver.sanitizeName" (printf "%s-%s" .path .name) }}
    - name: {{ $cmName }}
      configMap:
        name: {{ $cmRef }}
        defaultMode: {{ .chmod | default "0755" }}
        items:
          - key: {{ .name }}
            path: {{ .name }}
      {{- end }}
    {{- end }}
{{- end }}

{{- end }}
