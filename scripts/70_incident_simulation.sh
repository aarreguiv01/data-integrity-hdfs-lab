#!/usr/bin/env bash

# ==============================================================================
# SCRIPT 70: SIMULACIÓN DE INCIDENTE (CHAOS ENGINEERING)
# ------------------------------------------------------------------------------
# PROPÓSITO:
# Este script pone a prueba la tolerancia a fallos de HDFS.
# 1. Verifica el estado saludable del clúster.
# 2. "Mata" intencionalmente un DataNode (simulando fallo de hardware/red).
# 3. Documenta la evidencia del fallo.
# 4. Recupera el nodo y verifica la auto-reparación del sistema.
# ==============================================================================

# --- CONFIGURACIÓN DE SEGURIDAD BASH ---
# -e: Detiene el script inmediatamente si un comando falla.
# -u: Detiene el script si se intenta usar una variable no definida.
# -o pipefail: Si falla un comando dentro de una tubería (|), todo falla.
set -euo pipefail

# --- INICIO DEL CRONÓMETRO ---
SECONDS=0

# --- CORRECCIÓN CRÍTICA PARA WINDOWS (GIT BASH) ---
# Git Bash intenta ser útil convirtiendo rutas como "/tmp" a "C:/Program Files/Git/tmp".
# Esto rompe los comandos de Docker que esperan rutas de Linux.
# Esta variable desactiva esa conversión automática.
export MSYS_NO_PATHCONV=1

# ==========================================
# 1. VARIABLES DE CONFIGURACIÓN
# ==========================================
# Nombre del contenedor NameNode (El cerebro del clúster)
NN_CONTAINER=${NN_CONTAINER:-namenode}

# Nombre del DataNode "Víctima" que vamos a detener.
# (Debe coincidir con el nombre real que ves al hacer 'docker ps')
DN_VICTIM=${DN_VICTIM:-clustera-dnnm-1} 

# Fecha actual para organizar los reportes (Formato YYYY-MM-DD)
DT=${DT:-$(date +%F)}

# Directorio en HDFS donde guardaremos la evidencia final de la auditoría
AUDIT_DIR="/audit/incident/$DT"

# Archivo temporal local donde escribiremos el reporte paso a paso.
# IMPORTANTE: Usamos "./" (ruta relativa) para evitar problemas de rutas en Windows.
REPORT_FILE="./incident_report_$DT.txt"

# --- CABECERA VISUAL ---
echo "========================================================"
echo "[incident] SIMULACRO DE FALLO EN DATANODE: $DT"
echo "[incident] Gestor (NameNode): $NN_CONTAINER"
echo "[incident] Víctima elegida:   $DN_VICTIM"
echo "========================================================"

# ==========================================
# 2. VALIDACIONES PREVIAS
# ==========================================
# Antes de empezar, nos aseguramos de que la "víctima" existe y está viva.
# Si el contenedor no está corriendo, el script se detiene para evitar errores confusos.
if ! docker ps --format '{{.Names}}' | grep -q "^${DN_VICTIM}$"; then
    echo "ERROR CRÍTICO: El contenedor '$DN_VICTIM' no está corriendo."
    echo "Por favor, verifica el nombre correcto con 'docker ps'."
    exit 1
fi

# Preparar el directorio en HDFS donde se guardará el informe final.
# '|| true' permite continuar si la carpeta ya existe.
echo "[incident] Preparando directorio de auditoría en HDFS..."
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -mkdir -p $AUDIT_DIR" || true


# ==========================================
# 3. FUNCIÓN DE CHEQUEO DE SALUD
# ==========================================
# Esta función se ejecuta en cada fase para tomar una "foto" del sistema.
# Recibe un argumento ($1) que es el nombre de la fase (ej: BASELINE, IMPACTO).
check_health() {
    local phase=$1
    echo " -> [$phase] Analizando estado del sistema..."
    
    # A) VERDAD INMEDIATA (INFRAESTRUCTURA - DOCKER)
    # Preguntamos a Docker si el contenedor está corriendo o detenido.
    # Esto es instantáneo. Si falla el comando, asumimos que está "DEAD".
    local docker_status=$(docker inspect -f '{{.State.Status}}' "$DN_VICTIM" 2>/dev/null || echo "DEAD")
    echo "    [DOCKER] Estado físico del contenedor $DN_VICTIM: $docker_status"
    
    # B) VERDAD RETARDADA (APLICACIÓN - HDFS)
    # Ejecutamos 'hdfs fsck' (File System Check) dentro del NameNode.
    # Nota: HDFS tiene un "heartbeat" (latido). Puede tardar hasta 10 mins en
    # darse cuenta de que un nodo murió. Por eso a veces dice "HEALTHY" aunque Docker diga "exited".
    docker exec "$NN_CONTAINER" bash -lc "hdfs fsck /data -blocks -locations" > ./fsck_temp.txt
    
    echo "    [HDFS] Reporte de integridad (fsck):"
    
    # Filtramos la salida para mostrar solo lo vital:
    # - HEALTHY/CORRUPT: Estado general.
    # - Under-replicated: Bloques que han perdido copias.
    # - Live datanodes: Cuántos nodos siguen vivos.
    grep -E "HEALTHY|CORRUPT|MISSING|Under-replicated|Live datanodes" ./fsck_temp.txt
    
    # C) GUARDAR EVIDENCIA
    # Escribimos los hallazgos en nuestro archivo de reporte local acumulativo.
    echo -e "\n=== FASE: $phase (Estado Docker: $docker_status) ===" >> "$REPORT_FILE"
    cat ./fsck_temp.txt >> "$REPORT_FILE"
}

# ==========================================
# 4. EJECUCIÓN DEL SIMULACRO
# ==========================================

# --- FASE 1: LÍNEA BASE (BASELINE) ---
# Comprobamos que todo está bien antes de romper nada.
echo ""
echo "[incident] 1. Estableciendo estado inicial (BASELINE)..."
echo "REPORTE DE INCIDENTE - FECHA: $DT" > "$REPORT_FILE"
check_health "BASELINE"

# --- FASE 2: EL SABOTAJE ---
# Aquí simulamos el fallo. 'docker stop' es equivalente a tirar del cable de corriente del servidor.
echo ""
echo "[incident] 2. INICIANDO SABOTAJE: APAGANDO $DN_VICTIM "
docker stop "$DN_VICTIM"
echo " -> Contenedor detenido exitosamente."

# --- FASE 3: IMPACTO ---
# Medimos el daño inmediato.
# Docker dirá "exited" (rojo), pero HDFS quizás diga "HEALTHY" (verde) temporalmente.
echo ""
echo "[incident] 3. Auditando impacto inmediato..."
echo "(INFO: Es normal si HDFS aún no marca el nodo como muerto, tarda unos minutos en confirmar)"
check_health "IMPACTO"

# --- FASE 4: RECUPERACIÓN ---
# Simulamos que el técnico ha arreglado el servidor y lo enciende de nuevo.
echo ""
echo "[incident] 4. Recuperando el servicio (Reiniciando nodo)..."
docker start "$DN_VICTIM"
echo " -> Nodo reiniciado. Esperando 20 segundos para reconexión y replicación..."
sleep 20

# --- FASE 5: ESTADO FINAL ---
# Verificamos que el clúster se ha auto-reparado y vuelve a estar sano.
echo ""
echo "[incident] 5. Verificando recuperación final..."
check_health "RECOVERY"

# ==========================================
# 5. GUARDADO Y LIMPIEZA
# ==========================================

echo ""
echo "[incident] Subiendo reporte forense a HDFS..."

# Paso 1: Copiar del PC (Host) al contenedor NameNode (/tmp)
docker cp "$REPORT_FILE" "$NN_CONTAINER:/tmp/incident_final.txt"

# Paso 2: Mover del contenedor NameNode a HDFS (/audit/incident/...)
docker exec "$NN_CONTAINER" bash -lc "hdfs dfs -put -f /tmp/incident_final.txt $AUDIT_DIR/"

# Paso 3: Borrar archivos temporales del PC para no dejar basura
rm "$REPORT_FILE" ./fsck_temp.txt

echo "========================================================"
echo "[incident] PROCESO COMPLETADO EXITOSAMENTE."
echo "Evidencia disponible en HDFS: $AUDIT_DIR/incident_final.txt"
echo "========================================================"

# --- FIN DEL CRONÓMETRO ---
echo "------------------------------------------------"
echo "[incident] Tiempo total de ejecución: ${SECONDS}s"
echo "------------------------------------------------"