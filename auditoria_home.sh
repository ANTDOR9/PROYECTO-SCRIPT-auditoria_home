#!/bin/bash
#-------------------------------------------------------------
# auditoria_home.sh - Auditoria de directorios de /home
# Wanda TI - Red Hat System Administration I - SENATI
# Uso: sudo ./auditoria_home.sh [ruta]
#-------------------------------------------------------------

set -u
set -o pipefail

readonly NOMBRE_SCRIPT="$(basename "$0")"
readonly DIR_BASE="${1:-/home}"
readonly EXIT_OK=0
readonly EXIT_NO_ROOT=1
readonly EXIT_RUTA_INVALIDA=2
readonly EXIT_SIN_LECTURA=3

mensaje_error() {
    echo "[ERROR] $1" >&2
}

# root siempre tiene EUID 0
verificar_root() {
    if [[ "$EUID" -ne 0 ]]; then
        mensaje_error "Este script debe ejecutarse como usuario root."
        mensaje_error "Usuario actual: $(whoami) (EUID=$EUID)"
        mensaje_error "Solucion: ejecute  sudo ./${NOMBRE_SCRIPT}"
        exit "$EXIT_NO_ROOT"
    fi
}

validar_ruta() {
    if [[ ! -d "$DIR_BASE" ]]; then
        mensaje_error "La ruta '${DIR_BASE}' no existe o no es un directorio."
        exit "$EXIT_RUTA_INVALIDA"
    fi

    if [[ ! -r "$DIR_BASE" ]]; then
        mensaje_error "Sin permisos de lectura sobre '${DIR_BASE}'."
        exit "$EXIT_SIN_LECTURA"
    fi
}

imprimir_cabecera() {
    echo "==============================================================="
    echo "   REPORTE DE AUDITORIA DE DIRECTORIOS - WANDA TI"
    echo "==============================================================="
    echo "Servidor  : $(hostname)"
    echo "Fecha     : $(date '+%d/%m/%Y %H:%M:%S')"
    echo "Ejecutado : $(whoami) (EUID=$EUID)"
    echo "Auditando : ${DIR_BASE}"
    echo "---------------------------------------------------------------"
}

auditar_directorios() {
    local contador=0
    local carpeta

    # El patron */ limita el recorrido a directorios
    for carpeta in "${DIR_BASE}"/*/; do
        [[ -d "$carpeta" ]] || continue
        carpeta="${carpeta%/}"

        echo "Directorio    : $(basename "$carpeta")"
        echo "  Ruta        : ${carpeta}"
        echo "  Permisos    : $(stat -c '%A (%a)' "$carpeta")"
        echo "  Propietario : $(stat -c '%U' "$carpeta")"
        echo "  Grupo       : $(stat -c '%G' "$carpeta")"
        echo "  Ocupacion   : $(du -sh "$carpeta" 2>/dev/null | cut -f1)"
        echo "  Archivos    : $(find "$carpeta" -type f 2>/dev/null | wc -l)"
        echo "---------------------------------------------------------------"

        contador=$((contador + 1))
    done

    if [[ "$contador" -eq 0 ]]; then
        echo "[AVISO] No se encontraron subdirectorios en '${DIR_BASE}'."
    else
        echo "Total de directorios auditados: ${contador}"
    fi

    echo "Ocupacion total de ${DIR_BASE}: $(du -sh "$DIR_BASE" 2>/dev/null | cut -f1)"
}

main() {
    verificar_root
    validar_ruta
    imprimir_cabecera
    auditar_directorios
    echo "[OK] Auditoria finalizada correctamente."
    exit "$EXIT_OK"
}

main "$@"
