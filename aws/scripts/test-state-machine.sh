#!/bin/bash

# Script para testing de la State Machine
# Uso: ./scripts/test-state-machine.sh

set -e

# Obtener región desde AWS CLI o usar default
REGION=$(aws configure get region || echo "us-east-1")

echo "========================================="
echo "Testing de State Machine de Reintentos"
echo "========================================="
echo "Región: ${REGION}"
echo ""

# Obtener ARN de la State Machine
echo "Buscando State Machine..."
STATE_MACHINE_ARN=$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
  --output text 2>/dev/null || true)

if [ -z "$STATE_MACHINE_ARN" ]; then
  echo "❌ Error: No se encontró la State Machine. ¿Has desplegado el stack?"
  echo ""
  echo "Debug: Outputs disponibles en el stack:"
  aws cloudformation describe-stacks \
    --region "${REGION}" \
    --stack-name ml-retries-stack \
    --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue]' \
    --output table 2>/dev/null || echo "No se pudo obtener los outputs"
  exit 1
fi

echo "✓ State Machine encontrada: ${STATE_MACHINE_ARN}"
echo ""

# Crear input con múltiples reintentos
echo "Creando input con casos REALISTAS basados en datos de entrenamiento..."
cat > /tmp/state_machine_input.json << 'EOF'
{
  "retries": [
    {
      "monto": 1000.0,
      "delta_horas": 2.0,
      "retry_hour": 20,
      "retry_dayofweek": 2,
      "retry_is_weekend": 0,
      "error_categoria": "cliente_4xx",
      "detalle_fail": "Fondos insuficientes. La tarjeta no tiene fondos suficientes para realizar la compra.",
      "retry_hora_bucket": "noche"
    },
    {
      "monto": 1500.0,
      "delta_horas": 1.0,
      "retry_hour": 21,
      "retry_dayofweek": 3,
      "retry_is_weekend": 0,
      "error_categoria": "cliente_4xx",
      "detalle_fail": "Excede el límite mensual de número de compras por correo",
      "retry_hora_bucket": "noche"
    },
    {
      "monto": 2000.0,
      "delta_horas": 12.0,
      "retry_hour": 4,
      "retry_dayofweek": 3,
      "retry_is_weekend": 0,
      "error_categoria": "cliente_4xx",
      "detalle_fail": "Operación denegada. El cliente debe intentar nuevamente ó utilice otra tarjeta.",
      "retry_hora_bucket": "madrugada"
    }
  ]
}
EOF

echo "✓ Input creado"
echo ""

# Ejecutar la State Machine
echo "Ejecutando State Machine..."
EXECUTION_ARN=$(aws stepfunctions start-execution \
  --region "${REGION}" \
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
    --region "${REGION}" \
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
  --region "${REGION}" \
  --execution-arn ${EXECUTION_ARN} \
  | jq '{status: .status, startDate: .startDate, stopDate: .stopDate}'

echo ""
echo "Historial de eventos:"
aws stepfunctions get-execution-history \
  --region "${REGION}" \
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
