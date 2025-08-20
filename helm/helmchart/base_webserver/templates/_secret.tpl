{{- define "base_webserver.path-secret" -}}

apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: {{ .name }}-{{ .path | trimPrefix "/" | replace "/" "-" | replace "_" "-" | lower }}-vss
  namespace: {{ .namespace }}
spec:
  type: kv-v2
  mount: k8secrets
  path: {{ .path }}
  destination:
    name: {{ .path | trimPrefix "/" | replace "/" "-" | replace "_" "-" | lower }}-secret
    create: true
  # static secret refresh interval
  refreshAfter: 24h
  # Name of the CRD to authenticate to Vault
  vaultAuthRef: {{ .name }}-auth

{{- end }}