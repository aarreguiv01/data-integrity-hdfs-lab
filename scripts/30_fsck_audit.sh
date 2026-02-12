#!/usr/bin/env bash
set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
SECONDS=0

# Al ver una ruta que empezaba por /tmp/ dentro del comando docker exec, Git Bash la convirtió automáticamente a una ruta de Windows antes de enviarla al contenedor.
# El contenedor recibió una orden de buscar un archivo en C:/Users/..., pero dentro del contenedor (que es Linux) esa ruta no existe.
export MSYS_NO_PATHCONV=1


# --- CONFIGURACIÓN ---
NN_CONTAINER=${NN_CONTAINER:-namenode}
DT=${DT:-$(date +%F)}

echo "[fsck] Iniciando auditoría de integridad para fecha: $DT"

# 1. PREPARACIÓN
# Creamos la carpeta en HDFS donde guardaremos los informes de hoy
# || true evita que falle si ya existe
echo "   -> Creando directorio de auditoría en HDFS..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p /audit/fsck/$DT"

# Definimos nombres de archivos temporales
RAW_REPORT="/tmp/fsck_full_$DT.txt"
SUMMARY_REPORT="/tmp/fsck_summary_$DT.txt"

# ---------------------------------------------------------
# 2. EJECUTAR FSCK (El chequeo médico)
# ---------------------------------------------------------
echo "   -> Ejecutando 'hdfs fsck' sobre /data..."
# -files: lista archivos
# -blocks: lista bloques
# -locations: dice en qué nodo está cada bloque
# Nota: Esto puede tardar si hay muchos datos.
docker exec "$NN_CONTAINER" bash -lc "hdfs fsck /data -files -blocks -locations > $RAW_REPORT"

# ---------------------------------------------------------
# 3. GENERAR RESUMEN (Extraer métricas clave)
# ---------------------------------------------------------
echo "   -> Generando resumen de métricas..."

# Usamos grep para buscar las líneas importantes dentro del reporte
docker exec "$NN_CONTAINER" bash -lc "echo '--- RESUMEN DE INTEGRIDAD ($DT) ---' > $SUMMARY_REPORT"
docker exec "$NN_CONTAINER" bash -lc "grep -i 'Total blocks' $RAW_REPORT >> $SUMMARY_REPORT"
docker exec "$NN_CONTAINER" bash -lc "grep -i 'CORRUPT blocks' $RAW_REPORT >> $SUMMARY_REPORT"
docker exec "$NN_CONTAINER" bash -lc "grep -i 'MISSING blocks' $RAW_REPORT >> $SUMMARY_REPORT"
docker exec "$NN_CONTAINER" bash -lc "grep -i 'Under-replicated blocks' $RAW_REPORT >> $SUMMARY_REPORT"
docker exec "$NN_CONTAINER" bash -lc "grep -i 'Mis-replicated blocks' $RAW_REPORT >> $SUMMARY_REPORT"

# ---------------------------------------------------------
# 4. GUARDAR EVIDENCIAS EN HDFS
# ---------------------------------------------------------
echo "   -> Guardando informes en HDFS (/audit/fsck/$DT/)..."

# Subimos el reporte completo y el resumen
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -put -f $RAW_REPORT /audit/fsck/$DT/"
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -put -f $SUMMARY_REPORT /audit/fsck/$DT/"

# ---------------------------------------------------------
# 5. MOSTRAR RESULTADO EN PANTALLA
# ---------------------------------------------------------
echo ""
echo "[fsck] RESULTADO DEL ANÁLISIS:"
echo "=================================================="
# Mostramos el resumen que acabamos de generar
docker exec "$NN_CONTAINER" cat "$SUMMARY_REPORT"
echo "=================================================="

# Limpieza local del contenedor
docker exec "$NN_CONTAINER" rm "$RAW_REPORT" "$SUMMARY_REPORT"

echo "[fsck] Auditoría completada."

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[fsck] Tiempo total de ejecución: ${SECONDS}s"
echo "------------------------------------------------"