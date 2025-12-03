#!/bin/bash

# --- Configuración ---
declare -a PROJECTS=(
    "daf-dp-refined-prod"       
)
# Nombre del archivo de salida CSV.
OUTPUT_FILE="permisos_bigquery_alineado.csv"

# Archivos temporales
TEMP_INHERITED="temp_inherited_perms.txt"
TEMP_JSON_POLICY="temp_policy_raw.json"

# --- Lógica del Script ---

# Escribe la cabecera del CSV.
# Orden esperado: 1.Proyecto, 2.Dataset, 3.TipoPermiso, 4.TipoCuenta, 5.Correo, 6.Rol, 7.EntidadAplicada
echo "Proyecto,Dataset,TipoDePermiso,TipoCuenta,Correo,Rol,EntidadAplicada" > "$OUTPUT_FILE"

for project_id in "${PROJECTS[@]}"
do
  echo "========================================================================"
  echo "PROCESANDO PROYECTO: $project_id"
  echo "========================================================================"

  if ! gcloud config set project "$project_id" 2>/dev/null; then
    echo "  Error: No se pudo acceder al proyecto $project_id."
    continue
  fi

  # Limpiamos el acumulador
  > "$TEMP_INHERITED"

  # --- 1. CAPTURAR PERMISOS HEREDADOS (ORGANIZACIÓN Y FOLDERS) ---
  echo "  -> Analizando jerarquía (Organización/Carpetas)..."
  
  gcloud projects get-ancestors "$project_id" --format=json | jq -c '.[]' | while read -r ancestor; do
    ancestor_type=$(echo "$ancestor" | jq -r '.type')
    ancestor_id=$(echo "$ancestor" | jq -r '.id')

    if [ "$ancestor_type" = "project" ]; then
      continue
    fi

    echo "     -> Revisando: $ancestor_type $ancestor_id"
    rm -f "$TEMP_JSON_POLICY"

    if [ "$ancestor_type" = "organization" ]; then
      gcloud organizations get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    elif [ "$ancestor_type" = "folder" ]; then
      gcloud resource-manager folders get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    fi

    if [ -s "$TEMP_JSON_POLICY" ]; then
      # A) Guardar en CSV general (Orden corregido)
      jq -r --arg project "$project_id" --arg origin "$ancestor_type/$ancestor_id" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", ($member | split(":"))[0], ($member | split(":"))[1], .role, $origin] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"

      # B) Guardar en temporal para replicar (Formato interno: Origin|Type|Email|Role)
      jq -r --arg origin "$ancestor_type/$ancestor_id" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | "\($origin)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role' "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
    fi
  done


  # --- 2. CAPTURAR PERMISOS A NIVEL DE PROYECTO ---
  echo "  -> Analizando permisos del Proyecto..."
  
  rm -f "$TEMP_JSON_POLICY"
  gcloud projects get-iam-policy "$project_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
  
  if [ -s "$TEMP_JSON_POLICY" ]; then
      # A) CSV General (Orden corregido: TipoCuenta, Email, Rol, Entidad)
      jq -r --arg project "$project_id" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", ($member | split(":"))[0], ($member | split(":"))[1], .role, "project/" + $project] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"

      # B) Temporal
      jq -r --arg project "$project_id" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | "project/\($project)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role' "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
  fi


  # --- 3. CAPTURAR DATASETS ---
  datasets=$(bq ls -n 10000 --project_id="$project_id" 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -v '^bq_read_all')

  if [ -n "$datasets" ]; then
      for dataset_id in $datasets
      do
        echo "     -> Dataset: $dataset_id"
        
        # 3.1 Directos (Orden corregido)
        rm -f "$TEMP_JSON_POLICY"
        bq show --format=prettyjson "$project_id:$dataset_id" > "$TEMP_JSON_POLICY" 2>/dev/null

        if [ -s "$TEMP_JSON_POLICY" ]; then
            jq -r --arg project "$project_id" --arg dataset "$dataset_id" \
            '.access[] | . as $item | {principal: (if .iamMember then .iamMember elif .userByEmail then ("user:"+.userByEmail) elif .groupByEmail then ("group:"+.groupByEmail) elif .domain then ("domain:"+.domain) else "unknown:N/A" end)} | [$project, $dataset, "DIRECTO", (.principal | split(":"))[0], (.principal | split(":"))[1], $item.role, "dataset/" + $dataset] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"
        fi

        # 3.2 Inyectados (AQUÍ ESTABA EL ERROR PRINCIPAL)
        if [ -f "$TEMP_INHERITED" ]; then
            while IFS='|' read -r i_origin i_type i_email i_role; do
                # Orden corregido: ... TipoCuenta, Correo, Rol, EntidadAplicada
                echo "\"$project_id\",\"$dataset_id\",\"HEREDADO ($i_origin)\",\"$i_type\",\"$i_email\",\"$i_role\",\"$i_origin\"" >> "$OUTPUT_FILE"
            done < "$TEMP_INHERITED"
        fi
      done
  fi

done

rm -f "$TEMP_INHERITED" "$TEMP_JSON_POLICY"

echo ""
echo "========================================================================"
echo "✅ Finalizado. Columnas alineadas correctamente en: $OUTPUT_FILE"
echo "========================================================================"