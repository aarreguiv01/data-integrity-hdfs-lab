#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CABECERA DE SEGURIDAD ("Safety First")
# -----------------------------------------------------------------------------
# set -e: Detiene el script inmediatamente si un comando falla (devuelve error).
# set -u: Detiene el script si intentamos usar una variable que no ha sido definida.
# set -o pipefail: Si una parte de una tubería (|) falla, todo el comando se considera fallido.
set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
SECONDS=0

# -----------------------------------------------------------------------------
# CONFIGURACIÓN DE VARIABLES
# -----------------------------------------------------------------------------
# Sintaxis ${VAR:-valor}: Si la variable existe, úsala; si no, usa el valor por defecto.
OUT_DIR=${OUT_DIR:-./data_local}  # Carpeta donde guardaremos los archivos
DT=${DT:-$(date +%F)}             # Fecha actual formato AAAA-MM-DD (ej: 2026-02-10)

# Limpieza de fecha: ${VAR//buscar/reemplazar}
DT_SAFE=${DT//-/}

# Creamos la carpeta de destino. 
mkdir -p "$OUT_DIR/$DT"

echo "[generate] Iniciando generación de datos en: $OUT_DIR/$DT"
echo "[generate] Usando fecha dinámica: $DT"

# -----------------------------------------------------------------------------
# PARÁMETROS DE GENERACIÓN
# -----------------------------------------------------------------------------
# Definimos el tamaño exacto que queremos generar por archivo (en Megabytes)
TARGET_SIZE_MB=300

# -----------------------------------------------------------------------------
# 1. GENERACIÓN DE LOGS (Simulación de servidor web)
# -----------------------------------------------------------------------------
LOG_FILE="logs_${DT_SAFE}.log"
LOG_PATH="$OUT_DIR/$DT/$LOG_FILE"

echo ""
echo "[generate] 1/2 Generando LOGS con fecha $DT..."

# EXPLICACIÓN DEL TRUCO 'yes | dd':
# Se usa '|| true' para evitar que el script falle cuando 'dd' cierra la tubería y 'yes' se queja.
yes "${DT}T10:00:00 INFO user_8821 action=ADD_TO_CART status=200 delay=12ms" \
    | dd of="$LOG_PATH" bs=1M count=$TARGET_SIZE_MB iflag=fullblock status=progress || true

echo " Logs generados exitosamente."

# -----------------------------------------------------------------------------
# 2. GENERACIÓN DE IOT (Simulación de sensores JSON)
# -----------------------------------------------------------------------------
IOT_FILE="iot_${DT_SAFE}.jsonl"
IOT_PATH="$OUT_DIR/$DT/$IOT_FILE"

echo ""
echo "[generate] 2/2 Generando datos IOT..."

# Repetimos la misma lógica pero con una estructura JSON para simular sensores
yes '{"deviceId": "sensor_x50", "ts": 1716200000, "metric": "temperature", "value": 24.5, "region": "eu-west"}' \
    | dd of="$IOT_PATH" bs=1M count=$TARGET_SIZE_MB iflag=fullblock status=progress || true

echo " Datos IoT generados exitosamente."

# -----------------------------------------------------------------------------
# VERIFICACIÓN FINAL
# -----------------------------------------------------------------------------
echo ""
echo "[generate] Resumen de espacio ocupado:"
# du -sh: Muestra el tamaño (Disk Usage) en formato humano (Human-readable)
du -sh "$OUT_DIR/$DT/"*

echo "[generate] TODO completado."

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[generate] Tiempo total de ejecución: ${SECONDS}s"
echo "------------------------------------------------"