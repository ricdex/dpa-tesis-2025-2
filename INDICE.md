# Índice del Proyecto

**Proyecto de Tesis:** Predicción de Éxito en Reintentos de Pagos Recurrentes

---

## 📍 Ubícate en el Proyecto

### ¿Soy un investigador/tesista?
→ Comienza en **README.md** (raíz) y **SETUP_Y_EJECUCION.md** (raíz)

### ¿Quiero desplegar en AWS?
→ Ve a carpeta **aws/** y lee **README_AWS.md** y **QUICKSTART_AWS.md**

### ¿Necesito documentación técnica detallada?
→ Ver **aws/docs/** (documentación AWS)

---

## 📂 Archivos en la Raíz

| Archivo | Propósito |
|---------|----------|
| **README.md** | QUÉ es el proyecto (objetivo, metodología, features) |
| **SETUP_Y_EJECUCION.md** | CÓMO ejecutar (pasos offline y AWS) |
| **requirements.txt** | Dependencias Python para entrenamiento |
| **ejecutar-evaluacion-algoritmos.py** | Script principal (entrenar modelo) |
| **suscripciones.xlsx** | Datos de ejemplo |

---

## 📂 Carpetas Funcionales

| Carpeta | Contenido |
|---------|----------|
| **data/** | Datos adicionales (opcional) |
| **models/** | Modelos entrenados (generado al ejecutar) |
| **notebooks/** | Jupyter notebooks para análisis (opcional) |
| **aws/** | Infraestructura AWS CDK (opcional) |

---

## 📂 Carpeta aws/ (Infraestructura Opcional)

| Archivo | Propósito |
|---------|----------|
| **README_AWS.md** | Documentación de componentes AWS |
| **QUICKSTART_AWS.md** | Guía rápida (3 pasos) |
| **.env.example** | Template de variables de entorno |
| **package.json** | Dependencias Node.js |
| **tsconfig.json** | Config TypeScript |
| **cdk.json** | Config CDK |

---

## 📂 aws/bin/ - Entry Point CDK

| Archivo |
|---------|
| **app.ts** - Inicializa la app CDK |

---

## 📂 aws/lib/ - Stack CDK

| Archivo |
|---------|
| **ml-retries-stack.ts** - Define S3 + Lambda + Step Functions |

---

## 📂 aws/lambda/ - Función de Inferencia

| Archivo |
|---------|
| **lambda_predict_reintento.py** - Handler Python (predicción) |
| **Dockerfile** - Imagen Docker para Lambda |
| **requirements.txt** - Dependencias Python (ML) |

---

## 📂 aws/scripts/ - Automatización

| Archivo |
|---------|
| **setup-and-deploy.sh** - Deploy automático todo en uno |
| **test-lambda.sh** - Testing de Lambda |
| **test-state-machine.sh** - Testing de State Machine |

---

## 📂 aws/docs/ - Documentación Técnica

Contiene documentación detallada sobre:
- ARCHITECTURE.md - Diagramas de arquitectura
- MANIFEST.md - Inventario de archivos
- PROJECT_STRUCTURE.txt - Estructura visual
- Otros documentos técnicos

---

## 🚀 Flujo Rápido

### Solo Tesis (Local)
```
1. README.md (leer)
2. SETUP_Y_EJECUCION.md (leer sección offline)
3. pip install -r requirements.txt
4. python3 ejecutar-evaluacion-algoritmos.py
   → Genera: models/mejor_modelo.pkl
```

### Con AWS (Producción)
```
1. Ejecutar pasos de tesis (arriba)
2. cd aws/
3. README_AWS.md (leer)
4. bash scripts/setup-and-deploy.sh
   → Despliega en AWS
```

---

## 📖 Lecturas Recomendadas

**Orden de lectura:**

1. **INDICE.md** (este archivo) - 3 min
2. **README.md** - 10 min
3. **SETUP_Y_EJECUCION.md** - 10 min
4. Ejecutar script - 10 min
5. **aws/README_AWS.md** (si deseas AWS) - 5 min
6. **aws/QUICKSTART_AWS.md** (si deseas AWS) - 5 min

---

## ❓ Preguntas Frecuentes

**P: ¿Necesito AWS?**
R: No. AWS es completamente opcional. Puedes entrenar y evaluar sin AWS.

**P: ¿Dónde está el script principal?**
R: En `ejecutar-evaluacion-algoritmos.py` (raíz)

**P: ¿Dónde están los datos?**
R: En `suscripciones.xlsx` (raíz)

**P: ¿Dónde se guardan los resultados?**
R: En carpeta `models/`

**P: ¿Cómo despliego en AWS?**
R: Ve a carpeta `aws/` y lee `QUICKSTART_AWS.md`

**P: ¿Cuánto tiempo lleva ejecutar todo?**
R: Offline: ~20 minutos | Con AWS: ~35 minutos

---

## 🎯 Tu Primer Comando

```bash
# Desde la raíz del proyecto
cat README.md
```

Luego:

```bash
cat SETUP_Y_EJECUCION.md
```

Luego:

```bash
pip install -r requirements.txt
python3 ejecutar-evaluacion-algoritmos.py
```

**¡Listo!** Tienes tu modelo entrenado.

---

**Última actualización:** Noviembre 2025
