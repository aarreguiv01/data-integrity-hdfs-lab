#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# CONFIGURACIÓN DE SEGURIDAD
# -----------------------------------------------------------------------------
set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
SECONDS=0

# -----------------------------------------------------------------------------
# CORRECCIÓN PARA WINDOWS (GIT BASH)
# -----------------------------------------------------------------------------
export MSYS_NO_PATHCONV=1

# -----------------------------------------------------------------------------
# VARIABLES Y RUTAS
# -----------------------------------------------------------------------------
# Nombre del contenedor Docker donde corre Hadoop (NameNode)
NN_CONTAINER=${NN_CONTAINER:-namenode}

# Fecha del día (ej: 2023-10-25)
DT=${DT:-$(date +%F)}

# Rutas dentro del sistema de archivos distribuido (HDFS)
SRC_BASE="/data/logs/raw/dt=${DT}"    # Carpeta original
DST_BASE="/backup/logs_dt=${DT}"      # Carpeta de respaldo
AUDIT_BASE="/audit/inventory/${DT}"   # Donde guardaremos el reporte final

# Carpeta TEMPORAL en tu máquina local (tu PC) para trabajar los datos
TMP_DIR="./tmp_inventory_${DT}"
mkdir -p "$TMP_DIR"

echo "[inventory] DT=$DT"

# -----------------------------------------------------------------------------
# PREPARACIÓN EN HDFS
# -----------------------------------------------------------------------------
# Creamos la carpeta de auditoría DENTRO de HDFS usando el cliente dockerizado
docker exec "$NN_CONTAINER" hdfs dfs -mkdir -p "$AUDIT_BASE"

# -----------------------------------------------------------------------------
# 1. GENERAR INVENTARIO ORIGEN
# -----------------------------------------------------------------------------
echo "[inventory] Generando inventario ORIGEN..."

# Se conecta, lista archivos, limpia la salida y obtiene estadísticas uno a uno
docker exec "$NN_CONTAINER" \
  bash -lc "hdfs dfs -ls -R $SRC_BASE" | awk '{print $8}' | grep -v '^$' \
  | while read -r file; do
        # Nota: Esto se ejecuta por cada archivo, puede ser lento
        docker exec "$NN_CONTAINER" hdfs dfs -stat '%n,%b,%y' "$file"
    done | sort > "$TMP_DIR/src_inventory.csv"

# -----------------------------------------------------------------------------
# 2. GENERAR INVENTARIO DESTINO
# -----------------------------------------------------------------------------
echo "[inventory] Generando inventario DESTINO..."

# Hacemos exactamente lo mismo para la carpeta de respaldo (DST_BASE)
docker exec "$NN_CONTAINER" \
  bash -lc "hdfs dfs -ls -R $DST_BASE" | awk '{print $8}' | grep -v '^$' \
  | while read -r file; do
        docker exec "$NN_CONTAINER" hdfs dfs -stat '%n,%b,%y' "$file"
    done | sort > "$TMP_DIR/dst_inventory.csv"

# -----------------------------------------------------------------------------
# 3. COMPARAR: ARCHIVOS FALTANTES (Missing)
# -----------------------------------------------------------------------------
echo "[inventory] Buscando archivos faltantes..."

# Extraemos solo la columna 1 (nombre del archivo) antes de la coma
cut -d',' -f1 "$TMP_DIR/src_inventory.csv" > "$TMP_DIR/src_names.txt"
cut -d',' -f1 "$TMP_DIR/dst_inventory.csv" > "$TMP_DIR/dst_names.txt"

# COMANDO 'comm': Compara dos archivos ORDENADOS
# -23: Muestra solo lo que está en el archivo 1 (Origen) pero NO en el 2 (Destino).
comm -23 "$TMP_DIR/src_names.txt" "$TMP_DIR/dst_names.txt" \
  > "$TMP_DIR/missing_in_backup.txt"

# -----------------------------------------------------------------------------
# 4. COMPARAR: DIFERENCIA DE TAMAÑOS (Size Mismatch)
# -----------------------------------------------------------------------------
echo "[inventory] Buscando diferencias de tamaño..."

# COMANDO 'join': Une los archivos CSV por el nombre (columna 1)
# awk: Si el tamaño origen ($2) es distinto al destino ($4), imprime el reporte.
join -t',' -1 1 -2 1 \
  "$TMP_DIR/src_inventory.csv" "$TMP_DIR/dst_inventory.csv" \
  | awk -F',' '$2 != $4 {print $1",SRC_SIZE="$2",DST_SIZE="$4}' \
  > "$TMP_DIR/size_mismatch.txt"

# -----------------------------------------------------------------------------
# 5. SUBIR RESULTADOS Y LIMPIEZA
# -----------------------------------------------------------------------------
echo "[inventory] Subiendo resultados a HDFS..."

# Bucle para subir todos los archivos generados en local hacia HDFS
for f in "$TMP_DIR"/*; do
    # Paso 1: Copiar de tu PC al contenedor Docker (Linux intermedio)
    docker cp "$f" "$NN_CONTAINER:/tmp/"
    
    fname=$(basename "$f") # Extrae solo el nombre
    
    # Paso 2: Mover del contenedor Docker hacia dentro de HDFS
    docker exec "$NN_CONTAINER" hdfs dfs -put -f "/tmp/$fname" "$AUDIT_BASE/"
done

echo "[inventory] Auditoría completada ✔"

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[inventory] Tiempo total de ejecución: ${SECONDS}s"
echo "------------------------------------------------"