#!/usr/bin/env bash

# -e: Si el comando falla, el script se detiene
# -u: Si se usa una variable no definida, el script falla
# -o pipefail: si falla un comando dentro de una tuberia (|), todo falla
set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
# Reiniciamos el contador interno de bash a 0 para asegurar precisión
SECONDS=0

# Nombre del contenedor, "namenode" en mi caso
NN_CONTAINER=${NN_CONTAINER:-namenode}

# Fecha de hoy
DT=${DT:-$(date +%F)}

echo "[bootstrap] DT=$DT"
echo "[bootstrap] Configurando HDFS en contenedor: $NN_CONTAINER"

# --- CREACIÓN DE DIRECTORIOS ---
# Usamos bash -lc para asegurar que carga las variables de entorno de Hadoop correctamente

echo "[bootstrap] Creando carpetas..."

# 1. Crea zona de datos crudos (Raw Zone) particionada por fecha
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /data/logs/raw/dt=$DT"
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /data/iot/raw/dt=$DT"

# 2. Crea zona para Backups
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /backup/data"

# 3. Crea zonas para guardar los informes de auditoría (fsck)
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /audit/fsck/$DT"
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /audit/inventory/$DT"


# --- PERMISOS ---

# Da permisos de escritura, lectura y ejecucion a todos los usuarios
# -R: Recursivo (aplica a carpetas y subcarpetas).
# || true: Esto es un truco de seguridad. Si el chmod falla por alguna razón,
#          el "|| true" hace que el script NO se detenga y continúe.
echo "[bootstrap] Ajustando permisos (777)..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -chmod -R 777 /data /audit /backup" || true


# --- VERIFICACIÓN ---
echo "[bootstrap] Estructura creada:"
# Listar todo el HDFS recursivamente
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -ls -R /"

echo "[bootstrap] Completado."

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[bootstrap] Tiempo total de ejecución: ${SECONDS}s"
echo "------------------------------------------------"