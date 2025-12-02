#!/bin/bash

# --- Configuración ---
# Agrega aquí la lista de tus IDs de proyecto de GCP separados por un espacio.
# Ejemplo: PROJECTS="mi-proyecto-1 mi-proyecto-2 mi-proyecto-3"
PROJECTS="daf-dp-landing-dev"

# Nombre del archivo de salida CSV.
OUTPUT_FILE="permisos_bigquery.csv"

# --- Lógica del Script ---

# Escribe la cabecera del CSV en el archivo de salida.
# Si el archivo ya existe, se sobrescribirá.
echo "Proyecto,Dataset,Email,Rol,EntidadAplicada" > $OUTPUT_FILE

# Itera sobre cada proyecto definido en la variable PROJECTS.
for project_id in $PROJECTS
do
  echo "========================================================================"
  echo "PROCESANDO PROYECTO: $project_id"
  echo "========================================================================"

  # Establece el proyecto actual para los comandos de gcloud.
  gcloud config set project $project_id

  # Obtiene una lista de todos los datasets en el proyecto actual.
  # El comando 'bq ls' lista los datasets. Usamos 'tail' y 'awk' para limpiar la salida.
  datasets=$(bq ls --project_id=$project_id | tail -n +3 | awk '{print $1}')

  # Itera sobre cada dataset encontrado en el proyecto.
  for dataset_id in $datasets
  do
    echo "  -> Analizando dataset: $dataset_id"

    # Obtiene los metadatos del dataset en formato JSON.
    # 'jq' procesa el JSON para extraer y formatear cada permiso en una línea CSV.
    # Cada línea se añade al archivo de salida.
    bq show --format=prettyjson "$project_id:$dataset_id" | \
    jq -r --arg project "$project_id" --arg dataset "$dataset_id" \
    '.access[] |
     [$project, $dataset, (.userByEmail // .groupByEmail // .iamMember // .domain // "N/A"), .role, (.view.tableId // "DATASET_COMPLETO")] |
     @csv' >> $OUTPUT_FILE
  done
done

echo ""
echo "========================================================================"
echo "✅ Análisis completado."
echo "Los resultados han sido guardados en: $OUTPUT_FILE"
echo "========================================================================"