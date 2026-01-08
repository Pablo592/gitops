#!/bin/bash

#login
echo "[INFO] Obteniendo token para Vault"
response=$(curl -s --request POST \
     --data '{"jwt": "'"$VAULT_ID_TOKEN"'", "role": "charts"}' \
     https://<vault-domain>/v1/auth/gitlab/login)

vault_token=$(echo "$response" | jq -r .auth.client_token)

if [[ $vault_token != "hvs."* ]]; then
    echo "[ERROR] no se pudo obtener el token. Probablemente no tienes permisos para ejecutar este pipeline"
    exit 1
fi

echo "[INFO] Obteniendo credenciales de ChartMuseum"
response=$(curl -s \
    -H "X-Vault-Token: $vault_token" \
    https://<vault-domain>/v1/servicios/data/chartmuseum/api-user)

if [[ -z "$response" || "$response" == *'{"errors"'* ]]; then
   error=$(echo "$response" | jq -r .errors[0])
   echo "[ERROR] No se pudieron obtener las credenciales. $error"
   exit 1
fi

user=$(echo "$response" | jq -r .data.data.user)
pass=$(echo "$response" | jq -r .data.data.pass)

echo "user=$user" > creds
echo "pass=$pass" >> creds
