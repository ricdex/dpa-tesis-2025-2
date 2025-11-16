# Setup y Ejecución

Guía para ejecutar el proyecto **offline (para tesis)** y opcionalmente **en AWS (para producción)**.

---

## 🟢 FASE 1: EJECUCIÓN OFFLINE (Tesis Local)

### Requisitos

Necesitas solo **Python 3.9 o superior**:

```bash
python3 --version    # Verifica que sea >= 3.9
```

### Instalación de Dependencias

```bash
# En la raíz del proyecto
pip install -r requirements.txt
```

**Dependencias principales:**
- pandas - Manipulación de datos
- numpy - Cálculos numéricos
- scikit-learn - Modelos ML
- xgboost - Boosting (opcional)
- joblib - Serialización

### Ejecutar el Entrenamiento

```bash
# En la raíz del proyecto
python3 ejecutar-evaluacion-algoritmos.py
```

### Salida Esperada

El script generará **2 archivos**:

```
models/
├── mejor_modelo.pkl              ← Modelo entrenado (pickle)
└── metrics_resultados.csv        ← Tabla de métricas

Consola:
├─ === 1) Carga y limpieza ===
├─ Registros tras limpieza: XXXX
├─ === 2) Construcción de pares ===
├─ Casos (pares) construidos: XXXX
├─ === 3) Features y split estratificado ===
├─ === 4) Entrenamiento y evaluación ===
├─ [Métricas de cada modelo...]
├─ Mejor modelo: [random_forest|xgboost|logistic_regression] (F1=X.XXXX)
├─ === 5) Uplift de negocio ===
├─ Tasa baseline: X.XXXX
├─ Tasa con modelo: X.XXXX
└─ Uplift: XX.XXX%
```

### Verificación

Verifica que se crearon los archivos:

```bash
ls -lh models/mejor_modelo.pkl
cat metrics_resultados.csv
```

**¡Listo!** Ya tienes el modelo entrenado y listo para usar.

---

## 📚 Análisis de Resultados

Los resultados del entrenamiento se encuentran en:

### 1. `models/mejor_modelo.pkl`
Archivo serializado con el modelo entrenado. Contiene:
- Preprocesador (StandardScaler + OneHotEncoder)
- Clasificador entrenado (Random Forest, XGBoost o Logistic Regression)

**Uso:**
```python
import joblib
modelo = joblib.load('models/mejor_modelo.pkl')
predicciones = modelo.predict_proba(X_test)
```

### 2. `metrics_resultados.csv`
Tabla comparativa de los 3 modelos:

```
modelo,threshold,accuracy,precision,recall,f1,auc_roc
random_forest,0.3,0.7234,0.6543,0.7891,0.7185,0.7856
xgboost,0.4,0.7145,0.6234,0.7654,0.6923,0.7623
logistic_regression,0.5,0.6987,0.5876,0.7234,0.6521,0.7234
```

### 3. Consola (Uplift de Negocio)
El script calcula automáticamente:
```
Tasa baseline (reintentar todo):   65.0%
Tasa con modelo (top 70%):         72.5%
Uplift (puntos porcentuales):      7.5%
```

---

## 🔬 Usar el Modelo Entrenado

### Opción A: En Python Local

```python
import joblib
import pandas as pd

# Cargar modelo
modelo = joblib.load('models/mejor_modelo.pkl')

# Preparar datos
evento = pd.DataFrame({
    'monto': [150.0],
    'delta_horas': [5.0],
    'retry_hour': [10],
    'retry_dayofweek': [2],
    'retry_is_weekend': [0],
    'error_categoria': ['cliente_4xx'],
    'detalle_fail': ['Saldo insuficiente'],
    'retry_hora_bucket': ['manana']
})

# Predicción
probabilidad = modelo.predict_proba(evento)[:, 1][0]
decision = 'Reintentar' if probabilidad >= 0.3 else 'No reintentar'

print(f"Probabilidad de éxito: {probabilidad:.2%}")
print(f"Decisión: {decision}")
```

### Opción B: En Jupyter Notebook

Ver archivo: `notebooks/exploracion.ipynb`

```bash
jupyter notebook notebooks/exploracion.ipynb
```

---

## 🔴 FASE 2: DESPLIEGUE EN AWS (Opcional)

### ⚠️ Importante
**AWS es completamente opcional**. Solo si quieres desplegar el modelo en producción con inferencia en tiempo real.

---

### Requisitos para AWS

- Node.js >= 18.x
- npm >= 9.x
- AWS CLI v2 (configurado con credenciales)
- Docker (instalado y corriendo)

### Verificar Requisitos

```bash
node --version          # >= v18.x
npm --version           # >= 9.x
aws --version           # v2
aws sts get-caller-identity  # Verifica credenciales
docker --version        # Verifica Docker corriendo
```

---

### Setup de AWS

#### 1. Navegar a la carpeta AWS

```bash
cd aws
```

#### 2. Instalar Dependencias Node.js

```bash
npm install
```

#### 3. Compilar TypeScript

```bash
npm run build
```

#### 4. Validar Síntesis de CDK

```bash
npx cdk synth
```

---

### Deployment Automático

**Se recomienda usar el script automático:**

```bash
# Desde la carpeta aws/
bash scripts/setup-and-deploy.sh
```

Este script:
1. Verifica todos los requisitos
2. Instala dependencias
3. Compila el código
4. Valida la síntesis
5. Despliega en AWS
6. Sube el modelo a S3

**Tiempo estimado:** 15-20 minutos

---

### Deployment Manual (Alternativa)

Si prefieres hacerlo paso a paso:

```bash
# 1. Asegúrate de que mejor_modelo.pkl existe
ls ../models/mejor_modelo.pkl

# 2. Desplegar stack
npx cdk deploy

# 3. Obtener nombre del bucket
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ModelBucketName`].OutputValue' \
  --output text)

# 4. Subir modelo a S3
aws s3 cp ../models/mejor_modelo.pkl s3://${BUCKET}/models/mejor_modelo.pkl
```

---

### Testing de AWS

Una vez desplegado:

```bash
# Test Lambda directa
bash scripts/test-lambda.sh

# Test State Machine (batch)
bash scripts/test-state-machine.sh
```

---

### Ver Logs

```bash
aws logs tail /aws/lambda/ml-retries-inference --follow
```

---

### Destruir Infraestructura

Cuando ya no necesites AWS:

```bash
# Desde la carpeta aws/
npx cdk destroy

# Limpiar bucket S3
aws s3 rm s3://${BUCKET} --recursive
aws s3 rb s3://${BUCKET}
```

---

## 📂 Estructura Final

Después de ejecutar todo:

```
dpa-tesis-2025-2/
│
├── README.md                              ← Descripción proyecto
├── SETUP_Y_EJECUCION.md                   ← Este archivo
├── requirements.txt                       ← Dependencias Python
│
├── ejecutar-evaluacion-algoritmos.py      ← Script principal
├── suscripciones.xlsx                     ← Datos de entrada
│
├── models/
│   ├── mejor_modelo.pkl                   ← Generado ✓
│   └── metrics_resultados.csv             ← Generado ✓
│
├── notebooks/
│   └── exploracion.ipynb                  ← Análisis
│
└── aws/                                   ← OPCIONAL
    ├── README_AWS.md
    ├── QUICKSTART_AWS.md
    ├── bin/
    ├── lib/
    ├── lambda/
    ├── scripts/
    ├── docs/
    └── package.json
```

---

## ✅ Checklist de Ejecución

### Fase Offline (Tesis)
- [ ] Verificar Python 3.9+
- [ ] Instalar dependencias: `pip install -r requirements.txt`
- [ ] Ejecutar: `python3 ejecutar-evaluacion-algoritmos.py`
- [ ] Verificar salida: `models/mejor_modelo.pkl`
- [ ] Revisar métricas: `metrics_resultados.csv`

### Fase AWS (Producción)
- [ ] Verificar requisitos (Node, npm, AWS CLI, Docker)
- [ ] Entrar a carpeta: `cd aws`
- [ ] Instalar deps: `npm install`
- [ ] Desplegar: `bash scripts/setup-and-deploy.sh`
- [ ] Testear: `bash scripts/test-lambda.sh`
- [ ] Ver logs: `aws logs tail /aws/lambda/ml-retries-inference --follow`

---

## 🆘 Troubleshooting

### Error: "No module named pandas"

```bash
pip install -r requirements.txt
```

### Error: "suscripciones.xlsx not found"

Asegúrate de estar en la raíz del proyecto:
```bash
ls suscripciones.xlsx
```

### Error: "mejor_modelo.pkl not found" (AWS)

El archivo debe estar en `models/`:
```bash
ls models/mejor_modelo.pkl
```

### Error: AWS CLI no configurado

```bash
aws configure
aws sts get-caller-identity
```

### Error: Docker no está corriendo

Inicia Docker:
```bash
docker ps  # Verifica que funciona
```

### Error: Node/npm no encontrado

Instala desde: https://nodejs.org/

---

## 📖 Documentación Completa

Para más detalles, ver:

- **Fase Offline (Tesis):** Ver `README.md`
- **Fase AWS (Producción):** Ver `aws/README_AWS.md` y `aws/QUICKSTART_AWS.md`
- **Análisis Técnico:** Ver `aws/docs/`

---

## 🎯 Resumen Rápido

### Solo Tesis (Local)
```bash
pip install -r requirements.txt
python3 ejecutar-evaluacion-algoritmos.py
# → Genera: models/mejor_modelo.pkl + metrics_resultados.csv
```

### Con AWS (Producción)
```bash
pip install -r requirements.txt
python3 ejecutar-evaluacion-algoritmos.py
cd aws
bash scripts/setup-and-deploy.sh
# → Despliega en AWS + sube modelo a S3
bash scripts/test-lambda.sh
bash scripts/test-state-machine.sh
```

---

**Última actualización:** Noviembre 2025
