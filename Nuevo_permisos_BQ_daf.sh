#!/bin/bash

#ultima versión eficiente

#USAR ESTA VERSIÓN DICIEMBRE 2025

#entrega a nivel dataset, y hereda los permisos de org, folder y proyecto, solo editor, viewer, owner, writer, reader

# --- Configuración ---
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
#!/bin/bash


# Nombre del archivo de salida
OUTPUT_FILE="permisos_bq_auditoria_tags_cascada.csv"

# Archivos temporales
TEMP_INHERITED="temp_inherited_perms.txt"
TEMP_JSON_POLICY="temp_policy_raw.json"
TEMP_NAME_CACHE="temp_name_cache.txt"
TEMP_DATASET_TAGS="temp_dataset_tags.txt"
TEMP_PROJECT_TAGS="temp_project_tags.txt" # Nuevo archivo para tags del proyecto

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

# --- LISTA BLANCA DE ROLES ---
ROLE_FILTER="roles/bigquery.admin|roles/bigquery.dataViewer|roles/bigquery.dataEditor|roles/owner|DaFDataAdmin|DaFBigqueryCreateDataset|DaFBigqueryCreateTable|DaF_BigQuery_Transfers_Get|Daf_Bigquery_Recomender"

for project_id in "${PROJECTS[@]}"
do
  echo "========================================================================"
  echo "PROCESANDO PROYECTO: $project_id"
  echo "========================================================================"

  if ! gcloud config set project "$project_id" 2>/dev/null; then
    echo "  Error: No se pudo acceder al proyecto $project_id."
    continue
  fi

  # --- NUEVO: Obtener Tags del Proyecto (Nivel Superior) ---
  # Los tags de proyecto se ligan al Project Number, no al ID.
  project_number=$(gcloud projects describe "$project_id" --format="value(projectNumber)" 2>/dev/null)
  
  > "$TEMP_PROJECT_TAGS"
  if [ -n "$project_number" ]; then
      echo "  -> Obteniendo Tags a nivel de Proyecto ($project_number)..."
      gcloud resource-manager tags bindings list \
        --parent="//cloudresourcemanager.googleapis.com/projects/$project_number" \
        --format="value(tagValue)" 2>/dev/null > "$TEMP_PROJECT_TAGS"
  fi

  > "$TEMP_INHERITED"

  # --- 1. JERARQUÍA (Org/Folder) ---
  echo "  -> Analizando jerarquía..."
  
  gcloud projects get-ancestors "$project_id" --format=json | jq -c '.[]' | while read -r ancestor; do
    ancestor_type=$(echo "$ancestor" | jq -r '.type')
    ancestor_id=$(echo "$ancestor" | jq -r '.id')

    if [ "$ancestor_type" = "project" ]; then
      continue
    fi

    friendly_name=$(obtener_nombre_amigable "$ancestor_type" "$ancestor_id")
    
    rm -f "$TEMP_JSON_POLICY"
    if [ "$ancestor_type" = "organization" ]; then
      gcloud organizations get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    elif [ "$ancestor_type" = "folder" ]; then
      gcloud resource-manager folders get-iam-policy "$ancestor_id" --format=json > "$TEMP_JSON_POLICY" 2>/dev/null
    fi

    if [ -s "$TEMP_JSON_POLICY" ]; then
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


  # --- 3. DATASETS Y EVALUACIÓN CASCADA ---
  datasets=$(bq ls -n 10000 --project_id="$project_id" 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -v '^bq_read_all')

  if [ -n "$datasets" ]; then
      for dataset_id in $datasets
      do
        echo "  -> Analizando permisos directos del dataset: $dataset_id"

        # 3.1 Obtener Tags REALES del Dataset
        > "$TEMP_DATASET_TAGS"
        gcloud resource-manager tags bindings list \
            --parent="//bigquery.googleapis.com/projects/$project_id/datasets/$dataset_id" \
            --format="value(tagValue)" 2>/dev/null > "$TEMP_DATASET_TAGS"

        # 3.2 Permisos Directos
        rm -f "$TEMP_JSON_POLICY"
        bq show --format=prettyjson "$project_id:$dataset_id" > "$TEMP_JSON_POLICY" 2>/dev/null

        if [ -s "$TEMP_JSON_POLICY" ]; then
            jq -r --arg project "$project_id" --arg dataset "$dataset_id" \
            '.access[] | . as $item | {principal: (if .iamMember then .iamMember elif .userByEmail then ("user:"+.userByEmail) elif .groupByEmail then ("group:"+.groupByEmail) elif .domain then ("domain:"+.domain) else "unknown:N/A" end)} | [$project, $dataset, "DIRECTO", (.principal | split(":"))[0], (.principal | split(":"))[1], $item.role, "dataset/" + $dataset, "Directo (Aplica Siempre)"] | @csv' "$TEMP_JSON_POLICY" >> "$OUTPUT_FILE"
        fi

        # 3.3 Lógica de Herencia CASCADA (Proyecto OR Dataset)
        if [ -f "$TEMP_INHERITED" ]; then
            while IFS='|' read -r i_origin i_type i_email i_role i_raw_expr; do
                
                should_print=false
                status_msg="N/A"

                if [ "$i_raw_expr" == "SIN_CONDICION" ]; then
                    should_print=true
                    status_msg="Heredado (Universal)"
                else
                    # Extraer ID del Tag de la condición
                    extracted_tag=$(echo "$i_raw_expr" | grep -o "tagValues/[0-9]\+")

                    if [ -n "$extracted_tag" ]; then
                        # VERIFICACIÓN DOBLE:
                        # 1. ¿Está el tag en el PROYECTO? (Hereda a todo lo de adentro)
                        if grep -q "$extracted_tag" "$TEMP_PROJECT_TAGS"; then
                            should_print=true
                            status_msg="Heredado (Tag en Proyecto)"
                        # 2. ¿Está el tag en el DATASET?
                        elif grep -q "$extracted_tag" "$TEMP_DATASET_TAGS"; then
                            should_print=true
                            status_msg="Heredado (Tag en Dataset)"
                        else
                            # No está ni en el proyecto ni en el dataset
                            should_print=false
                        fi
                    else
                        should_print=false 
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

rm -f "$TEMP_INHERITED" "$TEMP_JSON_POLICY" "$TEMP_NAME_CACHE" "$TEMP_DATASET_TAGS" "$TEMP_PROJECT_TAGS"

echo ""
echo "========================================================================"
echo "✅ Finalizado."
echo "   - Se validan tags en PROYECTO y en DATASET."
echo "   - Si el proyecto tiene el tag, aplica a todos sus datasets."
echo "Archivo: $OUTPUT_FILE"
echo "========================================================================"