#!/usr/bin/env bash
set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
SECONDS=0

# --- CORRECCIÓN PARA WINDOWS (GIT BASH) ---
# Esto evita que Git Bash transforme "/tmp" en "C:/Program Files/..."
# Es vital para que el comando hdfs dfs -put funcione bien.
export MSYS_NO_PATHCONV=1

# Configuracion
NN_CONTAINER=${NN_CONTAINER:-namenode}
DT=${DT:-$(date +%F)}
LOCAL_DIR=${LOCAL_DIR:-./data_local/$DT}

# Creamos la variable DT_SAFE (2026-02-02 -> 20260202)
DT_SAFE=${DT//-/}

echo "[ingest] DT=$DT"
echo "[ingest] Local dir=$LOCAL_DIR"

# ---------------------------------------------------------
# FUNCIÓN AUXILIAR: Subir archivo (Host -> Docker -> HDFS)
# ---------------------------------------------------------
ingestar() {
    local archivo=$1       # Ej: logs_20260202.log
    local ruta_hdfs=$2     # Ej: /data/logs/raw/dt=...

    echo "------------------------------------------------"
    echo "Procesando: $archivo"

    # 1. Copiar del PC al Contenedor (Zona temporal)
    # Nota: Si falla aquí, asegúrate de haber ejecutado el script 10 antes.
    docker cp "$LOCAL_DIR/$archivo" "$NN_CONTAINER:/tmp/$archivo"

    # 2. Subir a HDFS
    # -f fuerza la sobrescritura. Usamos /tmp normal gracias al export de arriba.
    echo "   -> Subiendo a HDFS ($ruta_hdfs)..."
    docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -put -f /tmp/$archivo $ruta_hdfs"

    # 3. Limpiar temporal
    # Añadimos '|| true' para que si falla el borrado por permisos, el script continúe.
    echo "   -> Limpiando contenedor..."
    docker exec "$NN_CONTAINER" rm "/tmp/$archivo" || true
    
    echo "Completado: $archivo"
}

# ---------------------------------------------------------
# 1) EJECUTAR LA CARGA
# ---------------------------------------------------------

# Subir LOGS a /data/logs/raw/dt=YYYY-MM-DD/
ingestar "logs_${DT_SAFE}.log" "/data/logs/raw/dt=$DT/"

# Subir IOT a /data/iot/raw/dt=YYYY-MM-DD/
ingestar "iot_${DT_SAFE}.jsonl" "/data/iot/raw/dt=$DT/"

# ---------------------------------------------------------
# 2) MOSTRAR EVIDENCIAS
# ---------------------------------------------------------
echo ""
echo "[ingest] EVIDENCIAS EN HDFS:"
echo "=================================================="

# Listar carpetas para confirmar ubicación
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -ls -R /data/logs/raw/dt=$DT"
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -ls -R /data/iot/raw/dt=$DT"

echo ""
echo "--- TAMAÑO FINAL (Debe ser ~300M cada uno) ---"
# El comando clave para verificar que has subido todo
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -du -h /data"

echo "=================================================="
echo "[ingest] TODO completado."

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[ingest] Tiempo total de ejecución: ${SECONDS}s"
echo "------------------------------------------------"