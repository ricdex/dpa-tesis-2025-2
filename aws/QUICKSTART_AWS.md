# Quick Start AWS - 5 Minutos

**Solo necesario si deseas desplegar en AWS. Para tesis, ver carpeta raíz.**

---

## ✅ Requisitos

```bash
node --version          # >= 18.x
npm --version           # >= 9.x
aws sts get-caller-identity  # Credenciales configuradas
docker --version        # Docker corriendo
```

---

## 🚀 3 Pasos para Desplegar

### 1. Instalar Dependencias
```bash
npm install
```

### 2. Ejecutar Deployment Automático
```bash
bash scripts/setup-and-deploy.sh
```

(Todo automático: compila, valida, despliega, sube modelo)

### 3. Testear
```bash
bash scripts/test-lambda.sh
bash scripts/test-state-machine.sh
```

---

## 📊 Entrada/Salida

**Input:**
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

**Output:**
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

## 🆘 Troubleshooting

**"No se encuentra el modelo"**
→ Asegúrate de estar en carpeta `aws/` y ejecutar: `python3 ../ejecutar-evaluacion-algoritmos.py`

**"AWS CLI no configurado"**
→ Ejecuta: `aws configure`

**"Docker no está corriendo"**
→ Inicia Docker

**"No tengo Node.js"**
→ Descargarlo de: https://nodejs.org/

---

## 📈 Monitorear

```bash
# Ver logs en tiempo real
aws logs tail /aws/lambda/ml-retries-inference --follow
```

---

## 🗑️ Limpiar

```bash
# Destruir infraestructura
npx cdk destroy

# Limpiar bucket S3
aws s3 rm s3://{bucket} --recursive
aws s3 rb s3://{bucket}
```

---

## 📖 Más Información

Ver: **README_AWS.md** y carpeta **docs/**

---

**Tiempo total:** ~20 minutos (primera vez)

Última actualización: Noviembre 2025
