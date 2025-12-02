#!/bin/bash

# --- Configuración ---
# Lista de IDs de proyecto de GCP a analizar.
declare -a PROJECTS=(
  "daf-datalake-prd-trusted"
    "daf-datalake-prd-refined"
    "daf-datalake-prd-landing"
    "daf-datalake-prd-raw"
    "daf-datalake-dev-trusted"
    "daf-datalake-dev-refined"
    "daf-datalake-dev-landing"
    "daf-datalake-dev-raw"
    "daf-datalake-qas-trusted"
    "daf-datalake-qas-refined"
    "daf-datalake-qas-landing"
    "daf-datalake-qas-raw"
    "daf-instances-prod"
    "daf-instances-psb"
    "daf-instances-dev"
    "daf-bigquery-dev"
    "daf-bigquery-prod"
    "daf-datasharing-prd"
    "daf-datasharing-qas"
    "daf-datasharing-dev"
    "daf-instances-qa"
    "daf-data-analytics"
    "daf-bigquery-qas"
    "daf-bigquery-qa"
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
    "daf-aip-singularity-comp-prd"
    "daf-aip-singularity-comp-sb"
    "daf-aip-singularity-comp-stg"
    "daf-aip-singularity-data-prd"
    "daf-aip-singularity-data-sb"
    "daf-aip-singularity-data-stg"    
)

# Nombre del archivo de salida CSV.
OUTPUT_FILE="permisos_gcp_completo_daf.csv"

# --- Lógica del Script ---

echo "Proyecto,NivelDePermiso,EntidadAplicada,TipoMiembro,Miembro,Rol" > "$OUTPUT_FILE"

for project_id in "${PROJECTS[@]}"; do
  echo "========================================================================"
  echo "PROCESANDO PROYECTO: $project_id"
  echo "========================================================================"

  if ! gcloud projects describe "$project_id" > /dev/null 2>&1; then
      echo "  -> ❗️ ERROR: No se pudo acceder al proyecto '$project_id'. Saltando..."
      continue
  fi

  gcloud config set project "$project_id"

  # --- 1. CAPTURAR PERMISOS HEREDADOS DE LA JERARQUÍA ---
  echo "  -> Obteniendo ancestros (folders, organización)..."
  gcloud projects get-ancestors "$project_id" --format=json | jq -c '.[]' | while read -r ancestor; do
    ancestor_type=$(echo "$ancestor" | jq -r '.type')
    ancestor_id=$(echo "$ancestor" | jq -r '.id')

    if [ "$ancestor_type" = "project" ]; then
      continue
    fi

    echo "  -> Analizando herencia de: $ancestor_type/$ancestor_id"
    
    iam_policy=""
    # CAMBIO CLAVE: Se añade '2>/dev/null' para suprimir mensajes de error de gcloud.
    if [ "$ancestor_type" = "organization" ]; then
      iam_policy=$(gcloud organizations get-iam-policy "$ancestor_id" --format=json 2>/dev/null)
    elif [ "$ancestor_type" = "folder" ]; then
      iam_policy=$(gcloud resource-manager folders get-iam-policy "$ancestor_id" --format=json 2>/dev/null)
    fi

    # CAMBIO CLAVE: Se comprueba si el comando anterior tuvo éxito (código de salida 0).
    if [ $? -eq 0 ] && [ -n "$iam_policy" ]; then
      echo "$iam_policy" | \
      jq -r --arg project "$project_id" --arg origin "$ancestor_type/$ancestor_id" \
      '.bindings[]? | .members[]? as $member | [$project, "Heredado", $origin, ($member | split(":"))[0], ($member | split(":"))[1], .role] | @csv' >> "$OUTPUT_FILE"
    else
      echo "    -> ⚠️  Advertencia: No se pudo obtener la política IAM para $ancestor_type/$ancestor_id (probablemente por falta de permisos). Saltando."
    fi
  done

  # --- 2. CAPTURAR PERMISOS A NIVEL DE PROYECTO ---
  echo "  -> Obteniendo permisos directos del proyecto..."
  # CAMBIO CLAVE: Añadimos la misma lógica de comprobación de errores aquí.
  project_iam_policy=$(gcloud projects get-iam-policy "$project_id" --format=json 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$project_iam_policy" ]; then
    echo "$project_iam_policy" | \
    jq -r --arg project "$project_id" \
    '.bindings[]? | .members[]? as $member | [$project, "Directo", "project/" + $project, ($member | split(":"))[0], ($member | split(":"))[1], .role] | @csv' >> "$OUTPUT_FILE"
  else
    echo "    -> ❗️ ERROR: No se pudo obtener la política IAM para el proyecto $project_id."
  fi
done

echo ""
echo "========================================================================"
echo "✅ Análisis de jerarquía completa finalizado."
echo "Los resultados han sido guardados en: $OUTPUT_FILE"
echo "========================================================================"