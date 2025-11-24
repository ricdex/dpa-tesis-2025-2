#!/bin/bash

# Script para destruir todos los recursos de AWS
# Uso: ./scripts/destroy.sh

set -e

echo "========================================="
echo "Destruir Infraestructura de AWS"
echo "========================================="
echo ""

# Obtener región
REGION=$(aws configure get region || echo "us-east-1")

echo "Región: ${REGION}"
echo ""

# Verificar que AWS está configurado
if ! aws sts get-caller-identity &> /dev/null; then
  echo "❌ AWS CLI no está configurado"
  exit 1
fi

echo "Cuenta AWS:"
aws sts get-caller-identity --region "${REGION}" --query "Account" --output text
echo ""

# Advertencia
echo "========================================="
echo "⚠️  ADVERTENCIA CRÍTICA"
echo "========================================="
echo ""
echo "ESTO ELIMINARÁ:"
echo "  ✗ Lambda Function"
echo "  ✗ Step Functions State Machine"
echo "  ✗ S3 Bucket (CON TODO SU CONTENIDO)"
echo "  ✗ IAM Roles"
echo "  ✗ CloudWatch Logs"
echo "  ✗ Otros recursos del stack"
echo ""
echo "Esta acción es IRREVERSIBLE. Los datos EN S3 se perderán."
echo ""
echo "========================================="
echo ""

# Confirmación
echo "¿ESTÁS SEGURO de que deseas continuar? (escribe 'eliminar-todo' para confirmar):"
read -r confirm

if [ "${confirm}" != "eliminar-todo" ]; then
  echo "Operación cancelada"
  exit 0
fi

echo ""
echo "========================================="
echo "Eliminando stack: ml-retries-stack"
echo "========================================="
echo ""

# Eliminar el stack
aws cloudformation delete-stack \
  --region "${REGION}" \
  --stack-name ml-retries-stack

echo "✓ Comando de eliminación enviado"
echo ""

# Esperar a que se complete
echo "Esperando a que se complete la eliminación (máx 10 minutos)..."
echo ""

WAIT_SECONDS=0
MAX_SECONDS=600

while [ $WAIT_SECONDS -lt $MAX_SECONDS ]; do
  STATUS=$(aws cloudformation describe-stacks \
    --region "${REGION}" \
    --stack-name ml-retries-stack \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DELETE_COMPLETE")

  if [ "${STATUS}" = "DELETE_COMPLETE" ]; then
    echo ""
    echo "✓ Stack eliminado exitosamente"
    break
  elif [[ "${STATUS}" == *"DELETE_FAILED"* ]]; then
    echo "❌ Error al eliminar el stack"
    echo "Estado: ${STATUS}"
    exit 1
  else
    echo "  Estado actual: ${STATUS}... ($((WAIT_SECONDS / 60)) min)"
    sleep 5
    WAIT_SECONDS=$((WAIT_SECONDS + 5))
  fi
done

if [ $WAIT_SECONDS -ge $MAX_SECONDS ]; then
  echo "⚠️  Timeout: Verifica manualmente en AWS Console"
  exit 1
fi

echo ""
echo "========================================="
echo "✓ Infraestructura Destruida Completamente"
echo "========================================="
echo ""
echo "Recursos eliminados:"
echo "  ✓ Stack CloudFormation"
echo "  ✓ Lambda"
echo "  ✓ Step Functions"
echo "  ✓ S3 Bucket"
echo "  ✓ IAM Roles"
echo "  ✓ CloudWatch Logs"
echo ""
echo "Para volver a desplegar:"
echo "  ./scripts/setup-and-deploy.sh"
echo ""
