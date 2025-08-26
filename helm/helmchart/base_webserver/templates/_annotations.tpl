{{- define "base_webserver.annotations" -}}
{{- $vals := .annotation -}}
{{- if and $vals $vals.enabled -}}
annotations:
{{- range $key, $value := $vals.list }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end -}}
{{- end }}
