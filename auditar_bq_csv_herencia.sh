#!/bin/bash

# --- Configuración ---
# Agrega aquí la lista de tus IDs de proyecto de GCP separados por un espacio.
# Ejemplo: PROJECTS="mi-proyecto-1 mi-proyecto-2 mi-proyecto-3"

declare -a PROJECTS=(

    "daf-aip-singularity-comp-prd"
    "daf-aip-singularity-comp-sb"
    "daf-aip-singularity-comp-stg"
    "daf-aip-singularity-data-prd"
    "daf-aip-singularity-data-sb"
    "daf-aip-singularity-data-stg"  
    "daf-dp-raw-prod"
    "daf-dp-raw-qa"
    "daf-dp-raw-dev"
    "daf-dp-raw-sb-dev"
    "daf-dp-raw-sb-qa"
    "daf-dp-refined-prod"
    "daf-dp-refined-qa"
    "daf-dp-refined-dev"
    "daf-dp-refined-sb-dev"
    "daf-dp-refined-sb-qa"
    "daf-dp-landing-prod"
    "daf-dp-landing-qa"
    "daf-dp-landing-dev"
    "daf-dp-landing-sb-dev"
    "daf-dp-landing-sb-qa"
    "daf-dp-trusted-prod"
    "daf-dp-trusted-qa"
    "daf-dp-trusted-dev"
    "daf-dp-trusted-sb-dev"
    "daf-dp-trusted-sb-qa"
    "daf-dp-semantic-layer-dev"
    "daf-dp-semantic-layer-prod"
    "daf-dp-semantic-layer-qa"
    "daf-dp-management-prod"
    "daf-dp-management-qa"
    "daf-dp-management-dev"
    "daf-dp-management-sb-dev"
    "daf-dp-management-sb-qa"
    "daf-dp-compute-dev"
    "daf-dp-compute-prod"
    "daf-dp-compute-qa"
    "daf-dp-compute-sb-dev"
    "daf-dp-compute-sb-qa"
    "daf-dp-sandbox"     
    "daf-dp-datasharing-prod"
    "daf-dp-datasharing-dev"
    "daf-dp-datasharing-qa"       
)

declare -a PROJECTS_test=(

 
    "daf-dp-raw-prod"
    "daf-dp-raw-qa"
    "daf-dp-raw-dev"
)




# Nombre del archivo de salida CSV.
OUTPUT_FILE="permisos_bigquery_definitivo_daf.csv"

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
