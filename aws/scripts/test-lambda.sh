#!/bin/bash

# Script para testing de la Lambda de Inferencia
# Uso: ./scripts/test-lambda.sh

set -e

# Obtener región desde AWS CLI o usar default
REGION=$(aws configure get region || echo "us-east-1")

echo "========================================="
echo "Testing de Lambda de Inferencia"
echo "========================================="
echo "Región: ${REGION}"
echo ""

# Obtener el nombre de la Lambda
echo "Buscando Lambda..."
LAMBDA_NAME=$(aws lambda list-functions \
  --region "${REGION}" \
  --query "Functions[?contains(FunctionName, 'InferenceLambda')].FunctionName" \
  --output text)

if [ -z "$LAMBDA_NAME" ]; then
  echo "❌ Error: No se encontró la Lambda. ¿Has desplegado el stack?"
  echo ""
  echo "Debug: Funciones Lambda disponibles:"
  aws lambda list-functions --region "${REGION}" --query 'Functions[*].FunctionName' --output text 2>/dev/null || echo "No se pudo listar funciones"
  exit 1
fi

echo "✓ Lambda encontrada: ${LAMBDA_NAME}"
echo ""

# Caso 1: Fondos insuficientes a las 20:00 (buena hora)
echo "Caso 1: Fondos insuficientes (hora 20, buena tasa de éxito)..."
cat > /tmp/test_payload_1.json << 'EOF'
{
  "monto": 1000.0,
  "delta_horas": 2.0,
  "retry_hour": 20,
  "retry_dayofweek": 2,
  "retry_is_weekend": 0,
  "error_categoria": "cliente_4xx",
  "detalle_fail": "Fondos insuficientes. La tarjeta no tiene fondos suficientes para realizar la compra.",
  "retry_hora_bucket": "noche"
}
EOF

echo "✓ Payload 1 creado"
echo ""

echo "Invocando Lambda con evento 1..."
aws lambda invoke \
  --region "${REGION}" \
  --function-name ${LAMBDA_NAME} \
  --payload file:///tmp/test_payload_1.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/response_1.json

echo "✓ Respuesta:"
jq . /tmp/response_1.json
echo ""

# Caso 2: Límite mensual excedido a las 21:00 (mejor hora)
echo "Caso 2: Límite mensual (hora 21, mejor tasa de éxito)..."
cat > /tmp/test_payload_2.json << 'EOF'
{
  "monto": 1500.0,
  "delta_horas": 1.0,
  "retry_hour": 21,
  "retry_dayofweek": 3,
  "retry_is_weekend": 0,
  "error_categoria": "cliente_4xx",
  "detalle_fail": "Excede el límite mensual de número de compras por correo",
  "retry_hora_bucket": "noche"
}
EOF

echo "✓ Payload 2 creado"
echo ""

echo "Invocando Lambda con evento 2..."
aws lambda invoke \
  --region "${REGION}" \
  --function-name ${LAMBDA_NAME} \
  --payload file:///tmp/test_payload_2.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/response_2.json

echo "✓ Respuesta:"
jq . /tmp/response_2.json
echo ""

# Crear evento inválido (para testing de errores)
echo "Creando evento de prueba 3: Evento inválido (campo faltante)..."
cat > /tmp/test_payload_invalid.json << 'EOF'
{
  "monto": 150.0
}
EOF

echo "✓ Payload inválido creado"
echo ""

# Invocar Lambda con payload inválido
echo "Invocando Lambda con evento inválido..."
aws lambda invoke \
  --region "${REGION}" \
  --function-name ${LAMBDA_NAME} \
  --payload file:///tmp/test_payload_invalid.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/response_invalid.json

echo "✓ Respuesta recibida:"
jq . /tmp/response_invalid.json
echo ""

echo "========================================="
echo "✓ Testing completado exitosamente"
echo "========================================="
echo ""
echo "Ver logs:"
echo "  aws logs tail /aws/lambda/ml-retries-inference --follow"
