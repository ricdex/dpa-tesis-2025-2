#!/bin/bash

# Script para subir el modelo a S3
# Uso: ./scripts/upload-model.sh

set -e

# Obtener región
REGION=$(aws configure get region || echo "us-east-1")

echo "========================================="
echo "Subir Modelo a S3"
echo "========================================="
echo ""

# Verificar que AWS está configurado
if ! aws sts get-caller-identity &> /dev/null; then
  echo "❌ AWS CLI no está configurado"
  exit 1
fi

# Obtener el nombre del bucket del stack
echo "Buscando bucket S3..."
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ModelBucketName`].OutputValue' \
  --output text 2>/dev/null || true)

if [ -z "$BUCKET_NAME" ]; then
  echo "❌ Error: No se encontró el bucket. ¿Has desplegado el stack?"
  exit 1
fi

echo "✓ Bucket encontrado: ${BUCKET_NAME}"
echo ""

# Verificar que el modelo existe localmente
MODEL_SOURCE="../models/mejor_modelo.pkl"
if [ ! -f "$MODEL_SOURCE" ]; then
  echo "❌ Error: No se encontró $MODEL_SOURCE"
  exit 1
fi

echo "✓ Modelo encontrado: $MODEL_SOURCE"
echo "  Tamaño: $(du -h $MODEL_SOURCE | cut -f1)"
echo ""

# Subir el modelo
echo "Subiendo modelo a S3..."
aws s3 cp "$MODEL_SOURCE" "s3://${BUCKET_NAME}/models/mejor_modelo.pkl" \
  --region "${REGION}"

echo ""
echo "✓ Modelo subido exitosamente"
echo ""

# Verificar que se subió
echo "Verificando en S3:"
aws s3 ls "s3://${BUCKET_NAME}/models/" --region "${REGION}" --human-readable

echo ""
echo "========================================="
echo "✓ Upload completado"
echo "========================================="
echo ""
echo "Ahora puedes ejecutar:"
echo "  ./scripts/test-lambda.sh"
echo "  ./scripts/test-state-machine.sh"
