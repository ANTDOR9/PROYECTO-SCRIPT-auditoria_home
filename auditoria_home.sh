#!/bin/bash
#===============================================================================
# Nombre    : auditoria_home.sh
# Propósito : Auditar los directorios contenidos en /home mostrando, para cada
#             uno, su nombre, permisos, propietario, grupo y ocupación en disco.
# Curso     : Red Hat System Administration I (Linux Red Hat) - SENATI
# Caso      : Empresa Wanda TI - Auditoría de directorios de usuario
# Uso       : sudo ./auditoria_home.sh [ruta_opcional]
# Requisito : Debe ejecutarse con privilegios de root (UID 0)
#===============================================================================

#-------------------------------------------------------------------------------
# 1. CONFIGURACIÓN DE SEGURIDAD DEL INTÉRPRETE
#    set -u : aborta si se usa una variable no definida (evita rutas vacías)
#    set -o pipefail : si falla un comando dentro de una tubería, falla toda
#    IFS controlado : evita que nombres con espacios rompan el recorrido
#-------------------------------------------------------------------------------
set -u
set -o pipefail
IFS=$'\n\t'

#-------------------------------------------------------------------------------
# 2. VARIABLES GLOBALES
#-------------------------------------------------------------------------------
readonly NOMBRE_SCRIPT="$(basename "$0")"
readonly VERSION="1.0"
# Directorio a auditar: por defecto /home, o el que se pase como 1er argumento
readonly DIR_BASE="${1:-/home}"

# Códigos de salida (convención: 0 = éxito, distinto de 0 = error)
readonly EXIT_OK=0
readonly EXIT_NO_ROOT=1          # No se ejecutó como root
readonly EXIT_RUTA_INVALIDA=2    # La ruta a auditar no existe o no es directorio
readonly EXIT_SIN_LECTURA=3      # Sin permisos de lectura sobre la ruta

# Secuencias de color para una salida legible en consola
readonly C_TITULO="\e[1;34m"   # Azul negrita
readonly C_OK="\e[1;32m"       # Verde
readonly C_ERROR="\e[1;31m"    # Rojo
readonly C_ETIQUETA="\e[1;33m" # Amarillo
readonly C_RESET="\e[0m"

#-------------------------------------------------------------------------------
# 3. FUNCIÓN: mensaje_error
#    Imprime un mensaje de error en STDERR (canal 2), no en la salida estándar.
#    Esto permite que el usuario redirija la salida normal sin perder los errores.
#-------------------------------------------------------------------------------
mensaje_error() {
    echo -e "${C_ERROR}[ERROR]${C_RESET} $1" >&2
}

#-------------------------------------------------------------------------------
# 4. FUNCIÓN: verificar_root
#    Comprueba que el script se esté ejecutando con privilegios de root.
#    La variable especial $EUID contiene el ID efectivo del usuario;
#    el usuario root siempre tiene EUID igual a 0.
#    Si no es root, muestra un mensaje claro y termina con código de error.
#-------------------------------------------------------------------------------
verificar_root() {
    if [[ "$EUID" -ne 0 ]]; then
        mensaje_error "Este script debe ejecutarse como usuario root."
        mensaje_error "Usuario actual: $(whoami) (EUID=$EUID)"
        mensaje_error "Solución: ejecute  sudo ./${NOMBRE_SCRIPT}"
        exit "$EXIT_NO_ROOT"
    fi
}

#-------------------------------------------------------------------------------
# 5. FUNCIÓN: validar_ruta
#    Verifica que el directorio a auditar exista, sea realmente un directorio
#    y que el script tenga permisos de lectura sobre él.
#-------------------------------------------------------------------------------
validar_ruta() {
    if [[ ! -e "$DIR_BASE" ]]; then
        mensaje_error "La ruta '${DIR_BASE}' no existe en este sistema."
        exit "$EXIT_RUTA_INVALIDA"
    fi

    if [[ ! -d "$DIR_BASE" ]]; then
        mensaje_error "La ruta '${DIR_BASE}' existe pero no es un directorio."
        exit "$EXIT_RUTA_INVALIDA"
    fi

    if [[ ! -r "$DIR_BASE" ]]; then
        mensaje_error "Sin permisos de lectura sobre '${DIR_BASE}'."
        exit "$EXIT_SIN_LECTURA"
    fi
}

#-------------------------------------------------------------------------------
# 6. FUNCIÓN: imprimir_cabecera
#    Muestra el encabezado del reporte con datos de contexto de la auditoría.
#-------------------------------------------------------------------------------
imprimir_cabecera() {
    echo -e "${C_TITULO}=============================================================${C_RESET}"
    echo -e "${C_TITULO}   REPORTE DE AUDITORÍA DE DIRECTORIOS - WANDA TI            ${C_RESET}"
    echo -e "${C_TITULO}=============================================================${C_RESET}"
    echo -e "${C_ETIQUETA}Script     :${C_RESET} ${NOMBRE_SCRIPT} v${VERSION}"
    echo -e "${C_ETIQUETA}Servidor   :${C_RESET} $(hostname)"
    echo -e "${C_ETIQUETA}Fecha      :${C_RESET} $(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "${C_ETIQUETA}Ejecutado  :${C_RESET} $(whoami) (EUID=$EUID)"
    echo -e "${C_ETIQUETA}Auditando  :${C_RESET} ${DIR_BASE}"
    echo -e "${C_TITULO}-------------------------------------------------------------${C_RESET}"
}

#-------------------------------------------------------------------------------
# 7. FUNCIÓN: auditar_directorios
#    Recorre cada subdirectorio de DIR_BASE y extrae su información.
#    Comandos empleados:
#      - stat  : obtiene permisos, propietario y grupo de forma estructurada
#      - du -sh: calcula la ocupación real en disco de forma legible (K, M, G)
#      - find  : cuenta archivos contenidos, dato útil para la auditoría
#-------------------------------------------------------------------------------
auditar_directorios() {
    local contador=0
    local carpeta nombre permisos octal propietario grupo tamano archivos

    # El patrón */ hace que el bucle recorra únicamente directorios.
    for carpeta in "${DIR_BASE}"/*/; do

        # Si el patrón no encontró coincidencias, bash devuelve el patrón
        # literal; esta comprobación evita procesar una ruta inexistente.
        [[ -d "$carpeta" ]] || continue

        # Se elimina la barra final para mostrar el nombre limpio.
        carpeta="${carpeta%/}"
        nombre="$(basename "$carpeta")"

        # --- Extracción de metadatos con stat ---
        # %A = permisos simbólicos (drwxr-xr-x)
        # %a = permisos en formato octal (755)
        # %U = usuario propietario   %G = grupo propietario
        permisos="$(stat -c '%A' "$carpeta" 2>/dev/null || echo 'N/D')"
        octal="$(stat -c '%a'  "$carpeta" 2>/dev/null || echo 'N/D')"
        propietario="$(stat -c '%U' "$carpeta" 2>/dev/null || echo 'N/D')"
        grupo="$(stat -c '%G' "$carpeta" 2>/dev/null || echo 'N/D')"

        # --- Ocupación en disco ---
        # du -sh entrega el total del directorio en formato legible.
        # Se descartan los errores (2>/dev/null) de subcarpetas inaccesibles
        # para que un fallo puntual no interrumpa toda la auditoría.
        tamano="$(du -sh "$carpeta" 2>/dev/null | cut -f1)"
        [[ -z "$tamano" ]] && tamano="N/D"

        # --- Cantidad de archivos contenidos ---
        archivos="$(find "$carpeta" -type f 2>/dev/null | wc -l)"

        # --- Impresión del bloque de información ---
        echo -e "${C_OK}Directorio      :${C_RESET} ${nombre}"
        echo -e "  Ruta completa : ${carpeta}"
        echo -e "  Permisos      : ${permisos} (${octal})"
        echo -e "  Propietario   : ${propietario}"
        echo -e "  Grupo         : ${grupo}"
        echo -e "  Ocupación     : ${tamano}"
        echo -e "  Archivos      : ${archivos}"
        echo -e "${C_TITULO}-------------------------------------------------------------${C_RESET}"

        contador=$((contador + 1))
    done

    # Caso especial: el directorio existe pero no contiene subdirectorios.
    if [[ "$contador" -eq 0 ]]; then
        echo -e "${C_ETIQUETA}[AVISO]${C_RESET} No se encontraron subdirectorios en '${DIR_BASE}'."
    else
        echo -e "${C_ETIQUETA}Total de directorios auditados:${C_RESET} ${contador}"
    fi

    # Ocupación global del directorio base, como dato de cierre.
    echo -e "${C_ETIQUETA}Ocupación total de ${DIR_BASE}:${C_RESET} $(du -sh "$DIR_BASE" 2>/dev/null | cut -f1)"
}

#-------------------------------------------------------------------------------
# 8. FUNCIÓN: main
#    Punto de entrada. Ordena la ejecución de las validaciones y del reporte.
#-------------------------------------------------------------------------------
main() {
    verificar_root        # Requisito del caso: solo root puede ejecutarlo
    validar_ruta          # Manejo de errores sobre la ruta a auditar
    imprimir_cabecera     # Contexto de la auditoría
    auditar_directorios   # Recolección y presentación de la información
    echo -e "${C_OK}[OK]${C_RESET} Auditoría finalizada correctamente."
    exit "$EXIT_OK"
}

# Ejecución del programa principal, pasando los argumentos recibidos.
main "$@"
