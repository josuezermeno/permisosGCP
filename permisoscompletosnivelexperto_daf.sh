#!/bin/bash

# --- Configuración ---
declare -a PROJECTS=(
    "daf-dp-raw-prod" 
)
#!/bin/bash

# Nombre del archivo de salida
OUTPUT_FILE="permisos_bq_auditoria_tags_final.csv"

# Archivos temporales
TEMP_INHERITED="temp_inherited_perms.txt"
TEMP_JSON_POLICY="temp_policy_raw.json"
TEMP_NAME_CACHE="temp_name_cache.txt"
TEMP_DATASET_TAGS="temp_dataset_tags.txt"

# Inicializamos cache vacía
> "$TEMP_NAME_CACHE"

# --- FUNCIÓN DE CACHÉ DE NOMBRES ---
function obtener_nombre_amigable() {
    local tipo=$1
    local id=$2
    local cache_key="${tipo}_${id}"
    
    local cached_name
    cached_name=$(grep "^${cache_key}|" "$TEMP_NAME_CACHE" | head -n 1 | cut -d'|' -f2)

    if [ -n "$cached_name" ]; then
        echo "$cached_name"
        return
    fi

    local display_name=""
    if [ "$tipo" = "organization" ]; then
        display_name=$(gcloud organizations describe "$id" --format="value(displayName)" 2>/dev/null)
    elif [ "$tipo" = "folder" ]; then
        display_name=$(gcloud resource-manager folders describe "$id" --format="value(displayName)" 2>/dev/null)
    elif [ "$tipo" = "project" ]; then
        display_name=$(gcloud projects describe "$id" --format="value(name)" 2>/dev/null)
    fi

    if [ -z "$display_name" ]; then
        display_name="$id"
    fi

    local safe_name="${display_name} ($id)"
    echo "${cache_key}|${safe_name}" >> "$TEMP_NAME_CACHE"
    echo "$safe_name"
}

# --- Lógica del Script ---

echo "Proyecto,Dataset,TipoDePermiso,TipoCuenta,Correo,Rol,EntidadAplicada,EstadoCondicion" > "$OUTPUT_FILE"

# Filtro de roles (Regex)
ROLE_FILTER="bigquery|owner|editor|admin"

for project_id in "${PROJECTS[@]}"
do
  echo "========================================================================"
  echo "PROCESANDO PROYECTO: $project_id"
  echo "========================================================================"

  if ! gcloud config set project "$project_id" 2>/dev/null; then
    echo "  Error: No se pudo acceder al proyecto $project_id."
    continue
  fi

  > "$TEMP_INHERITED"

  # --- 1. JERARQUÍA (Org/Folder) ---
  echo "  -> Analizando jerarquía y extrayendo Condiciones CRUDAS..."
  
  gcloud projects get-ancestors "$project_id" --format=json | jq -c '.[]' | while read -r ancestor; do
    ancestor_type=$(echo "$ancestor" | jq -r '.type')
    ancestor_id=$(echo "$ancestor" | jq -r '.id')

    if [ "$ancestor_type" = "project" ]; then
      continue
    fi

    friendly_name=$(obtener_nombre_amigable "$ancestor_type" "$ancestor_id")
    echo "     -> Revisando: $ancestor_type $friendly_name"
    
    rm -f "$TEMP_JSON_POLICY"
    if [ "$ancestor_type" = "organization" ]; then
      gcloud organizations get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    elif [ "$ancestor_type" = "folder" ]; then
      gcloud resource-manager folders get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    fi

    if [ -s "$TEMP_JSON_POLICY" ]; then
      # CAMBIO CLAVE: Extraemos la expresión completa o la palabra "SIN_CONDICION"
      # Usamos una variable intermedia $expr para simplificar
      jq -r --arg origin_label "$ancestor_type/$friendly_name" --arg filter "$ROLE_FILTER" \
      '.bindings[] | select(.role | test($filter; "i")) | .members[] as $member | 
       (if .condition == null or .condition.expression == null then "SIN_CONDICION" else .condition.expression end) as $expr |
       "\($origin_label)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role + "|" + $expr' \
      "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
    fi
  done


  # --- 2. PERMISOS DEL PROYECTO ---
  echo "  -> Analizando permisos del Proyecto..."
  
  rm -f "$TEMP_JSON_POLICY"
  gcloud projects get-iam-policy "$project_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
  
  if [ -s "$TEMP_JSON_POLICY" ]; then
      jq -r --arg project "$project_id" --arg filter "$ROLE_FILTER" \
      '.bindings[] | select(.role | test($filter; "i")) | .members[] as $member | 
       (if .condition == null or .condition.expression == null then "SIN_CONDICION" else .condition.expression end) as $expr |
       "project/\($project)|" + ($member | split(":"))[0] + "|" + ($member | split(":"))[1] + "|" + .role + "|" + $expr' \
      "$TEMP_JSON_POLICY" >> "$TEMP_INHERITED"
  fi


  # --- 3. DATASETS Y EVALUACIÓN SEGURA DE CONDICIONES ---
  datasets=$(bq ls -n 10000 --project_id="$project_id" 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -v '^bq_read_all')

  if [ -n "$datasets" ]; then
      for dataset_id in $datasets
      do
        # 3.1 Obtener Tags REALES del Dataset
        > "$TEMP_DATASET_TAGS"
        gcloud resource-manager tags bindings list \
            --parent="//bigquery.googleapis.com/projects/$project_id/datasets/$dataset_id" \
            --format="value(tagValue)" 2>/dev/null > "$TEMP_DATASET_TAGS"

        # 3.2 Permisos Directos (Estos siempre aplican)
        rm -f "$TEMP_JSON_POLICY"
        bq show --format=prettyjson "$project_id:$dataset_id" > "$TEMP_JSON_POLICY" 2>/dev/null

        if [ -s "$TEMP_JSON_POLICY" ]; then
            jq -r --arg project "$project_id" --arg dataset "$dataset_id" \
            '.access[] | . as $item | {principal: (if .iamMember then .iamMember elif .userByEmail then ("user:"+.userByEmail) elif .groupByEmail then ("group:"+.groupByEmail) elif .domain then ("domain:"+.domain) else "unknown:N/A" end)} | [$project, $dataset, "DIRECTO", (.principal | split(":"))[0], (.principal | split(":"))[1], $item.role, "dataset/" + $dataset, "Directo (Aplica Siempre)"] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"
        fi

        # 3.3 Lógica de Herencia en Bash (Más robusta)
        if [ -f "$TEMP_INHERITED" ]; then
            while IFS='|' read -r i_origin i_type i_email i_role i_raw_expr; do
                
                should_print=false
                status_msg="N/A"

                if [ "$i_raw_expr" == "SIN_CONDICION" ]; then
                    # CASO 1: No hay condición, el permiso es universal.
                    should_print=true
                    status_msg="Heredado (Universal)"
                else
                    # CASO 2: HAY CONDICIÓN. Intentamos extraer el tagValues/12345
                    # Usamos grep -o para buscar solo el ID del tag dentro de todo el texto raro de la condición
                    extracted_tag=$(echo "$i_raw_expr" | grep -o "tagValues/[0-9]\+")

                    if [ -z "$extracted_tag" ]; then
                        # CASO 2a: Hay condición pero no es de Tags (es de Hora, IP, etc) o no pudimos leerla.
                        # Por seguridad, NO lo mostramos como válido.
                        should_print=false 
                    else
                        # CASO 2b: Encontramos un tag requerido (ej: tagValues/281478008704002)
                        # Verificamos si el dataset tiene ese tag
                        if grep -q "$extracted_tag" "$TEMP_DATASET_TAGS"; then
                            should_print=true
                            status_msg="Heredado (Tag Match: $extracted_tag)"
                        else
                            should_print=false
                            # El dataset no tiene el tag, así que el permiso no aplica. Ignoramos.
                        fi
                    fi
                fi

                if [ "$should_print" = true ]; then
                    echo "\"$project_id\",\"$dataset_id\",\"HEREDADO ($i_origin)\",\"$i_type\",\"$i_email\",\"$i_role\",\"$i_origin\",\"$status_msg\"" >> "$OUTPUT_FILE"
                fi

            done < "$TEMP_INHERITED"
        fi
      done
  fi
done

rm -f "$TEMP_INHERITED" "$TEMP_JSON_POLICY" "$TEMP_NAME_CACHE" "$TEMP_DATASET_TAGS"

echo ""
echo "========================================================================"
echo "✅ Finalizado."
echo "   - Lógica de condiciones corregida."
echo "   - Si el rol tiene condición y el dataset NO tiene el tag, se excluye."
echo "Archivo: $OUTPUT_FILE"
echo "========================================================================"