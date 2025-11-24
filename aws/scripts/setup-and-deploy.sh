#!/bin/bash

# Script de setup y deployment automático
# Uso: ./scripts/setup-and-deploy.sh

set -e

echo "========================================="
echo "Setup y Deployment de Infraestructura ML"
echo "========================================="
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
  echo "❌ Error: Ejecuta este script desde la raíz del proyecto"
  exit 1
fi

# Verificar requisitos
echo "Verificando requisitos..."
echo ""

# Node.js
if ! command -v node &> /dev/null; then
  echo "❌ Node.js no está instalado. Descárgalo de https://nodejs.org/"
  exit 1
fi
echo "✓ Node.js: $(node --version)"

# npm
if ! command -v npm &> /dev/null; then
  echo "❌ npm no está instalado"
  exit 1
fi
echo "✓ npm: $(npm --version)"

# AWS CLI
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI no está instalado. Descárgalo de https://aws.amazon.com/cli/"
  exit 1
fi
echo "✓ AWS CLI: $(aws --version)"

# Docker
if ! command -v docker &> /dev/null; then
  echo "❌ Docker no está instalado. Descárgalo de https://www.docker.com/"
  exit 1
fi
echo "✓ Docker: $(docker --version)"

echo ""
echo "Verificando credenciales de AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
  echo "❌ AWS CLI no está configurado correctamente"
  exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || echo "us-east-1")
echo "✓ Cuenta AWS: ${ACCOUNT_ID}"
echo "✓ Región: ${REGION}"

echo ""
echo "========================================="
echo "Step 1: Instalar dependencias de Node.js"
echo "========================================="
echo ""

if [ ! -d "node_modules" ]; then
  echo "Ejecutando npm install..."
  npm install
  echo "✓ Dependencias instaladas"
else
  echo "✓ Dependencias ya están instaladas"
fi

echo ""
echo "========================================="
echo "Step 2: Compilar TypeScript"
echo "========================================="
echo ""

echo "Ejecutando build..."
npm run build
echo "✓ Build completado"

echo ""
echo "========================================="
echo "Step 3: Validar síntesis de CDK"
echo "========================================="
echo ""

echo "Ejecutando cdk synth..."
npx cdk synth --quiet
echo "✓ Síntesis validada"

echo ""
echo "========================================="
echo "Step 4: Verificar que el modelo existe en ../models"
echo "========================================="
echo ""

MODEL_SOURCE="../models/mejor_modelo.pkl"

if [ ! -f "$MODEL_SOURCE" ]; then
  echo "⚠️  Aviso: $MODEL_SOURCE no encontrado"
  echo ""
  echo "Debes entrenar el modelo primero:"
  echo "  cd .."
  echo "  python3 ejecutar-evaluacion-algoritmos.py"
  echo ""
  echo "¿Deseas continuar? El modelo se subirá a S3 después del deployment [y/n]"
  read -r continue_without_model
  if [ "${continue_without_model}" != "y" ]; then
    exit 1
  fi
  MODEL_EXISTS=false
else
  echo "✓ Modelo encontrado en $MODEL_SOURCE"
  MODEL_EXISTS=true
fi

echo ""
echo "========================================="
echo "Step 5: Hacer permisos ejecutables en scripts"
echo "========================================="
echo ""

chmod +x scripts/*.sh
echo "✓ Scripts con permisos ejecutables"

echo ""
echo "========================================="
echo "Step 6: Desplegar stack en AWS"
echo "========================================="
echo ""

echo "ADVERTENCIA: Esto creará recursos en AWS y puede tener costos asociados."
echo "¿Deseas continuar? [y/n]"
read -r continue_deploy
if [ "${continue_deploy}" != "y" ]; then
  echo "Deployment cancelado"
  exit 0
fi

echo ""
echo "Desplegando stack..."
npx cdk deploy --require-approval never

echo ""
echo "✓ Stack desplegado exitosamente!"

echo ""
echo "========================================="
echo "Step 7: Obtener información del deployment"
echo "========================================="
echo ""

# Obtener región
REGION=$(aws configure get region || echo "us-east-1")

# Obtener el nombre del bucket
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`ModelBucketName`].OutputValue' \
  --output text)

# Obtener ARN de Lambda
LAMBDA_ARN=$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`InferenceLambdaArn`].OutputValue' \
  --output text)

# Obtener ARN de State Machine
STATE_MACHINE_ARN=$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name ml-retries-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
  --output text)

echo "Información de recursos:"
echo "  S3 Bucket:        ${BUCKET_NAME}"
echo "  Lambda ARN:       ${LAMBDA_ARN}"
echo "  State Machine:    ${STATE_MACHINE_ARN}"
echo ""

# Validar que se obtuvieron los valores
if [ -z "$BUCKET_NAME" ] || [ -z "$LAMBDA_ARN" ] || [ -z "$STATE_MACHINE_ARN" ]; then
  echo "⚠️  Aviso: No se pudieron obtener todos los outputs del stack"
  echo "Outputs disponibles:"
  aws cloudformation describe-stacks \
    --region "${REGION}" \
    --stack-name ml-retries-stack \
    --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue]' \
    --output table 2>/dev/null || echo "No se pudo obtener los outputs"
fi

echo ""
echo "========================================="
echo "Step 8: Subir el modelo a S3"
echo "========================================="
echo ""

if [ "$MODEL_EXISTS" = true ] && [ -f "$MODEL_SOURCE" ]; then
  echo "Subiendo modelo a S3..."
  aws s3 cp "$MODEL_SOURCE" "s3://${BUCKET_NAME}/models/mejor_modelo.pkl" --region "${REGION}"
  echo "✓ Modelo subido exitosamente"
  echo ""
  echo "Verificando que se subió correctamente..."
  aws s3 ls "s3://${BUCKET_NAME}/models/" --region "${REGION}"
else
  echo "⚠️  $MODEL_SOURCE no encontrado. El modelo NO fue subido a S3."
  echo ""
  echo "❌ IMPORTANTE: Sin el modelo en S3, Lambda no funcionará."
  echo ""
  echo "Cuando tengas el modelo, ejecúta:"
  echo "  aws s3 cp ../models/mejor_modelo.pkl s3://${BUCKET_NAME}/models/mejor_modelo.pkl --region ${REGION}"
fi

echo ""
echo "========================================="
echo "✓ Setup y Deployment Completado"
echo "========================================="
echo ""
echo "Recursos desplegados:"
echo "  S3 Bucket:        ${BUCKET_NAME}"
echo "  Lambda ARN:       ${LAMBDA_ARN}"
echo "  State Machine:    ${STATE_MACHINE_ARN}"
echo ""
echo "¿Deseas ejecutar los tests ahora? [y/n]"
read -r run_tests
if [ "${run_tests}" = "y" ]; then
  echo ""
  echo "Ejecutando test de Lambda..."
  ./scripts/test-lambda.sh
  echo ""
  echo "Ejecutando test de State Machine..."
  ./scripts/test-state-machine.sh
fi

echo ""
echo "========================================="
echo "Comandos útiles:"
echo "========================================="
echo ""
echo "Ver logs de Lambda:"
echo "  aws logs tail /aws/lambda/ml-retries-inference --follow"
echo ""
echo "Testear Lambda manualmente:"
echo "  ./scripts/test-lambda.sh"
echo ""
echo "Testear State Machine:"
echo "  ./scripts/test-state-machine.sh"
echo ""
echo "Ver detalles en: README.md"
