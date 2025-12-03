#!/bin/bash

#cambiamos al proyecto default
gcloud config set project daf-dp-management-prod

echo "Generando Listado de grupos...."
gcloud identity groups search     --organization="713468743428"     --labels="cloudidentity.googleapis.com/groups.discussion_forum"  --page-size=100000   --format=json  | jq '.[].groups[].groupKey.id' | sed 's/"//g' > groups_discussion.txt
gcloud identity groups search     --organization="713468743428"     --labels="cloudidentity.googleapis.com/groups.security"  --page-size=100000   --format=json  | jq '.[].groups[].groupKey.id' | sed 's/"//g' > groups_security.txt

cat groups_discussion.txt groups_security.txt | sort | uniq > groups.txt

ARCHIVO="SPIN_MembersByGroup_$(date +%d%b%Y | tr '[:lower:]' '[:upper:]').csv"
echo "Grupo, Correo" > "$ARCHIVO"
while IFS= read -r GRUPO; do


    if [[ -z "${GRUPO}" || "${GRUPO}" == *gws* || "${GRUPO}" == *sbogmail* ]]; then
        if [[ -n "${GRUPO}" ]]; then # Solo imprime si el nombre no está vacío
           echo "SALTANDO: El grupo ${GRUPO} coincide con un criterio de exclusión."
        fi
        continue # Pasa a la siguiente iteración del bucle
    fi

    echo "Generando Listado de: " ${GRUPO}
    TAG_COUNT="`gcloud beta identity groups memberships list --group-email=${GRUPO} --limit=5000 --format=json | jq '.[].memberKey[]' |wc -l`"
    
    if [ "${TAG_COUNT}" -gt 400 ]; then
        echo "SALTANDO: El grupo ${GRUPO} tiene ${TAG_COUNT} miembros (límite 400)."
        continue # 'continue' pasa a la siguiente iteración del bucle while
    fi
    if [ "${TAG_COUNT}" -gt 0 ]
    
    then
        echo "Usuarios encontrados ${TAG_COUNT}"
        for ((i=0; i<$TAG_COUNT; i++)); do
        
            COLUMN2="`gcloud beta identity groups memberships list --group-email=${GRUPO} --limit=5000 --format=json | jq --arg i "${i}" '.[$i|tonumber].memberKey[] '| sed 's/"//g'` "   
            echo "${GRUPO},${COLUMN2} " >> Groups_members.csv
        done
    else
        echo "Grupo Vacio"
        echo "${GRUPO}, Vacio " >> "$ARCHIVO"

    fi
   
done < groups.txt
echo ".....Terminado"

