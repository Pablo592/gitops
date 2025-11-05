{{- define "base_webserver.path-secret" -}}

apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: {{ include "base_webserver.sanitizeName" (printf "%s-%s-vss" .name .path) }}
  namespace: {{ .namespace }}
spec:
  type: kv-v2
  mount: k8secrets
  path: {{ .path }}
  destination:
    name: {{ include "base_webserver.sanitizeName" (printf "%s-secret" .path) }}
    create: true
  # static secret refresh interval
  refreshAfter: 24h
  # Name of the CRD to authenticate to Vault
  vaultAuthRef: {{ .name }}-auth

{{- end }}
