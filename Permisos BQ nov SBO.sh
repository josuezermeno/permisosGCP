#!/bin/bash

# --- Configuración ---
# Agrega aquí la lista de tus IDs de proyecto de GCP separados por un espacio.
# Ejemplo: PROJECTS="mi-proyecto-1 mi-proyecto-2 mi-proyecto-3"

declare -a PROJECTS=(



    "spin-datalake-prd-trusted"
    "spin-datalake-prd-refined"
    "spin-datalake-prd-landing"
    "spin-datalake-prd-raw"
    "spin-datalake-dev-trusted"
    "spin-datalake-dev-refined"
    "spin-datalake-dev-landing"
    "spin-datalake-dev-raw"
    "spin-datalake-qas-trusted"
    "spin-datalake-qas-refined"
    "spin-datalake-qas-landing"
    "spin-datalake-qas-raw"
    "spin-bigquery-dev"
    "spin-bigquery-prod"

    "spin-dp-raw-prod"
    "spin-dp-raw-qa"
    "spin-dp-raw-dev"
    "spin-dp-refined-prod"
    "spin-dp-refined-qa"
    "spin-dp-refined-dev"
 
    "spin-dp-landing-prod"
    "spin-dp-landing-qa"
    "spin-dp-landing-dev"
  
    "spin-dp-trusted-prod"
    "spin-dp-trusted-qa"
    "spin-dp-trusted-dev"

    "spin-dp-semantic-layer-dev"
    "spin-dp-semantic-layer-prod"
    "spin-dp-semantic-layer-qa"
    "spin-dp-management-prod"
    "spin-dp-management-qa"
    "spin-dp-management-dev"

    "spin-dp-compute-dev"
    "spin-dp-compute-prod"
    "spin-dp-compute-qa"
 
    "spin-dp-sandbox"     
    "spin-dp-datasharing-prod"
    "spin-dp-datasharing-dev"
    "spin-dp-datasharing-qa"  
    "spin-aip-singularity-comp-prd"
    "spin-aip-singularity-comp-sb"
    "spin-aip-singularity-comp-stg"
    "spin-aip-singularity-data-prd"
    "spin-aip-singularity-data-sb"
    "spin-aip-singularity-data-stg"     
)



# Nombre del archivo de salida CSV.
OUTPUT_FILE="permisos_bigquery_definitivo_sbo.csv"

# --- Lógica del Script ---

# Escribe la cabecera del CSV.
echo "Proyecto,Dataset,TipoDePermiso,TipoCuenta,Correo,Rol,EntidadAplicada" > "$OUTPUT_FILE"

# Itera sobre cada proyecto.

for project_id in "${PROJECTS[@]}"
#for project_id in $PROJECTS

do
  echo "========================================================================"
  echo "PROCESANDO PROYECTO: $project_id"
  echo "========================================================================"

  gcloud config set project "$project_id"

  # --- 1. CAPTURAR PERMISOS HEREDADOS DE LA JERARQUÍA (ORGANIZACIÓN Y FOLDERS) ---
  echo "  -> Obteniendo ancestros (folders, organización)..."
  # Obtiene los ancestros y los procesa con jq para iterar sobre cada uno
  gcloud projects get-ancestors "$project_id" --format=json | jq -c '.[]' | while read -r ancestor; do
    ancestor_type=$(echo "$ancestor" | jq -r '.type')
    ancestor_id=$(echo "$ancestor" | jq -r '.id')

    # Salta el ancestro de tipo "project", ya que se manejará por separado
    if [ "$ancestor_type" = "project" ]; then
      continue
    fi

    echo "  -> Analizando herencia de: $ancestor_type $ancestor_id"
    
    iam_policy=""
    # Elige el comando gcloud correcto según el tipo de ancestro
    if [ "$ancestor_type" = "organization" ]; then
      iam_policy=$(gcloud organizations get-iam-policy "$ancestor_id" --format=json)
    elif [ "$ancestor_type" = "folder" ]; then
      iam_policy=$(gcloud resource-manager folders get-iam-policy "$ancestor_id" --format=json)
    fi

    # Si se obtuvo una política, procésala con jq
    if [ -n "$iam_policy" ]; then
      echo "$iam_policy" | \
      jq -r --arg project "$project_id" --arg origin "$ancestor_type/$ancestor_id" \
      '.bindings[] | select(.role | contains("bigquery")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", $origin, ($member | split(":"))[0], ($member | split(":"))[1], .role] | @csv' >> "$OUTPUT_FILE"
    fi
  done


  # --- 2. CAPTURAR PERMISOS A NIVEL DE PROYECTO ---
  echo "  -> Obteniendo permisos a nivel de proyecto..."
  gcloud projects get-iam-policy "$project_id" --format=json | \
  jq -r --arg project "$project_id" \
  '.bindings[] | select(.role | contains("bigquery")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", "project/" + $project, ($member | split(":"))[0], ($member | split(":"))[1], .role] | @csv' >> "$OUTPUT_FILE"

  # --- 3. CAPTURAR PERMISOS DIRECTOS POR DATASET ---
  datasets=$(bq ls -n 10000 --project_id="$project_id" | tail -n +3 | awk '{print $1}' | grep -v '^bq_read_all')

  for dataset_id in $datasets
  do
    echo "  -> Analizando permisos directos del dataset: $dataset_id"
    bq show --format=prettyjson "$project_id:$dataset_id" | \
    jq -r --arg project "$project_id" --arg dataset "$dataset_id" \
    '.access[] | . as $item | {principal: (if .iamMember then .iamMember elif .userByEmail then ("user:"+.userByEmail) elif .groupByEmail then ("group:"+.groupByEmail) elif .domain then ("domain:"+.domain) else "unknown:N/A" end)} | [$project, $dataset, "DIRECTO", "dataset/" + $dataset, (.principal | split(":"))[0], (.principal | split(":"))[1], $item.role] | @csv' >> "$OUTPUT_FILE"
  done
done

echo ""
echo "========================================================================"
echo "✅ Análisis de jerarquía completa finalizado."
echo "Los resultados han sido guardados en: $OUTPUT_FILE"
echo "========================================================================"
