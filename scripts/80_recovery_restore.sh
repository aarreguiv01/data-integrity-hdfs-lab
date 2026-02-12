#!/usr/bin/env bash

# ==============================================================================
# SCRIPT 80: RECUPERACIÓN Y RESTAURACIÓN (DISASTER RECOVERY)
# ------------------------------------------------------------------------------
# PROPÓSITO:
# Demostrar la capacidad del sistema para recuperarse de una pérdida de datos.
# 1. Simula un desastre (borrado accidental de datos en producción).
# 2. Restaura los datos desde la zona de Respaldo (/backup) a Producción (/data).
# 3. Valida que la integridad (fsck) y el inventario sean correctos tras la carga.
# ==============================================================================

set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
SECONDS=0

# --- CORRECCIÓN PARA WINDOWS (GIT BASH) ---
export MSYS_NO_PATHCONV=1

# ==========================================
# 1. CONFIGURACIÓN
# ==========================================
NN_CONTAINER=${NN_CONTAINER:-namenode}
DT=${DT:-$(date +%F)}

# Rutas clave en HDFS
PROD_PATH="/data"           # Donde deberían estar los datos vivos
BACKUP_PATH="/backup"       # Donde guardamos la copia de seguridad
AUDIT_DIR="/audit/recovery/$DT"
REPORT_FILE="./recovery_report_$DT.txt"

echo "========================================================"
echo "[recovery] INICIANDO PROTOCOLO DE RECUPERACIÓN: $DT"
echo "[recovery] Namenode: $NN_CONTAINER"
echo "========================================================"

# Asegurar directorio de reportes
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p $AUDIT_DIR" || true

# ==========================================
# 2. SIMULACIÓN DEL DESASTRE (DATA LOSS)
# ==========================================
echo ""
echo "[recovery] 1. SIMULANDO DESASTRE (BORRADO ACCIDENTAL) "
echo " -> Eliminando datos en $PROD_PATH/logs/raw/dt=$DT..."

# El comando -rm -skipTrash borra los datos sin pasar por la papelera (irrecuperable sin backup)
# || true evita que el script falle si los datos ya no existen
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -rm -r -skipTrash $PROD_PATH/logs/raw/dt=$DT" || true
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -rm -r -skipTrash $PROD_PATH/iot/raw/dt=$DT" || true

echo " -> Verificando destrucción de datos..."
# Si el ls falla es buena señal (significa que no existen)
if docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -ls $PROD_PATH/logs/raw/dt=$DT" 2>/dev/null; then
    echo "ERROR: Los datos siguen ahí. El desastre falló."
else
    echo "CONFIRMADO: Datos eliminados. El sistema está en estado crítico."
fi

# ==========================================
# 3. PROCESO DE RESTAURACIÓN (RESTORE)
# ==========================================
echo ""
echo "[recovery] 2. Iniciando restauración desde BACKUP..."

# Recreamos la estructura de carpetas vacías en producción
echo " -> Reconstruyendo estructura de directorios..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p $PROD_PATH/logs/raw/"
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p $PROD_PATH/iot/raw/"

# Copiamos desde Backup hacia Producción (Recuperación)
# Nota: En script 40 guardamos como /backup/logs_dt=YYYY-MM-DD. 
# Ahora lo copiamos y renombramos al destino original /data/logs/raw/dt=YYYY-MM-DD
echo " -> Restaurando LOGS..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -cp $BACKUP_PATH/logs_dt=$DT $PROD_PATH/logs/raw/dt=$DT"

echo " -> Restaurando IOT..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -cp $BACKUP_PATH/iot_dt=$DT $PROD_PATH/iot/raw/dt=$DT"

echo " -> ¡Restauración completada!"

# ==========================================
# 4. VALIDACIÓN DE INTEGRIDAD (POST-MORTEM)
# ==========================================
echo ""
echo "[recovery] 3. Validando salud del sistema recuperado..."

echo "REPORTE DE RECUPERACIÓN - $DT" > "$REPORT_FILE"

# A) Verificar que los archivos existen (ls -R)
echo "--- INVENTARIO RECUPERADO ---" >> "$REPORT_FILE"
echo " -> Listando archivos recuperados..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -ls -R $PROD_PATH" >> "$REPORT_FILE"

# B) Verificar integridad de bloques (FSCK)
echo -e "\n--- SALUD DE BLOQUES (FSCK) ---" >> "$REPORT_FILE"
echo " -> Ejecutando chequeo médico (fsck)..."
docker exec "$NN_CONTAINER" bash -lc "hdfs fsck $PROD_PATH -blocks -locations" >> "$REPORT_FILE"

# Mostramos un resumen en pantalla para feedback inmediato
echo "    [RESUMEN FSCK]"
grep -E "HEALTHY|CORRUPT|MISSING" "$REPORT_FILE"

# ==========================================
# 5. GUARDAR EVIDENCIA
# ==========================================
echo ""
echo "[recovery] 4. Archivando evidencia..."

# Subimos el reporte a HDFS
docker cp "$REPORT_FILE" "$NN_CONTAINER:/tmp/recovery_evidence.txt"
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -put -f /tmp/recovery_evidence.txt $AUDIT_DIR/"

# Limpieza local
rm "$REPORT_FILE"

echo "========================================================"
echo "[recovery] SISTEMA RECUPERADO EXITOSAMENTE."
echo "Evidencia disponible en: $AUDIT_DIR/recovery_evidence.txt"
echo "========================================================"

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[recovery] Tiempo total de RTO (Recuperación): ${SECONDS}s"
echo "------------------------------------------------"