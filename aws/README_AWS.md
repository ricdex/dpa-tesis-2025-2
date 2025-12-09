# Infraestructura AWS CDK para Inferencia del Modelo

## 📌 Resumen

Esta carpeta contiene la **infraestructura como código (IaC)** en AWS CDK v2 para desplegar el modelo de ML en **producción**.

**Estado:** Opcional. Solo necesario si deseas desplegar Lambda en AWS.

---

## 🏗️ Componentes

| Componente | Descripción |
|-----------|-----------|
| **S3 Bucket** | Almacena `mejor_modelo.pkl` |
| **Lambda** | Carga modelo y realiza predicción en tiempo real |
| **Step Functions** | Orquesta predicciones batch en paralelo |
| **CloudWatch** | Logs y monitoreo |
| **IAM** | Permisos mínimos (menor privilegio) |

---

## 📂 Estructura

```
aws/
├── bin/app.ts                          ← Entry point CDK
├── lib/ml-retries-stack.ts             ← Definición del stack
├── lambda/
│   ├── lambda_predict_reintento.py    ← Handler Python
│   ├── Dockerfile                      ← Imagen Docker
│   └── requirements.txt                ← Dependencias Python
├── scripts/
│   ├── setup-and-deploy.sh             ← Deployment automático
│   ├── test-lambda.sh                  ← Testing Lambda
│   ├── test-state-machine.sh           ← Testing batch
│   ├── upload-model.sh                 ← Subir modelo a S3
│   └── destroy.sh                      ← Eliminar todos los recursos
├── docs/                               ← Documentación técnica
├── package.json                        ← Dependencias Node.js
├── tsconfig.json                       ← Config TypeScript
├── cdk.json                            ← Config CDK
├── README_AWS.md                       ← Este archivo
└── QUICKSTART_AWS.md                   ← Guía rápida
```

---

## 🚀 Inicio Rápido

### 1. Requisitos
- Node.js >= 18.x
- AWS CLI v2 (configurado)
- Docker
- Modelo entrenado: `../models/mejor_modelo.pkl`

### 2. Deployment Automático
```bash
bash scripts/setup-and-deploy.sh
```

### 3. Testing
```bash
bash scripts/test-lambda.sh
bash scripts/test-state-machine.sh
```

### 4. Actualizar Modelo
```bash
bash scripts/upload-model.sh
```

### 5. Limpiar Recursos
```bash
bash scripts/destroy.sh
```

---

## 📖 Documentación

- **QUICKSTART_AWS.md** - Guía de 5 minutos
- **docs/** - Documentación técnica detallada

---

## 🔑 Permisos IAM

Lambda solo tiene:
- `s3:GetObject` en el bucket del modelo

---

## 💵 Costos

Estimado: ~$1/mes para 10,000 invocaciones

- S3: $0.02
- Lambda: $0.20
- Step Functions: $0.25
- CloudWatch: $0.50

---

## 🔐 Seguridad

✅ Acceso S3 bloqueado (privado)
✅ Encriptación SSE-S3
✅ IAM con menor privilegio
✅ Validación de entrada
✅ Logs auditables

---

## ❓ Preguntas Frecuentes

**P: ¿Necesito esto para ejecutar la tesis?**
R: No. Esto es solo para desplegar en producción (AWS).

**P: ¿Cuánto cuesta?**
R: ~$1/mes para uso bajo.

**P: ¿Cómo destruyo todo?**
R: `bash scripts/destroy.sh` (requiere confirmación manual)

---

Para más detalles: Ver **QUICKSTART_AWS.md**

**Última actualización:** Noviembre 2025
