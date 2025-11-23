# Predicción de Éxito en Reintentos de Pagos Recurrentes

## 📚 Proyecto de Tesis de Investigación

Este es un proyecto de **investigación en Machine Learning aplicado a pagos recurrentes**, desarrollado por Ricardo Avila (17200959) para el curso de Tesis (2025-2).

### 🎯 Objetivo Principal

Desarrollar y evaluar modelos de Machine Learning que predigan la probabilidad de **éxito en un reintento de pago** cuando la suscripción ha fallado en el primer intento.

El objetivo es:
- **Entrenar** modelos offline (Random Forest, Regresión Logística, XGBoost)
- **Evaluar** su desempeño con métricas estándar (Precision, Recall, F1, AUC-ROC)
- **Calcular** el uplift de negocio respecto a estrategias baseline
- **Desplegar** el mejor modelo en AWS para inferencia en producción

---

## 🔬 Metodología

### Fase 1: Análisis Exploratorio (Offline)
```
suscripciones.xlsx  →  Carga y limpieza  →  EDA  →  Feature Engineering
```

### Fase 2: Entrenamiento (Offline)
```
Dataset  →  Train/Test Split  →  Entrenamiento  →  Evaluación  →  mejor_modelo.pkl
```

### Fase 3: Inferencia (Producción en AWS - Opcional)
```
Lambda  ←  S3 (modelo)  ←  Predicción en tiempo real
```

---

## 📦 Datos

**Archivo:** `suscripciones.xlsx`

Contiene registros de intentos de pago recurrente con campos:
- `ID Suscripción` - Identificador único
- `Fecha` - Timestamp del intento
- `Monto` - Valor del pago
- `HTTP Status Code` - Resultado (201 = éxito, otros = fallo)
- `Detalle` - Descripción del error (si aplica)

**Estructura:** Pares de intentos (fallo + segundo intento) para entrenar el modelo

---

## 🧪 Features Utilizados

### Numéricas
- `monto` - Cantidad de dinero
- `delta_horas` - Horas entre primer y segundo intento
- `retry_hour` - Hora del día del reintento (0-23)
- `retry_dayofweek` - Día de la semana (0-6)
- `retry_is_weekend` - Indicador binario de fin de semana

### Categóricas
- `error_categoria` - Tipo de error (cliente_4xx, servicio_5xx, etc.)
- `detalle_fail` - Descripción específica del error
- `retry_hora_bucket` - Bucket temporal (madrugada, mañana, tarde, noche)

### Target
- `target_exito_second` - Si el segundo intento fue exitoso (0/1)

---

## 🤖 Modelos Entrenados

Se entrenan y evalúan **3 modelos de clasificación**:

| Modelo | Tipo | Parámetros |
|--------|------|-----------|
| **Regresión Logística** | Lineal | max_iter=1000, class_weight="balanced" |
| **Random Forest** | Ensemble | n_estimators=200, max_depth=None |
| **XGBoost** | Boosting | n_estimators=200, max_depth=5 |

Se elige el modelo con **mejor F1-score** en test.

---

## 📊 Resultados

El script genera:
- **`mejor_modelo.pkl`** - Modelo serializado (pickle) con el mejor desempeño
- **`metrics_resultados.csv`** - Tabla comparativa de métricas de todos los modelos

---

## 🏗️ Arquitectura General

```
┌────────────────────────────────────────────────────────────┐
│  FASE OFFLINE (Local - Todo lo que necesitas para tesis)   │
├────────────────────────────────────────────────────────────┤
│                                                              │
│  suscripciones.xlsx                                         │
│         ↓                                                    │
│  ejecutar-evaluacion-algoritmos.py                          │
│  ├─ Carga y limpieza                                        │
│  ├─ Feature engineering                                     │
│  ├─ Entrenamiento de 3 modelos                              │
│  └─ Evaluación con métricas                                 │
│         ↓                                                    │
│  mejor_modelo.pkl + metrics_resultados.csv                 │
│                                                              │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│  FASE PRODUCCIÓN (AWS - Opcional, infraestructura IaC)     │
├────────────────────────────────────────────────────────────┤
│                                                              │
│  mejor_modelo.pkl → S3                                      │
│                     ↓                                        │
│  Lambda (Python) → Predicción en tiempo real                │
│       ↓                                                      │
│  Step Functions → Orquestación batch                        │
│                                                              │
│  Carpeta: aws/                                              │
│                                                              │
└────────────────────────────────────────────────────────────┘
```

---

## 🚀 Cómo Usar Este Proyecto

### Para Tesis (Offline - Local)

```bash
# 1. Instalar dependencias Python
pip install -r requirements.txt

# 2. Ejecutar el script de entrenamiento
python3 ejecutar-evaluacion-algoritmos.py

# Outputs:
# - mejor_modelo.pkl         (modelo entrenado)
# - metrics_resultados.csv   (resultados comparativos)
```

**Tiempo estimado:** 5-10 minutos

**Requisitos:** Solo Python 3.9+ con dependencias ML

---

### Para Producción (AWS - Opcional)

Ver archivo: **`SETUP_Y_EJECUCION.md`** → Sección "Despliegue en AWS"

Requiere:
- Cuenta AWS
- Docker
- Node.js

---

## 📂 Estructura de Carpetas

```
dpa-tesis-2025-2/
│
├── README.md                              ← Este archivo
├── SETUP_Y_EJECUCION.md                   ← Guía de ejecución y despliegue
├── requirements.txt                       ← Dependencias Python
│
├── ejecutar-evaluacion-algoritmos.py      ← Script principal (TESIS)
├── suscripciones.xlsx                     ← Datos de ejemplo
│
├── data/                                  ← Datos adicionales
├── models/                                ← Modelos entrenados
│   └── mejor_modelo.pkl                   ← Generado al ejecutar
│
├── notebooks/                             ← Jupyter notebooks
│   └── exploracion.ipynb                  ← EDA y análisis
│
└── aws/                                   ← INFRAESTRUCTURA OPCIONAL
    ├── README_AWS.md                      ← Documentación AWS
    ├── QUICKSTART_AWS.md                  ← Guía rápida AWS
    ├── bin/                               ← CDK entry point
    ├── lib/                               ← CDK stack
    ├── lambda/                            ← Handler Lambda
    ├── scripts/                           ← Scripts deployment
    ├── docs/                              ← Documentación AWS
    └── package.json                       ← Dependencias Node.js
```

---

## 📖 Documentación

### En la Raíz
- **README.md** ← Este archivo (descripción del proyecto)
- **SETUP_Y_EJECUCION.md** ← Pasos para ejecutar

### En Carpeta `aws/`
- **aws/README_AWS.md** ← Documentación técnica de AWS CDK
- **aws/QUICKSTART_AWS.md** ← Guía rápida para desplegar
- **aws/docs/** ← Documentación adicional

---

## 🧬 Tecnologías

### Offline (Tesis)
- **Python 3.9+**
- **pandas** - Manipulación de datos
- **scikit-learn** - Modelos ML
- **xgboost** - Boosting (opcional)
- **joblib** - Serialización de modelos
- **numpy** - Cálculos numéricos

### Online (Producción)
- **AWS S3** - Almacenamiento de modelo
- **AWS Lambda** - Inferencia en tiempo real
- **AWS Step Functions** - Orquestación
- **AWS CloudWatch** - Logging y monitoreo
- **AWS CDK v2** - Infrastructure as Code (TypeScript)
- **Docker** - Contenedores

---

## 📊 Resultados Esperados

Después de ejecutar `ejecutar-evaluacion-algoritmos.py`:

### 1. **mejor_modelo.pkl**
Archivo serializado del mejor modelo (Random Forest, Logistic, o XGBoost).

**Estructura:**
```python
Pipeline(
    steps=[
        ('preprocess', ColumnTransformer(...)),  # Escalado + One-hot
        ('clf', BestModel)                      # Clasificador
    ]
)
```

### 2. **metrics_resultados.csv**
Tabla comparativa con columnas:
```
modelo, threshold, accuracy, precision, recall, f1, auc_roc
```

### 3. **Uplift de Negocio**
Calculado en consola:
```
Tasa baseline (reintentar todo):    65.0%
Tasa con modelo (top 70%):          72.5%
Uplift (puntos porcentuales):       7.5%
```

---

## 🔍 Análisis y Validación

El script realiza:

✅ **Detección automática de columnas** - Busca columnas por nombre flexible
✅ **Limpieza de datos** - Elimina duplicados y valores faltantes
✅ **Feature engineering** - Crea variables derivadas de fechas y errores
✅ **Train/Test split** - Estratificado al 80/20
✅ **Validación múltiple** - Prueba 3 thresholds por modelo
✅ **Métricas completas** - Accuracy, Precision, Recall, F1, AUC-ROC
✅ **Análisis de negocio** - Cálculo de uplift vs baseline

---

## 💾 Persistencia

```
Datos de entrada
       ↓
Modelo entrenado (mejor_modelo.pkl)
       ↓
Opcional: Subir a S3 para inferencia en AWS Lambda
       ↓
Predicción en tiempo real
```

---

## ⚠️ Importante

- **Este es un proyecto de tesis de investigación**, no de producción inmediata
- **La fase offline es completamente independiente** de AWS
- **AWS es opcional** para desplegar el modelo en producción
- **No necesitas AWS para entrenar, evaluar ni probar el modelo**
- **Todos los archivos de tesis están en la raíz**

---

## 🚀 Próximos Pasos

### 1. Para Ejecutar Offline (Tesis)
→ Ver: **`SETUP_Y_EJECUCION.md`** → Sección "Ejecución Offline"

### 2. Para Desplegar en AWS (Producción)
→ Ver: **`SETUP_Y_EJECUCION.md`** → Sección "Despliegue en AWS"

### 3. Para Explorar Datos
→ Ver: **`notebooks/exploracion.ipynb`**

---

## 📝 Citación

Si usas este proyecto en tu tesis, cítalo como:

```
Proyecto de Tesis: Predicción de Éxito en Reintentos de Pagos Recurrentes
Usando Machine Learning (XGBoost, Random Forest, Regresión Logística)
Año: 2025 | Período: 2
```

---

## 👤 Autor

Ricardo Avila Dextre 17200959
Tesis de investigación 2025-2
DPA-ESAN

---

## 📞 Preguntas?

- **¿Cómo ejecuto el proyecto?** → Ver `SETUP_Y_EJECUCION.md`
- **¿Cómo despliego en AWS?** → Ver `aws/QUICKSTART_AWS.md`
- **¿Dónde está el código?** → Ver `ejecutar-evaluacion-algoritmos.py`
- **¿Cómo veo resultados?** → Ver `metrics_resultados.csv` y consola

---

**Última actualización:** Noviembre 2025
