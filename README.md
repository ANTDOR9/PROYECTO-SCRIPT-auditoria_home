# Auditoría de Directorios `/home` — `auditoria_home.sh`

Script en Bash desarrollado para el **Trabajo Final del curso Red Hat System Administration I (Linux Red Hat)** — SENATI, carrera de Redes y Seguridad Informática.

Resuelve el caso práctico de la empresa **Wanda TI**, que requiere una herramienta para que los administradores de sistema obtengan información detallada de cada uno de los directorios contenidos en `/home`, facilitando las tareas de auditoría, control de permisos y gestión del espacio en disco.

---

## 1. ¿Qué hace el script?

El script recorre automáticamente todos los subdirectorios de `/home` (uno por cada usuario del sistema) y genera un reporte en consola que muestra, para cada directorio:

| Dato | Descripción | Comando utilizado |
|---|---|---|
| Nombre | Nombre del directorio de usuario | `basename` |
| Ruta completa | Ubicación absoluta en el sistema de archivos | — |
| Permisos | Formato simbólico (`drwxr-xr-x`) y octal (`755`) | `stat -c '%A'` y `stat -c '%a'` |
| Propietario | Usuario dueño del directorio | `stat -c '%U'` |
| Grupo | Grupo propietario del directorio | `stat -c '%G'` |
| Ocupación en disco | Tamaño total legible (K, M, G) | `du -sh` |
| Archivos | Cantidad de archivos contenidos | `find` + `wc -l` |

Además, exige **privilegios de root** para ejecutarse y maneja los errores de forma controlada, terminando con códigos de salida específicos según el tipo de fallo.

---

## 2. Cómo está conformado: paso a paso

El código está organizado en ocho bloques, en el mismo orden en que aparecen dentro del archivo.

### Paso 1 — Configuración de seguridad del intérprete

Se activan opciones que hacen la ejecución más robusta y evitan comportamientos inesperados:

```bash
set -u              # Aborta si se usa una variable no definida
set -o pipefail     # Si falla un comando dentro de una tubería, falla toda la tubería
IFS=$'\n\t'         # Evita que los nombres con espacios rompan el recorrido
```

### Paso 2 — Variables globales

Se definen como constantes (`readonly`) el nombre y versión del script, el directorio a auditar (`/home` por defecto, o el que se reciba como primer argumento), los códigos de salida y los colores de la salida en consola.

```bash
readonly DIR_BASE="${1:-/home}"
readonly EXIT_OK=0
readonly EXIT_NO_ROOT=1          # No se ejecutó como root
readonly EXIT_RUTA_INVALIDA=2    # La ruta no existe o no es un directorio
readonly EXIT_SIN_LECTURA=3      # Sin permisos de lectura sobre la ruta
```

### Paso 3 — Función `mensaje_error`

Centraliza la impresión de errores y los envía al canal de error estándar (**STDERR**, descriptor 2) en lugar de la salida normal. Así, si el administrador redirige el reporte a un archivo, los errores siguen siendo visibles en pantalla.

### Paso 4 — Función `verificar_root`

Responde al requisito principal del caso: el script solo puede ser ejecutado por root. Se utiliza la variable especial `$EUID`, que contiene el identificador efectivo del usuario y vale `0` únicamente para root.

```bash
if [[ "$EUID" -ne 0 ]]; then
    mensaje_error "Este script debe ejecutarse como usuario root."
    exit "$EXIT_NO_ROOT"
fi
```

Si la verificación falla, muestra el usuario actual, la solución sugerida (`sudo ./auditoria_home.sh`) y finaliza con código de error **1**.

### Paso 5 — Función `validar_ruta`

Antes de recorrer nada, comprueba tres condiciones sobre el directorio a auditar y aborta con el código correspondiente si alguna no se cumple:

1. Que la ruta exista (`-e`) → código **2**
2. Que sea realmente un directorio y no un archivo (`-d`) → código **2**
3. Que se tengan permisos de lectura sobre ella (`-r`) → código **3**

### Paso 6 — Función `imprimir_cabecera`

Genera el encabezado del reporte con la información de contexto que toda auditoría necesita para ser trazable: nombre y versión del script, nombre del servidor (`hostname`), fecha y hora de ejecución (`date`), usuario que la ejecutó y ruta auditada.

### Paso 7 — Función `auditar_directorios`

Es el núcleo del script. Recorre con un bucle `for` el patrón `"${DIR_BASE}"/*/`, que selecciona **únicamente directorios** (por la barra final).

Por cada directorio encontrado:

1. Comprueba que sea un directorio válido y limpia la barra final del nombre.
2. Extrae permisos, propietario y grupo con `stat`.
3. Calcula la ocupación en disco con `du -sh`.
4. Cuenta los archivos contenidos con `find` y `wc -l`.
5. Imprime el bloque de información con formato y colores.
6. Incrementa un contador de directorios procesados.

Los errores puntuales de subcarpetas inaccesibles se descartan con `2>/dev/null`, de modo que un fallo aislado **no interrumpe toda la auditoría**. Al terminar, muestra el total de directorios auditados y la ocupación global de `/home`; si no encontró subdirectorios, emite un aviso en lugar de fallar.

### Paso 8 — Función `main`

Es el punto de entrada del programa. Ordena la ejecución en la secuencia lógica correcta y finaliza con código **0** al completarse sin problemas:

```bash
main() {
    verificar_root        # 1. Validar privilegios
    validar_ruta          # 2. Validar la ruta a auditar
    imprimir_cabecera     # 3. Mostrar contexto
    auditar_directorios   # 4. Recolectar y presentar la información
    exit "$EXIT_OK"
}
```

---

## 3. Requisitos

- Sistema operativo Red Hat Enterprise Linux (o cualquier distribución Linux compatible).
- Intérprete **Bash** 4.0 o superior.
- Utilidades estándar del sistema: `stat`, `du`, `find`, `basename`, `hostname`, `date`.
- Privilegios de **root** o acceso mediante `sudo`.

---

## 4. Instalación y uso

Asignar permisos de ejecución al archivo:

```bash
chmod +x auditoria_home.sh
```

Ejecutar la auditoría sobre `/home`:

```bash
sudo ./auditoria_home.sh
```

Auditar una ruta distinta (parámetro opcional):

```bash
sudo ./auditoria_home.sh /opt
```

Guardar el reporte en un archivo para su posterior revisión:

```bash
sudo ./auditoria_home.sh > reporte_auditoria_$(date +%F).txt
```

> **Nota para Windows:** si el archivo se transfiere desde Windows al servidor Linux y aparece el error `bad interpreter: No such file or directory`, ejecutar `dos2unix auditoria_home.sh` para corregir los saltos de línea.

---

## 5. Ejemplo de salida

```
=============================================================
   REPORTE DE AUDITORÍA DE DIRECTORIOS - WANDA TI
=============================================================
Script     : auditoria_home.sh v1.0
Servidor   : srv-wandati-01
Fecha      : 12/09/2026 15:32:39
Ejecutado  : root (EUID=0)
Auditando  : /home
-------------------------------------------------------------
Directorio      : jperez
  Ruta completa : /home/jperez
  Permisos      : drwxr-xr-x (755)
  Propietario   : jperez
  Grupo         : contabilidad
  Ocupación     : 1.2G
  Archivos      : 3421
-------------------------------------------------------------
Directorio      : mlopez
  Ruta completa : /home/mlopez
  Permisos      : drwxr-x--- (750)
  Propietario   : mlopez
  Grupo         : finanzas
  Ocupación     : 16K
  Archivos      : 3
-------------------------------------------------------------
Total de directorios auditados: 2
Ocupación total de /home: 1.2G
[OK] Auditoría finalizada correctamente.
```

Ejemplo de ejecución **sin** privilegios de root:

```
[ERROR] Este script debe ejecutarse como usuario root.
[ERROR] Usuario actual: jperez (EUID=1001)
[ERROR] Solución: ejecute  sudo ./auditoria_home.sh
```

---

## 6. Códigos de salida

| Código | Significado |
|---|---|
| `0` | Auditoría completada correctamente |
| `1` | El script no se ejecutó con privilegios de root |
| `2` | La ruta indicada no existe o no es un directorio |
| `3` | Sin permisos de lectura sobre la ruta indicada |

Estos códigos permiten integrar el script en tareas programadas (`cron`) o en otros scripts, evaluando el resultado mediante la variable `$?`.

---

## 7. Medidas de seguridad implementadas

- **Verificación obligatoria de privilegios:** impide que usuarios sin autorización obtengan un inventario de los directorios y sus permisos.
- **Errores dirigidos a STDERR:** separa el reporte de los mensajes de fallo, facilitando el registro y la depuración.
- **Variables de solo lectura (`readonly`):** evita la modificación accidental o malintencionada de rutas y códigos críticos durante la ejecución.
- **`set -u` e `IFS` controlado:** previene el uso de variables vacías que podrían derivar en operaciones sobre rutas incorrectas.
- **Operación estrictamente de solo lectura:** el script consulta metadatos, pero nunca lee el contenido de los archivos ni los modifica, preservando la confidencialidad de la información de los usuarios.
- **Supresión controlada de errores:** los fallos de acceso a subcarpetas no exponen rutas internas ni detienen la auditoría.

---

## 8. Estructura del proyecto

```
PROYECTO-SCRIPT-auditoria_home/
├── auditoria_home.sh    # Script principal de auditoría
└── README.md            # Este documento
```
