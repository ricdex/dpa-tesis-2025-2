# Manifest - Archivos Creados para Infraestructura de ML

Este documento lista todos los archivos creados como parte de la infraestructura AWS CDK para inferencia de modelos ML de reintentos de pagos.

## Índice

- [CDK - Infraestructura (TypeScript)](#cdk---infraestructura-typescript)
- [Lambda - Inferencia (Python)](#lambda---inferencia-python)
- [Scripts - Deployment y Testing](#scripts---deployment-y-testing)
- [Documentación](#documentación)
- [Configuración](#configuración)

---

## CDK - Infraestructura (TypeScript)

### `bin/app.ts` (Entry Point)
**Propósito:** Punto de entrada de la aplicación CDK.

**Contenido:**
- Instancia la aplicación CDK
- Define el stack `MlRetriesStack`
- Configura región y cuenta de AWS
- Sintetiza el template de CloudFormation

**Tamaño:** ~30 líneas

---

### `lib/ml-retries-stack.ts` (Stack Principal)
**Propósito:** Define toda la infraestructura en AWS.

**Componentes creados:**
1. **S3 Bucket** (`modelBucket`)
   - Nombre: `ml-retries-model-{ACCOUNT}-{REGION}`
   - Versionado: Sí
   - Encriptación: SSE-S3
   - Acceso público: Bloqueado

2. **Lambda Function** (`inferenceLambda`)
   - Tipo: `DockerImageFunction`
   - Runtime: Python 3.11
   - Timeout: 60 segundos
   - Memoria: 512 MB
   - Log Group: Retención 30 días
   - Variables de entorno: MODEL_BUCKET, MODEL_KEY, THRESHOLD, LOG_LEVEL
   - Permisos IAM: s3:GetObject en el bucket

3. **Step Functions State Machine** (`retriesStateMachine`)
   - Tipo: Standard
   - Flujo: Map → Lambda → Choice → Decision
   - Procesamiento: Hasta 5 reintentos en paralelo

**Outputs:**
- ModelBucketName
- InferenceLambdaArn
- StateMachineArn
- LambdaLogGroupName

**Tamaño:** ~180 líneas

---

## Lambda - Inferencia (Python)

### `lambda/lambda_predict_reintento.py` (Handler Principal)
**Propósito:** Handler de AWS Lambda para predicción de reintentos.

**Funcionalidades:**
1. **Carga de Modelo** (global, una sola vez)
   - Desde S3 al inicializarse la Lambda
   - Caching en memoria (_model global)

2. **Validación de Entrada**
   - Verifica que todos los campos requeridos estén presentes
   - Valida tipos de datos (numéricos vs categóricos)

3. **Preprocesamiento de Features**
   - Convierte evento JSON a DataFrame
   - Mantiene orden correcto de columnas

4. **Predicción**
   - Usa `predict_proba` del modelo
   - Retorna probabilidad de éxito
   - Aplica umbral para decisión binaria

5. **Respuesta**
   - statusCode 200 para éxito, 400 para error, 500 para excepción
   - Body con: probabilidad_exito, reintentar, threshold_usado

**Estructura esperada de entrada:**
```json
{
  "monto": 150.0,
  "delta_horas": 5.0,
  "retry_hour": 10,
  "retry_dayofweek": 2,
  "retry_is_weekend": 0,
  "error_categoria": "cliente_4xx",
  "detalle_fail": "Saldo insuficiente",
  "retry_hora_bucket": "manana"
}
```

**Tamaño:** ~280 líneas (bien comentadas)

---

### `lambda/Dockerfile`
**Propósito:** Define la imagen Docker para la Lambda.

**Base:** `public.ecr.aws/lambda/python:3.11`

**Acciones:**
1. Copia requirements.txt
2. Instala dependencias Python
3. Copia handler Python
4. Establece entrypoint: `lambda_predict_reintento.lambda_handler`

**Tamaño:** ~12 líneas

---

### `lambda/requirements.txt`
**Propósito:** Define las dependencias Python de la Lambda.

**Paquetes:**
- `boto3` - Cliente AWS
- `joblib` - Carga/almacenamiento de modelos
- `pandas` - Manipulación de datos
- `numpy` - Operaciones numéricas
- `scikit-learn` - Preprocesamiento ML (OneHotEncoder, StandardScaler)
- `xgboost` - Modelo XGBoost (si aplica)

**Tamaño:** ~6 líneas

---

## Scripts - Deployment y Testing

### `scripts/setup-and-deploy.sh`
**Propósito:** Automatiza todo el proceso de setup e instalación.

**Pasos:**
1. Verifica requisitos (Node.js, npm, AWS CLI, Docker)
2. Instala dependencias Node.js
3. Compila TypeScript
4. Valida síntesis de CDK
5. Valida que mejor_modelo.pkl existe
6. Despliega el stack en AWS
7. Sube el modelo a S3

**Uso:**
```bash
./scripts/setup-and-deploy.sh
```

**Tamaño:** ~190 líneas

---

### `scripts/test-lambda.sh`
**Propósito:** Testing manual de la Lambda de inferencia.

**Acciones:**
1. Busca la Lambda desplegada
2. Crea 3 eventos de prueba (válidos e inválido)
3. Invoca la Lambda con cada evento
4. Muestra las respuestas formateadas

**Uso:**
```bash
./scripts/test-lambda.sh
```

**Tamaño:** ~80 líneas

---

### `scripts/test-state-machine.sh`
**Propósito:** Testing de la State Machine end-to-end.

**Acciones:**
1. Obtiene ARN de la State Machine
2. Crea input con múltiples reintentos
3. Ejecuta la State Machine
4. Monitorea el progreso
5. Muestra resultados finales

**Uso:**
```bash
./scripts/test-state-machine.sh
```

**Tamaño:** ~100 líneas

---

## Documentación

### `README.md` (Documentación Completa)
**Propósito:** Documentación técnica y detallada del proyecto.

**Secciones:**
1. Descripción general y arquitectura
2. Requisitos previos
3. Estructura del proyecto
4. Instalación y configuración paso a paso
5. Preparación del modelo
6. Testing (4 niveles)
7. Monitoreo y debugging
8. Configuración y variables de entorno
9. Limpieza y destrucción
10. Troubleshooting
11. Estructura entrada/salida
12. Costos estimados
13. Referencias

**Público:** Desarrolladores y arquitectos técnicos
**Tamaño:** ~650 líneas

---

### `QUICKSTART.md` (Guía Rápida)
**Propósito:** Guía acelerada para empezar en 5-10 minutos.

**Secciones:**
1. Verificación rápida de requisitos
2. Entrenar el modelo
3. Setup automático (un comando)
4. Testing rápido (dos comandos)
5. Tres opciones de uso
6. Configuración opcional
7. Limpiar
8. Troubleshooting básico
9. Referencias a documentación completa

**Público:** Usuarios que quieren empezar rápido
**Tamaño:** ~250 líneas

---

### `MANIFEST.md` (Este archivo)
**Propósito:** Inventario de todos los archivos creados.

**Contenido:**
- Lista de archivos
- Propósito de cada uno
- Estructura y contenido principales
- Guía de lectura

**Tamaño:** ~Este archivo

---

## Configuración

### `package.json`
**Propósito:** Define las dependencias Node.js y scripts del proyecto.

**Scripts principales:**
- `npm install` - Instala dependencias
- `npm run build` - Compila TypeScript
- `npm run cdk:synth` - Valida síntesis de CDK
- `npm run cdk:deploy` - Despliega el stack
- `npm run cdk:destroy` - Destruye el stack

**Dependencias principales:**
- `aws-cdk-lib` - Librería de CDK v2
- `constructs` - Sistema de construcción de CDK
- `typescript` - Compilador TypeScript

**Tamaño:** ~30 líneas

---

### `tsconfig.json`
**Propósito:** Configuración del compilador TypeScript.

**Configuración:**
- Target: ES2020
- Module: CommonJS
- Output: ./dist
- Strict mode: Habilitado
- Resolución JSON: Habilitada

**Tamaño:** ~15 líneas

---

### `cdk.json`
**Propósito:** Configuración de la aplicación CDK.

**Configuración:**
- Comando app: `npx ts-node bin/app.ts`
- Context para compatibilidad
- Watch patterns (para desarrollo)

**Tamaño:** ~25 líneas

---

### `.env.example`
**Propósito:** Plantilla de variables de entorno.

**Variables:**
- AWS_REGION
- AWS_ACCOUNT_ID
- LAMBDA_LOG_LEVEL
- LAMBDA_THRESHOLD
- LAMBDA_MODEL_KEY

**Uso:** Copiar a `.env` y ajustar valores

**Tamaño:** ~12 líneas

---

### `.gitignore`
**Propósito:** Ignora archivos no versionables.

**Patrones:**
- Node.js: node_modules, dist, compiled JS
- Python: __pycache__, venv, .egg-info
- CDK: cdk.out, cdk.context.json
- IDE: .vscode, .idea
- OS: .DS_Store, Thumbs.db
- Local: mejor_modelo.pkl, .env
- Datos: suscripciones.xlsx

**Tamaño:** ~35 líneas

---

## Archivos Originales (No Modificados)

### `ejecutar-evaluacion-algoritmos.py`
**Propósito:** Script original de entrenamiento del modelo.
- No se modificó para mantener compatibilidad
- Genera mejor_modelo.pkl necesario para inferencia

### `suscripciones.xlsx`
**Propósito:** Datos de ejemplo para entrenamiento.
- No versionado (en .gitignore)

---

## Resumen de Archivos

| Categoría | Archivo | Propósito |
|-----------|---------|----------|
| **CDK Entry** | bin/app.ts | Punto de entrada del CDK |
| **CDK Stack** | lib/ml-retries-stack.ts | Definición de infraestructura |
| **Lambda Handler** | lambda/lambda_predict_reintento.py | Lógica de predicción |
| **Lambda Config** | lambda/Dockerfile | Imagen Docker |
| **Lambda Deps** | lambda/requirements.txt | Dependencias Python |
| **Scripts** | scripts/setup-and-deploy.sh | Setup automático |
| **Scripts** | scripts/test-lambda.sh | Testing de Lambda |
| **Scripts** | scripts/test-state-machine.sh | Testing de State Machine |
| **Docs** | README.md | Documentación completa |
| **Docs** | QUICKSTART.md | Guía rápida |
| **Docs** | MANIFEST.md | Este archivo |
| **Config** | package.json | Dependencias Node.js |
| **Config** | tsconfig.json | Config TypeScript |
| **Config** | cdk.json | Config CDK |
| **Config** | .env.example | Template de env vars |
| **Config** | .gitignore | Archivos ignorados |

**Total:** 15 archivos nuevos

---

## Recomendación de Lectura

### Para empezar rápido:
1. **QUICKSTART.md** ← Empieza aquí
2. Ejecuta: `./scripts/setup-and-deploy.sh`
3. Ejecuta: `./scripts/test-lambda.sh`

### Para entender la infraestructura:
1. **README.md** - Documentación técnica
2. **lib/ml-retries-stack.ts** - Definición de recursos
3. **lambda/lambda_predict_reintento.py** - Lógica de predicción

### Para debugging:
1. Ver logs: `aws logs tail /aws/lambda/ml-retries-inference --follow`
2. Troubleshooting en **README.md**

---

## Notas Importantes

- **No modificar** `ejecutar-evaluacion-algoritmos.py` (mantener integridad del script original)
- **Subir modelo a S3** después del deploy (paso manual)
- **Configurar AWS CLI** antes de ejecutar scripts
- **Docker debe estar corriendo** para el deploy
- **Costos estimados:** ~$1/mes para prueba/desarrollo

---

**Documento actualizado:** Noviembre 2025
