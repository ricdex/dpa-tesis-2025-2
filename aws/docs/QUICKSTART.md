# Quick Start Guide - ML Retries Infrastructure

Este es un guide rápido para empezar en 5 minutos.

## 1. Requisitos (5 minutos)

Asegúrate de tener instalado:

```bash
# Verificar Node.js
node --version    # Necesitas v18+
npm --version

# Verificar AWS CLI
aws --version
aws sts get-caller-identity  # Debe mostrar tu cuenta

# Verificar Docker
docker --version

# Verificar Python
python3 --version  # Necesitas Python 3.9+
```

Si algo falta, descárgalo de:
- Node.js: https://nodejs.org/
- AWS CLI: https://aws.amazon.com/cli/
- Docker: https://www.docker.com/

## 2. Entrenar el Modelo (offline)

```bash
# Desde la raíz del proyecto
python3 ejecutar-evaluacion-algoritmos.py
```

Esto genera:
- `mejor_modelo.pkl` ← Lo necesitas para la inferencia
- `metrics_resultados.csv` ← Métricas del modelo

## 3. Setup Automático (10 minutos)

Ejecuta el script de setup que hace TODO automáticamente:

```bash
./scripts/setup-and-deploy.sh
```

Este script:
1. ✓ Instala dependencias Node.js
2. ✓ Compila el código TypeScript
3. ✓ Valida la síntesis de CDK
4. ✓ Despliega la infraestructura en AWS
5. ✓ Sube el modelo a S3

**Eso es todo.** Ahora tienes:
- S3 Bucket con el modelo
- Lambda de inferencia lista
- State Machine de reintentos

## 4. Testing Rápido

### Test 1: Invocar Lambda directamente

```bash
./scripts/test-lambda.sh
```

**Salida esperada:**
```json
{
  "statusCode": 200,
  "body": {
    "probabilidad_exito": 0.78,
    "reintentar": true,
    "threshold_usado": 0.3
  }
}
```

### Test 2: Ejecutar State Machine

```bash
./scripts/test-state-machine.sh
```

**Salida esperada:**
```
✓ Ejecución completada exitosamente
Estado final:
{
  "status": "SUCCEEDED",
  ...
}
```

## 5. Usar la Infraestructura

### Opción A: Invocar Lambda desde CLI

```bash
# Obtener nombre de la Lambda
LAMBDA_NAME=$(aws lambda list-functions \
  --query "Functions[?contains(FunctionName, 'InferenceLambda')].FunctionName" \
  --output text)

# Crear evento
cat > payload.json << 'EOF'
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
EOF

# Invocar
aws lambda invoke \
  --function-name ${LAMBDA_NAME} \
  --payload file://payload.json \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json | jq
```

### Opción B: Usar con aplicación integrada

```python
import boto3
import json

client = boto3.client('lambda')

response = client.invoke(
    FunctionName='MlRetriesStack-InferenceLambda...',
    InvocationType='RequestResponse',
    Payload=json.dumps({
        "monto": 150.0,
        "delta_horas": 5.0,
        "retry_hour": 10,
        "retry_dayofweek": 2,
        "retry_is_weekend": 0,
        "error_categoria": "cliente_4xx",
        "detalle_fail": "Saldo insuficiente",
        "retry_hora_bucket": "manana"
    })
)

result = json.loads(response['Payload'].read())
print(result['body'])
```

### Opción C: Usar Step Functions para procesar múltiples reintentos

```bash
# Obtener ARN de la State Machine
STATE_MACHINE_ARN=$(aws cloudformation describe-stacks \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
  --output text)

# Crear evento con múltiples reintentos
cat > input.json << 'EOF'
{
  "retries": [
    {
      "monto": 150.0,
      "delta_horas": 5.0,
      "retry_hour": 10,
      "retry_dayofweek": 2,
      "retry_is_weekend": 0,
      "error_categoria": "cliente_4xx",
      "detalle_fail": "Saldo insuficiente",
      "retry_hora_bucket": "manana"
    },
    {
      "monto": 250.0,
      "delta_horas": 24.0,
      "retry_hour": 14,
      "retry_dayofweek": 3,
      "retry_is_weekend": 0,
      "error_categoria": "servicio_5xx",
      "detalle_fail": "Timeout",
      "retry_hora_bucket": "tarde"
    }
  ]
}
EOF

# Ejecutar
aws stepfunctions start-execution \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --input file://input.json
```

## 6. Configuración (Opcional)

### Cambiar el umbral de decisión

Por defecto es 0.3. Para cambiar a 0.5:

```bash
LAMBDA_NAME=$(aws lambda list-functions \
  --query "Functions[?contains(FunctionName, 'InferenceLambda')].FunctionName" \
  --output text)

aws lambda update-function-configuration \
  --function-name ${LAMBDA_NAME} \
  --environment Variables={THRESHOLD=0.5}
```

### Ver logs en tiempo real

```bash
aws logs tail /aws/lambda/ml-retries-inference --follow
```

## 7. Limpiar (Opcional)

Para destruir toda la infraestructura de forma segura:

```bash
bash scripts/destroy.sh
```

El script automáticamente:
- ✓ Muestra advertencia crítica sobre pérdida de datos
- ✓ Requiere confirmación manual (escribir 'eliminar-todo')
- ✓ Elimina CloudFormation stack completo
- ✓ Espera a que la eliminación se complete (máx 10 minutos)
- ✓ Muestra estado en tiempo real

## 8. Troubleshooting

### Error: "No se encuentra el modelo"

```bash
# Verificar que el modelo está en S3
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ModelBucketName`].OutputValue' \
  --output text)

aws s3 ls s3://${BUCKET}/models/

# Si no está, subirlo:
aws s3 cp mejor_modelo.pkl s3://${BUCKET}/models/mejor_modelo.pkl
```

### Error: "Permission denied"

```bash
# Verificar que la Lambda tiene permisos en S3
aws lambda get-policy --function-name ${LAMBDA_NAME}
```

### Lambda timeout

En `lib/ml-retries-stack.ts`, cambiar:
```typescript
timeout: cdk.Duration.seconds(120),  // de 60 a 120
```

Luego: `npm run build && npx cdk deploy`

## 9. Documentación Completa

Para detalles técnicos, ver:
- **README.md** - Documentación completa
- **lambda/lambda_predict_reintento.py** - Código fuente del handler (bien comentado)
- **lib/ml-retries-stack.ts** - Definición de infraestructura (bien documentada)

## 10. Estructura de Datos

### Input esperado por Lambda

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

### Output de Lambda

```json
{
  "statusCode": 200,
  "body": {
    "probabilidad_exito": 0.78,
    "reintentar": true,
    "threshold_usado": 0.3
  }
}
```

---

**¿Preguntas?** Ver README.md para documentación completa.
