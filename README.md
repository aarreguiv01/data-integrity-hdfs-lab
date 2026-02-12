# DataSecure Lab — Integridad de Datos en Big Data (HDFS)

Repositorio base del proyecto práctico **Integridad de Datos en Big Data** usando un ecosistema **Hadoop dockerizado** del aula.

-  Enunciado: `docs/enunciado_proyecto.md`
-  Rúbrica: `docs/rubric.md`
-  Pistas rápidas: `docs/pistas.md`
-  Entrega (individual): `docs/entrega.md`
-  Plantilla de evidencias: `docs/evidencias.md`

---

## Quickstart (para corrección)

```bash
cd docker/clusterA && docker compose up -d
bash scripts/00_bootstrap.sh && bash scripts/10_generate_data.sh && bash scripts/20_ingest_hdfs.sh
bash scripts/30_fsck_audit.sh && bash scripts/40_backup_copy.sh && bash scripts/50_inventory_compare.sh
bash scripts/70_incident_simulation.sh && bash scripts/80_recovery_restore.sh
```

> Si algún script necesita variables:  
> `DT=YYYY-MM-DD` (fecha) y `NN_CONTAINER=namenode` (nombre del contenedor NameNode).

---

## Servicios y UIs
- NameNode UI: http://localhost:9870
- ResourceManager UI: http://localhost:8088
- Jupyter (NameNode): http://localhost:8889

---

## Estructura del repositorio
- `docker/clusterA/`: docker-compose del aula (Cluster A)
- `scripts/`: pipeline (generación → ingesta → auditoría → backup → incidente → recuperación)
- `notebooks/`: análisis en Jupyter (tabla de auditorías y métricas)
- `docs/`: documentación (enunciado, rúbrica, pistas, entrega, evidencias)

---

## Normas de entrega (individual)
Consulta `docs/entrega.md`.  
**Obligatorio:** tag final `v1.0-entrega`.

---

## Nota
Este repositorio es un “starter kit”: algunos scripts contienen **TODOs** para completar el proyecto.


## Descripción del Proyecto
Este es un proyecto sobre la integridad de datos en sistemas BIG DATA, trabajando sobre un ecosistema HADOOP dockerizado. El objetivo es construir un flujo reproducible que permita:

• Generar y organizar un dataset realista (logs + IoT).
• Ingerirlo en HDFS con estructura particionada por fecha.
• Auditar la integridad de los datos (detección temprana) y guardar evidencias.
• Copiar datos a una zona de backup y validar que la copia es consistente.
• Simular un incidente (caída de nodo o problema de replicación) y demostrar
recuperación.
• Medir el coste (tiempo/recursos) y justificar decisiones (replicación, auditoría, etc.)

## Modalidad y trabajo
Para empezar a hacer esta practica lo primero que debemos hacer es un fork del repositorio de GitHub proporcionado por el profesor: https://github.com/josedavidmi/data-integrity-hdfs-lab.git

## Requisitos técnicos
Para que la práctica sea realista, se recomienda levantar:

• Base recomendada: 3 DataNodes.
• Extra / reto: 4 DataNodes.

En mi caso será con 3 Datanodes: docker compose up -d --scale dnnm=3


## SCRIPTS

## 00_bootstrap.sh (Preparar el terreno)
Antes de empezar a trabajar, necesitamos preparar la "casa". Este script se encarga de construir las habitaciones (carpetas) donde guardaremos los datos, las copias de seguridad y los informes de auditoría. Además, reparte las llaves (permisos) para asegurarse de que todos los procesos tengan acceso libre para escribir y leer sin problemas.

## 10_generate_data.sh (Crear los datos de prueba)
Como no tenemos usuarios reales conectados ahora mismo, este script hace de "actor". Se inventa datos falsos pero realistas: simula registros de una página web (Logs) y lecturas de sensores de temperatura (IoT). Crea archivos grandes (300MB) a propósito para que el sistema tenga que esforzarse y dividir el trabajo, simulando un día de carga real.

## 20_ingest_hdfs.sh (La mudanza)
Aquí es donde movemos los muebles. Este script toma los datos que acabamos de inventar en nuestro ordenador y los sube a la "nube" del clúster (HDFS). Se asegura de colocarlos ordenadamente en sus carpetas correspondientes y verifica que hayan llegado completos, sin perder ni un solo byte por el camino.

## 30_fsck_audit.sh (El chequeo médico)
Este es el doctor del sistema. Examina los datos que hemos subido para ver si están "sanos". Busca si hay piezas rotas (corruptas) o si faltan trozos de archivos. Al final, nos da un informe de salud y lo guarda para que tengamos un historial de que todo estaba bien en ese momento.

## 40_backup_copy.sh (La caja fuerte)
Más vale prevenir que curar. Este script toma todos nuestros datos importantes de la zona de trabajo y hace una copia idéntica en una zona de seguridad (Backup). Después de copiar, mide el tamaño de ambas carpetas para confirmarnos que la copia de seguridad es perfecta y completa.

## 50_inventory_compare.sh (El inventario)
Este script actúa como un auditor estricto. Compara, uno por uno, los archivos que tenemos en producción contra los que están en el backup. Su trabajo es detectar si falta algún archivo o si alguno tiene un tamaño diferente. Si encuentra diferencias, genera una alerta; si no, nos da el certificado de que el backup es fiel al original.

## 70_incident_simulation.sh (El simulacro de incendio)
Aquí jugamos a ser el villano. A propósito, "rompemos" una parte del sistema (apagamos un servidor) para ver si la infraestructura es resistente. Observamos cómo el sistema se queja al perder un nodo y verificamos que, al encenderlo de nuevo, el sistema sea lo bastante inteligente para auto-repararse y volver a la normalidad sin nuestra ayuda.

## 80_recovery_restore.sh (El rescate)
El escenario de pesadilla: simulamos que alguien borra por error todos los datos importantes. Este script demuestra que no hay pánico: va a la zona de seguridad (Backup), recupera la información y la restaura en su lugar original. Al final, hace un último chequeo para demostrar que, a pesar del desastre, no hemos perdido absolutamente nada.