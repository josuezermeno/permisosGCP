#!/bin/bash
## codigo de JOSE LUIS BERMUDEZ 

# Configuración y variables
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Variables
readonly DATE=$(date +"%d-%m-%Y-%H-%M-%S")
readonly BUnit="daf"
readonly GROUP_FILE="${BUnit}_groups_${DATE}.csv"
readonly GROUP_MEMBERS_FILE="${BUnit}_members_by_group_${DATE}.csv"
readonly GOOGLE_ORGANIZATION_ID="713468743428"
readonly TEMP_DIR=$(mktemp -d)
readonly LOG_FILE="${BUnit}_grupos_usuarios_daf_${DATE}.log"

# Función para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para limpieza al salir
cleanup() {
    log "Limpiando archivos temporales..."
    rm -rf "$TEMP_DIR"
}

# Trap para limpiar al salir
trap cleanup EXIT

# Función para verificar dependencias
check_dependencies() {
    local deps=("gcloud" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "ERROR: $dep no está instalado"
            exit 1
        fi
    done
}

# Función para verificar autenticación de gcloud
check_gcloud_auth() {
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log "ERROR: No hay una cuenta de gcloud autenticada"
        exit 1
    fi
}
gcloud config set project daf-dp-management-prod

# Función para obtener grupos
# Función auxiliar para descargar TODAS las páginas de una búsqueda
fetch_all_pages() {
    local label_filter="$1"
    local next_token=""
    
    # Bucle infinito hasta que se acaben las páginas
    while : ; do
        # 1. Construir el comando base
        # Nota: Usamos --page-size=1000 que es el máximo permitido por la API por llamada
        local cmd=(gcloud identity groups search --organization="$GOOGLE_ORGANIZATION_ID" --labels="$label_filter" --page-size=1000 --format=json)
        
        # 2. Si hay token de página siguiente, lo agregamos al comando
        if [[ -n "$next_token" ]]; then
            cmd+=(--page-token="$next_token")
        fi

        # 3. Ejecutar y capturar la respuesta JSON completa
        local response
        response=$("${cmd[@]}")

        # 4. Extraer los IDs de grupos de ESTA página y guardarlos
        # Usamos 'empty' para evitar errores si la página viniera vacía
        echo "$response" | jq -r '.[].groups[]?.groupKey.id // empty' >> "$RAW_GROUPS"

        # 5. Buscar el token de la siguiente página
        # El formato de gcloud devuelve una lista de respuestas, tomamos el token de la primera (única) respuesta
        local new_token
        new_token=$(echo "$response" | jq -r '.[0].nextPageToken // empty')

        # 6. Decidir si continuamos
        if [[ -n "$new_token" && "$new_token" != "null" ]]; then
            next_token="$new_token"
            log "   ...Pagina completada, descargando siguiente bloque..."
        else
            # Si no hay token, terminamos
            break
        fi
    done
}

# Función principal para obtener grupos
get_groups() {
    log "Generando listado de grupos (Discussion y Security)..."
    
    # Definir archivo temporal para acumular resultados crudos
    # Lo hacemos global para que la función auxiliar lo vea o lo pasamos como variable
    RAW_GROUPS="$TEMP_DIR/raw_groups_unsorted.txt"
    : > "$RAW_GROUPS" # Aseguramos que esté vacío al inicio

    # 1. Obtener grupos 'Discussion Forum' paginados
    log "Consultando grupos Discussion Forum (Iterando páginas)..."
    fetch_all_pages "cloudidentity.googleapis.com/groups.discussion_forum"

    # 2. Obtener grupos 'Security' paginados
    log "Consultando grupos Security (Iterando páginas)..."
    fetch_all_pages "cloudidentity.googleapis.com/groups.security"

    # 3. Procesar: Ordenar y eliminar duplicados
    if [ -s "$RAW_GROUPS" ]; then
        sort "$RAW_GROUPS" | uniq > "$GROUP_FILE"
        local group_count=$(wc -l < "$GROUP_FILE")
        log "EXITO: Se encontraron $group_count grupos únicos en total (superando el límite de 1000)."
    else
        log "ADVERTENCIA: No se encontraron grupos."
        touch "$GROUP_FILE"
    fi
}

# Función para obtener miembros de un grupo
get_group_members() {
    local group_email="$1"
    local temp_file="$TEMP_DIR/members_${group_email//[^a-zA-Z0-9]/_}.json"
    
    if gcloud beta identity groups memberships list \
        --group-email="$group_email" \
        --limit=50000 \
        --format=json > "$temp_file" 2>/dev/null; then
        
        local member_count=$(jq -r '.[].memberKey[]' "$temp_file" 2>/dev/null | wc -l)
        
        if [ "$member_count" -gt 0 ]; then
            log "Grupo $group_email: $member_count usuarios encontrados"
            jq -r '.[].memberKey[]' "$temp_file" | while read -r member; do
                echo "$group_email,$member" >> "$GROUP_MEMBERS_FILE"
            done
        else
            log "Grupo $group_email: Vacío"
            echo "$group_email,Vacío" >> "$GROUP_MEMBERS_FILE"
        fi
    else
        log "ERROR: No se pudieron obtener los miembros del grupo $group_email"
        echo "$group_email,Error al obtener miembros" >> "$GROUP_MEMBERS_FILE"
    fi
}

# Función principal
main() {
    log "Iniciando proceso de extracción de grupos y miembros..."
    
    # Verificaciones iniciales
    check_dependencies
    check_gcloud_auth
    
    # Crear archivo de salida con headers
    echo "Grupo,Correo" > "$GROUP_MEMBERS_FILE"
    
    # Obtener grupos
    get_groups
    
    # Procesar cada grupo
    local processed=0
    local total_groups=$(wc -l < "$GROUP_FILE")
    
    while IFS= read -r grupo; do
        ((processed++))
        log "Procesando grupo $processed/$total_groups: $grupo"
        get_group_members "$grupo"
    done < "$GROUP_FILE"
    
    log "Proceso completado. Archivos generados:"
    log "- Grupos: $GROUP_FILE"
    log "- Miembros: $GROUP_MEMBERS_FILE"
    log "- Log: $LOG_FILE"
}

# Ejecutar función principal
main "$@"