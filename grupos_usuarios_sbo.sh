#!/bin/bash

# Configuración y variables
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Variables
readonly DATE=$(date +"%d-%m-%Y-%H-%M-%S")
readonly BUnit="sbo"
readonly GROUP_FILE="${BUnit}_groups_${DATE}.csv"
readonly GROUP_MEMBERS_FILE="${BUnit}_members_by_group_${DATE}.csv"
readonly GOOGLE_ORGANIZATION_ID="532450477381"
readonly TEMP_DIR=$(mktemp -d)
readonly LOG_FILE="${BUnit}_grupos_usuarios_${DATE}.log"

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

# Función para obtener grupos
get_groups() {
    log "Generando listado de grupos..."
    
    if ! gcloud identity groups search \
        --organization="$GOOGLE_ORGANIZATION_ID" \
        --labels="cloudidentity.googleapis.com/groups.discussion_forum" \
        --page-size=10000 \
        --format=json | jq -r '.[].groups[].groupKey.id' > "$GROUP_FILE"; then
        log "ERROR: No se pudieron obtener los grupos"
        exit 1
    fi
    
    local group_count=$(wc -l < "$GROUP_FILE")
    log "Se encontraron $group_count grupos"
}

# Función para obtener miembros de un grupo
get_group_members() {
    local group_email="$1"
    local temp_file="$TEMP_DIR/members_${group_email//[^a-zA-Z0-9]/_}.json"
    
    if gcloud beta identity groups memberships list \
        --group-email="$group_email" \
        --limit=5000 \
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