# Evidencias (plantilla)

Incluye aquí (capturas o logs) con fecha:

## 1) NameNode UI (9870)
- Captura con DataNodes vivos y capacidad
![DataNodes](image-1.png)

## 2) Auditoría fsck
- ![Captura](image-3.png)Enlace/captura de salida (bloques/locations)
- ![Resumen](image-2.png)Resumen (CORRUPT/MISSING/UNDER_REPLICATED)

## 3) Backup + validación
- ![origen y destino](image-4.png)
![origen](image-7.png)
![destino](image-8.png)
Inventario origen vs destino
![evidencias](image-9.png)Evidencias de consistencia (tamaños/rutas)

## 4) Incidente + recuperación
- Qué hiciste, cuándo y qué efecto tuvo
- Evidencia de detección y de recuperación
![dnnm1](image-15.png)
![apagado](image-14.png)
![archivo_incidencia](image-12.png)
![salida_consola_recuperacion](image-16.png)
![restauracion_log](image-17.png)
![evidencia_recovery](image-18.png)
![evidencia_consola](image-19.png)

## 5) Métricas
- Capturas de docker stats durante replicación/copia
![script_40](image-10.png)

- Tabla de tiempos
![tiempo](image-20.png)