#!/bin/bash

# Script para testing de la State Machine
# Uso: ./scripts/test-state-machine.sh

set -e

echo "========================================="
echo "Testing de State Machine de Reintentos"
echo "========================================="

# Obtener ARN de la State Machine
echo "Buscando State Machine..."
STATE_MACHINE_ARN=$(aws cloudformation describe-stacks \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
  --output text 2>/dev/null || true)

if [ -z "$STATE_MACHINE_ARN" ]; then
  echo "❌ Error: No se encontró la State Machine. ¿Has desplegado el stack?"
  exit 1
fi

echo "✓ State Machine encontrada: ${STATE_MACHINE_ARN}"
echo ""

# Crear input con múltiples reintentos
echo "Creando input con 3 reintentos de ejemplo..."
cat > /tmp/state_machine_input.json << 'EOF'
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
      "detalle_fail": "Timeout del servicio",
      "retry_hora_bucket": "tarde"
    },
    {
      "monto": 75.5,
      "delta_horas": 2.5,
      "retry_hour": 22,
      "retry_dayofweek": 5,
      "retry_is_weekend": 1,
      "error_categoria": "cliente_4xx",
      "detalle_fail": "Fondos insuficientes",
      "retry_hora_bucket": "noche"
    }
  ]
}
EOF

echo "✓ Input creado"
echo ""

# Ejecutar la State Machine
echo "Ejecutando State Machine..."
EXECUTION_ARN=$(aws stepfunctions start-execution \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --input file:///tmp/state_machine_input.json \
  --query 'executionArn' \
  --output text)

echo "✓ Ejecución iniciada: ${EXECUTION_ARN}"
echo ""

# Esperar a que termine
echo "Esperando a que termine la ejecución (máx 30 segundos)..."
for i in {1..30}; do
  STATUS=$(aws stepfunctions describe-execution \
    --execution-arn ${EXECUTION_ARN} \
    --query 'status' \
    --output text)

  if [ "${STATUS}" = "SUCCEEDED" ]; then
    echo "✓ Ejecución completada exitosamente"
    break
  elif [ "${STATUS}" = "FAILED" ]; then
    echo "❌ Ejecución fallida"
    echo "Estado: ${STATUS}"
    exit 1
  else
    echo "  Estado actual: ${STATUS}... (${i}/30)"
    sleep 1
  fi
done

echo ""
echo "========================================="
echo "Resultados de la Ejecución"
echo "========================================="
echo ""

# Ver detalles de la ejecución
echo "Estado final:"
aws stepfunctions describe-execution \
  --execution-arn ${EXECUTION_ARN} \
  | jq '{status: .status, startDate: .startDate, stopDate: .stopDate}'

echo ""
echo "Historial de eventos:"
aws stepfunctions get-execution-history \
  --execution-arn ${EXECUTION_ARN} \
  | jq '.events[] | {type, timestamp}'

echo ""
echo "========================================="
echo "✓ Testing completado"
echo "========================================="
echo ""
echo "Comandos útiles:"
echo "  Ver logs: aws logs tail /aws/lambda/ml-retries-inference --follow"
echo "  Ver ejecución: aws stepfunctions describe-execution --execution-arn ${EXECUTION_ARN}"
