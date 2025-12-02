#!/bin/bash

# Encabezado para indicar el inicio del proceso
echo "Generando listado de grupos..."

# Obtiene la lista de grupos y la guarda en groups.txt
gcloud identity groups search \
    --organization="713468743428" \
    --labels="cloudidentity.googleapis.com/groups.discussion_forum" \
    --page-size=1000 \
    --format="value(groups.groupKey.id)" > groups.txt

# Crea el archivo CSV con los encabezados
echo "Grupo,Correo" > Groups_members.csv

# Lee el archivo groups.txt línea por línea
while IFS= read -r GRUPO; do

    # --- INICIO DE LA CORRECCIÓN ---
    # Si la línea leída (GRUPO) está vacía, sáltala y ve a la siguiente.
    if [ -z "${GRUPO}" ]; then
        continue
    fi
    # --- FIN DE LA CORRECCIÓN ---

    echo "Procesando grupo: ${GRUPO}"

    # Obtiene la lista COMPLETA de miembros UNA SOLA VEZ por grupo
    MEMBERS=$(gcloud beta identity groups memberships list --group-email="${GRUPO}" --format="json(memberKey.id)")
    
    # Cuenta los miembros usando jq sobre la variable (muy rápido)
    COUNT=$(echo "${MEMBERS}" | jq 'length')

    # Si el conteo es mayor a 200, imprime un mensaje y salta al siguiente grupo
    if [ "${COUNT}" -gt 200 ]; then
        echo "SALTANDO: El grupo ${GRUPO} tiene ${COUNT} miembros (límite 200)."
        continue # 'continue' pasa a la siguiente iteración del bucle while
    fi

    # Si el conteo es mayor a 0 (y menor o igual a 200)
    if [ "${COUNT}" -gt 0 ]; then
        echo "-> Encontrados ${COUNT} miembros. Exportando..."
        # Usa jq para formatear la salida eficientemente y la añade al CSV
        echo "${MEMBERS}" | jq -r --arg group "${GRUPO}" '.[] | "\($group),\(.memberKey.id)"' >> Groups_members.csv
    else
        # Si el grupo no tiene miembros
        echo "-> Grupo vacío."
        echo "${GRUPO},Vacio" >> Groups_members.csv
    fi
   
done < groups.txt

echo ".....Proceso Terminado."