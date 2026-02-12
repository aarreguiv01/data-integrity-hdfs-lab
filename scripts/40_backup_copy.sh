#!/usr/bin/env bash
set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
SECONDS=0

# --- CONFIGURACIÓN ---
NN_CONTAINER=${NN_CONTAINER:-namenode}
DT=${DT:-$(date +%F)}

SOURCE_DIR="/data"
BACKUP_DIR="/backup"

echo "[backup] Iniciando proceso de backup para fecha: $DT"

# 1. CREAR ESTRUCTURA EN DESTINO
# Creamos la carpeta de backup manteniendo la estructura de particionado
echo "   -> Asegurando directorios en /backup..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p $BACKUP_DIR"

# 2. EJECUTAR LA COPIA (Variante A: hdfs dfs -cp)
# Usamos -f para sobrescribir si ya existe (idempotencia)
echo "   -> Copiando datos de $SOURCE_DIR a $BACKUP_DIR..."
# Copiamos tanto logs como iot para la fecha DT
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -cp -f $SOURCE_DIR/logs/raw/dt=$DT $BACKUP_DIR/logs_dt=$DT" || echo "Aviso: No se encontraron logs para esta fecha."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -cp -f $SOURCE_DIR/iot/raw/dt=$DT $BACKUP_DIR/iot_dt=$DT" || echo "Aviso: No se encontraron datos IoT para esta fecha."

# ---------------------------------------------------------
# 3. VALIDACIÓN (Inventario y Consistencia)
# ---------------------------------------------------------
echo "   -> Validando consistencia del backup..."

# Generamos un inventario de tamaños para comparar (origen vs destino)
echo "--- COMPARATIVA DE TAMAÑOS (ORIGEN VS BACKUP) ---"
# Nota: Si no existen las rutas, el comando podría fallar, por eso es bueno a veces poner '|| true' en scripts de reporte
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -du -s -h $SOURCE_DIR/*/raw/dt=$DT" || true
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -du -s -h $BACKUP_DIR/*_dt=$DT" || true

# 4. AUDITORÍA FSCK DEL BACKUP
# Tal como pide el enunciado: auditoría fsck del destino
echo "   -> Ejecutando fsck sobre la zona de backup..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /audit/backup/$DT"
docker exec "$NN_CONTAINER" bash -lc "hdfs fsck $BACKUP_DIR -files -blocks > /tmp/backup_fsck_$DT.txt"
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -put -f /tmp/backup_fsck_$DT.txt /audit/backup/$DT/"

echo "[backup] Proceso finalizado con éxito para DT=$DT."

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[backup] Tiempo total de ejecución: ${SECONDS}s"
echo "------------------------------------------------"