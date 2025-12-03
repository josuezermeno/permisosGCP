#!/bin/bash

# --- Configuración ---
declare -a PROJECTS=(
    "daf-dp-refined-prod"       
)

# Nombre del archivo de salida CSV.
OUTPUT_FILE="permisos_bigquery_nombres_final.csv"

# Archivos temporales
TEMP_INHERITED="temp_inherited_perms.txt"
TEMP_JSON_POLICY="temp_policy_raw.json"
TEMP_NAME_CACHE="temp_name_cache.txt" # Cache basada en archivo para compatibilidad con Mac

# Inicializamos el archivo de caché vacío
> "$TEMP_NAME_CACHE"

# --- FUNCIÓN: Obtener Nombre (Compatible con Bash 3.2 / Mac) ---
function obtener_nombre_amigable() {
    local tipo=$1
    local id=$2
    local cache_key="${tipo}_${id}"
    
    # 1. Buscamos en el archivo de caché usando grep
    # Formato del archivo: clave|nombre_amigable
    local cached_name
    cached_name=$(grep "^${cache_key}|" "$TEMP_NAME_CACHE" | head -n 1 | cut -d'|' -f2)

    if [ -n "$cached_name" ]; then
        echo "$cached_name"
        return
    fi

    local display_name=""

    # 2. Si no está en caché, consultamos a GCP
    if [ "$tipo" = "organization" ]; then
        display_name=$(gcloud organizations describe "$id" --format="value(displayName)" 2>/dev/null)
    elif [ "$tipo" = "folder" ]; then
        display_name=$(gcloud resource-manager folders describe "$id" --format="value(displayName)" 2>/dev/null)
    elif [ "$tipo" = "project" ]; then
        display_name=$(gcloud projects describe "$id" --format="value(name)" 2>/dev/null)
    fi

    # 3. Si falló la consulta, usamos el ID
    if [ -z "$display_name" ]; then
        display_name="$id"
    fi

    # 4. Guardamos en el archivo caché y devolvemos
    local safe_name="${display_name} ($id)"
    echo "${cache_key}|${safe_name}" >> "$TEMP_NAME_CACHE"
    echo "$safe_name"
}

# --- Lógica del Script ---

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

  # Limpiamos el acumulador de herencia para el proyecto actual
  > "$TEMP_INHERITED"

  # --- 1. CAPTURAR PERMISOS HEREDADOS (ORGANIZACIÓN Y FOLDERS) ---
  echo "  -> Analizando jerarquía..."
  
  gcloud projects get-ancestors "$project_id" --format=json | jq -c '.[]' | while read -r ancestor; do
    ancestor_type=$(echo "$ancestor" | jq -r '.type')
    ancestor_id=$(echo "$ancestor" | jq -r '.id')

    if [ "$ancestor_type" = "project" ]; then
      continue
    fi

    # Obtenemos nombre usando la nueva función compatible
    friendly_name=$(obtener_nombre_amigable "$ancestor_type" "$ancestor_id")
    echo "     -> Revisando: $ancestor_type $friendly_name"
    
    rm -f "$TEMP_JSON_POLICY"

    if [ "$ancestor_type" = "organization" ]; then
      gcloud organizations get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    elif [ "$ancestor_type" = "folder" ]; then
      gcloud resource-manager folders get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    fi

    if [ -s "$TEMP_JSON_POLICY" ]; then
      # A) CSV General
      jq -r --arg project "$project_id" --arg origin_label "$ancestor_type/$friendly_name" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", ($member | split(":"))[0], ($member | split(":"))[1], .role, $origin_label] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"

      # B) Temporal para replicar
      jq -r --arg origin_label "$ancestor_type/$friendly_name" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | "\($origin_label)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role' "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
    fi
  done


  # --- 2. CAPTURAR PERMISOS A NIVEL DE PROYECTO ---
  echo "  -> Analizando permisos del Proyecto..."
  
  rm -f "$TEMP_JSON_POLICY"
  gcloud projects get-iam-policy "$project_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
  
  if [ -s "$TEMP_JSON_POLICY" ]; then
      jq -r --arg project "$project_id" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | [$project, "N/A (Heredado)", "HEREDADO", ($member | split(":"))[0], ($member | split(":"))[1], .role, "project/" + $project] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"

      # Temporal para proyecto
      jq -r --arg project "$project_id" \
      '.bindings[] | select(.role | test("bigquery|owner|editor"; "i")) | .members[] as $member | "project/\($project)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role' "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
  fi


  # --- 3. CAPTURAR DATASETS ---
 echo "  -> Analizando permisos de los datasets..."

  datasets=$(bq ls -n 10000 --project_id="$project_id" 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -v '^bq_read_all')

  if [ -n "$datasets" ]; then
      for dataset_id in $datasets
      do
         echo "     -> Dataset: $dataset_id"
        
        # 3.1 Directos
        rm -f "$TEMP_JSON_POLICY"
        bq show --format=prettyjson "$project_id:$dataset_id" > "$TEMP_JSON_POLICY" 2>/dev/null

        if [ -s "$TEMP_JSON_POLICY" ]; then
            jq -r --arg project "$project_id" --arg dataset "$dataset_id" \
            '.access[] | . as $item | {principal: (if .iamMember then .iamMember elif .userByEmail then ("user:"+.userByEmail) elif .groupByEmail then ("group:"+.groupByEmail) elif .domain then ("domain:"+.domain) else "unknown:N/A" end)} | [$project, $dataset, "DIRECTO", (.principal | split(":"))[0], (.principal | split(":"))[1], $item.role, "dataset/" + $dataset] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"
        fi

        # 3.2 Inyectados
        if [ -f "$TEMP_INHERITED" ]; then
            while IFS='|' read -r i_origin i_type i_email i_role; do
                echo "\"$project_id\",\"$dataset_id\",\"HEREDADO ($i_origin)\",\"$i_type\",\"$i_email\",\"$i_role\",\"$i_origin\"" >> "$OUTPUT_FILE"
            done < "$TEMP_INHERITED"
        fi
      done
  fi

done

# Limpieza final
rm -f "$TEMP_INHERITED" "$TEMP_JSON_POLICY" "$TEMP_NAME_CACHE"

echo ""
echo "========================================================================"
echo "✅ Finalizado."
echo "Archivo generado: $OUTPUT_FILE"
echo "========================================================================"