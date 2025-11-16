#!/bin/bash

# Script para testing de la Lambda de Inferencia
# Uso: ./scripts/test-lambda.sh

set -e

echo "========================================="
echo "Testing de Lambda de Inferencia"
echo "========================================="

# Obtener el nombre de la Lambda
echo "Buscando Lambda..."
LAMBDA_NAME=$(aws lambda list-functions \
  --query "Functions[?contains(FunctionName, 'InferenceLambda')].FunctionName" \
  --output text)

if [ -z "$LAMBDA_NAME" ]; then
  echo "❌ Error: No se encontró la Lambda. ¿Has desplegado el stack?"
  exit 1
fi

echo "✓ Lambda encontrada: ${LAMBDA_NAME}"
echo ""

# Crear evento de prueba exitoso
echo "Creando evento de prueba 1: Caso positivo (alto riesgo de éxito)..."
cat > /tmp/test_payload_1.json << 'EOF'
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

echo "✓ Payload 1 creado"
echo ""

# Invocar Lambda con payload 1
echo "Invocando Lambda con evento 1..."
aws lambda invoke \
  --function-name ${LAMBDA_NAME} \
  --payload file:///tmp/test_payload_1.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/response_1.json

echo "✓ Respuesta recibida:"
jq . /tmp/response_1.json
echo ""

# Crear evento de prueba 2
echo "Creando evento de prueba 2: Caso con mayor delta de horas..."
cat > /tmp/test_payload_2.json << 'EOF'
{
  "monto": 250.0,
  "delta_horas": 24.0,
  "retry_hour": 14,
  "retry_dayofweek": 3,
  "retry_is_weekend": 0,
  "error_categoria": "servicio_5xx",
  "detalle_fail": "Timeout del servicio",
  "retry_hora_bucket": "tarde"
}
EOF

echo "✓ Payload 2 creado"
echo ""

# Invocar Lambda con payload 2
echo "Invocando Lambda con evento 2..."
aws lambda invoke \
  --function-name ${LAMBDA_NAME} \
  --payload file:///tmp/test_payload_2.json \
  --cli-binary-format raw-in-base64-out \
  /tmp/response_2.json

echo "✓ Respuesta recibida:"
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
