#!/bin/bash

ls charts > repo_charts
echo "" >> repo_charts

cd charts || exit 1

while IFS= read -r LINE; do
    echo "-"
    if [ -n "$LINE" ]; then

        cd "$LINE" || exit 1
        echo "[INFO] helm package"
        helm_cmd=$(helm package .)

        filename=$(echo "$helm_cmd" | awk -F'/' '{print $NF}')
        if [[ $filename =~ ^([^[:digit:]]+)-([[:digit:].]+)\.tgz$ ]]; then 
            chart_name="${BASH_REMATCH[1]}"
            chart_version="${BASH_REMATCH[2]}"
        else
            echo "[ERROR] Invalid filename format: $filename"
            exit 1
        fi

        echo "[INFO] Subiendo $chart_name-$chart_version"

        request="https://chartmuseum.domain/api/charts/$chart_name/$chart_version"

        response=$(curl -s "$request")
        if [[ $response == *'{"error":'* ]]; then
            echo "[INFO] $chart_name-$chart_version no existia. Se sube."
        else 
            echo "[INFO] Se actualiza $chart_name-$chart_version"

            response=$(curl -s -X DELETE \
            -u "$user:$pass" "https://chartmuseum.domain/api/charts/$chart_name/$chart_version")

            if [[ $? != 0 || $response == *'{"error":'* ]]; then
                echo "[ERROR] no se pudo borrar el chart viejo: $response"
                exit 1
            fi 
        fi

        response=$(curl -s -X POST \
        --data-binary  "@$filename" \
        -u "$user:$pass" https://chartmuseum.domain/api/charts)

        if [[ $? != 0 || $response == *"error"* ]]; then
            echo "[ERROR] no se pudo subir el chart: $response"
            exit 1
        fi 

        cd ..

        echo "-"
    fi 
          
done < ../repo_charts   

echo "-"
echo "[INFO] Charts updated"
