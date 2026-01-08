{{- define "base_webserver.sanitizeName" -}}
{{- printf "%s" . | trimPrefix "/" | replace "/" "-" | replace "." "-" | replace "_" "-" | lower | trimSuffix "-" | trunc 63  -}}
{{- end }}
