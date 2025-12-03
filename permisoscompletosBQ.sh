#!/bin/bash

# --- Configuración ---
declare -a PROJECTS=(
    "daf-dp-trusted-prod"       
)
# Nombre del archivo de salida CSV.
OUTPUT_FILE="permisos_bigquery_expandido.csv"

# Archivos temporales
TEMP_INHERITED="temp_inherited_perms.txt"
TEMP_JSON_POLICY="temp_policy_raw.json"

# --- Lógica del Script ---

# Escribe la cabecera del CSV.
echo "Proyecto,Dataset,TipoDePermiso,TipoCuenta,Correo,Rol,EntidadAplicada" > "$OUTPUT_FILE"

for project_id in "${PROJECTS[@]}"
do
  echo "========================================================================"
  echo "PROCESANDO PROYECTO: $project_id"
  echo "========================================================================"

  # Intentamos setear el proyecto, si falla continuamos con el siguiente
  if ! gcloud config set project "$project_id" 2>/dev/null; then
    echo "  Error: No se pudo acceder al proyecto $project_id o no existe."
    continue
  fi

  # Limpiamos el archivo temporal de herencia al inicio de cada proyecto
  > "$TEMP_INHERITED"

  # --- 1. CAPTURAR PERMISOS HEREDADOS DE LA JERARQUÍA (ORGANIZACIÓN Y FOLDERS) ---
  echo "  -> Obteniendo ancestros (folders, organización)..."
  
  gcloud projects get-ancestors "$project_id" --format=json | jq -c '.[]' | while read -r ancestor; do
    ancestor_type=$(echo "$ancestor" | jq -r '.type')
    ancestor_id=$(echo "$ancestor" | jq -r '.id')

    if [ "$ancestor_type" = "project" ]; then
      continue
    fi

    echo "  -> Analizando herencia de: $ancestor_type $ancestor_id"
    
    # Limpiamos el archivo temporal JSON antes de usarlo
    rm -f "$TEMP_JSON_POLICY"

    # CORRECCION: Guardar salida en archivo en lugar de variable para evitar errores de parseo
    if [ "$ancestor_type" = "organization" ]; then
      gcloud organizations get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    elif [ "$ancestor_type" = "folder" ]; then
      gcloud resource-manager folders get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    fi

    # Verificamos si el archivo existe y tiene contenido (no está vacío)
    if [ -s "$TEMP_JSON_POLICY" ]; then
      # Procesamos directamente el archivo con jq
      
      # A) Guardar en CSV general
      jq -r --arg project "$project_id" --arg origin "$ancestor_type/$ancestor_id" \
      '.bindings[] | select(.role | contains("bigquery")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", $origin, ($member | split(":"))[0], ($member | split(":"))[1], .role] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"

      # B) Guardar en archivo temporal para replicar
      jq -r --arg origin "$ancestor_type/$ancestor_id" \
      '.bindings[] | select(.role | contains("bigquery")) | .members[] as $member | "\($origin)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role' "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
    fi
  done


  # --- 2. CAPTURAR PERMISOS A NIVEL DE PROYECTO ---
  echo "  -> Obteniendo permisos a nivel de proyecto..."
  
  # Usamos el mismo archivo temporal para el proyecto
  rm -f "$TEMP_JSON_POLICY"
  gcloud projects get-iam-policy "$project_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
  
  if [ -s "$TEMP_JSON_POLICY" ]; then
      # A) Guardar en CSV general
      jq -r --arg project "$project_id" \
      '.bindings[] | select(.role | contains("bigquery")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", "project/" + $project, ($member | split(":"))[0], ($member | split(":"))[1], .role] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"

      # B) Guardar en archivo temporal para replicar
      jq -r --arg project "$project_id" \
      '.bindings[] | select(.role | contains("bigquery")) | .members[] as $member | "project/\($project)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role' "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
  fi

  # --- 3. CAPTURAR PERMISOS DIRECTOS POR DATASET + INYECTAR HEREDADOS ---
  datasets=$(bq ls -n 10000 --project_id="$project_id" 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -v '^bq_read_all')

  # Si datasets está vacío, no entramos al loop, pero igual se generaron los heredados arriba
  if [ -n "$datasets" ]; then
      for dataset_id in $datasets
      do
        echo "  -> Analizando dataset: $dataset_id"
        
        # Usamos temp json para dataset también por consistencia
        rm -f "$TEMP_JSON_POLICY"
        bq show --format=prettyjson "$project_id:$dataset_id" > "$TEMP_JSON_POLICY" 2>/dev/null

        if [ -s "$TEMP_JSON_POLICY" ]; then
            # 3.1 Permisos Directos
            jq -r --arg project "$project_id" --arg dataset "$dataset_id" \
            '.access[] | . as $item | {principal: (if .iamMember then .iamMember elif .userByEmail then ("user:"+.userByEmail) elif .groupByEmail then ("group:"+.groupByEmail) elif .domain then ("domain:"+.domain) else "unknown:N/A" end)} | [$project, $dataset, "DIRECTO", "dataset/" + $dataset, (.principal | split(":"))[0], (.principal | split(":"))[1], $item.role] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"
        fi

        # 3.2 Inyectar permisos heredados (Org/Project) en este dataset
        if [ -f "$TEMP_INHERITED" ]; then
            while IFS='|' read -r i_origin i_type i_email i_role; do
                # Escribimos en el CSV forzando el nombre del dataset actual
                echo "\"$project_id\",\"$dataset_id\",\"HEREDADO ($i_origin)\",\"$i_origin\",\"$i_type\",\"$i_email\",\"$i_role\"" >> "$OUTPUT_FILE"
            done < "$TEMP_INHERITED"
        fi
      done
  else
      echo "  -> No se encontraron datasets en este proyecto o no se tienen permisos para listarlos."
  fi

done

# Limpieza final
rm -f "$TEMP_INHERITED"
rm -f "$TEMP_JSON_POLICY"

echo ""
echo "========================================================================"
echo "✅ Análisis completado."
echo "Los resultados están en: $OUTPUT_FILE"
echo "========================================================================"