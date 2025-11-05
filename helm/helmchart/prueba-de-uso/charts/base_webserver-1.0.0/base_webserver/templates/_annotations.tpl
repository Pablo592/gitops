{{- define "base_webserver.annotations" -}}
annotations:
  area: {{ .area | default "psi" | quote }}
{{- $vals := .annotation -}}
{{- if and $vals $vals.enabled -}}
{{- range $key, $value := $vals.list }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end }}
