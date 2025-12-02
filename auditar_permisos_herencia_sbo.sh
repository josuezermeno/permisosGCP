#!/bin/bash

# --- Configuración ---
# Lista de IDs de proyecto de GCP a analizar.
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
    "spin-instances-prod"
    "spin-instances-psb"
    "spin-instances-dev"
    "spin-bigquery-dev"
    "spin-bigquery-prod"
    "spin-datasharing-prd"
    "spin-datasharing-qas"
    "spin-datasharing-dev"
    "spin-instances-qa"
    "spin-data-analytics"
    "spin-bigquery-qas"
    "spin-bigquery-qa"
    "spin-dp-raw-prod"
    "spin-dp-raw-qa"
    "spin-dp-raw-dev"
    "spin-dp-raw-sb-dev"
    "spin-dp-raw-sb-qa"
    "spin-dp-refined-prod"
    "spin-dp-refined-qa"
    "spin-dp-refined-dev"
    "spin-dp-refined-sb-dev"
    "spin-dp-refined-sb-qa"
    "spin-dp-landing-prod"
    "spin-dp-landing-qa"
    "spin-dp-landing-dev"
    "spin-dp-landing-sb-dev"
    "spin-dp-landing-sb-qa"
    "spin-dp-trusted-prod"
    "spin-dp-trusted-qa"
    "spin-dp-trusted-dev"
    "spin-dp-trusted-sb-dev"
    "spin-dp-trusted-sb-qa"
    "spin-dp-semantic-layer-dev"
    "spin-dp-semantic-layer-prod"
    "spin-dp-semantic-layer-qa"
    "spin-dp-management-prod"
    "spin-dp-management-qa"
    "spin-dp-management-dev"
    "spin-dp-management-sb-dev"
    "spin-dp-management-sb-qa"
    "spin-dp-compute-dev"
    "spin-dp-compute-prod"
    "spin-dp-compute-qa"
    "spin-dp-compute-sb-dev"
    "spin-dp-compute-sb-qa"
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
OUTPUT_FILE="permisos_gcp_completo_sbo.csv"

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