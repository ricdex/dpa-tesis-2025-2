# 📇 Índice de Documentación y Archivos

**Última actualización:** Noviembre 2025

---

## 🚀 Si tienes 5 minutos

Empieza por aquí y ejecuta:

1. **[QUICKSTART.md](./QUICKSTART.md)** ← Lee esto primero
2. Ejecuta: `./scripts/setup-and-deploy.sh`
3. Ejecuta: `./scripts/test-lambda.sh`

---

## 📚 Guías de Documentación

| Documento | Duración | Para Quién | Contenido |
|-----------|----------|-----------|----------|
| **[QUICKSTART.md](./QUICKSTART.md)** | 5 min | Usuarios nuevos | Guía de inicio rápido en 5 pasos |
| **[PROJECT_STRUCTURE.txt](./PROJECT_STRUCTURE.txt)** | 10 min | Todos | Estructura visual del proyecto |
| **[README.md](./README.md)** | 30 min | Desarrolladores | Documentación técnica completa |
| **[MANIFEST.md](./MANIFEST.md)** | 15 min | Arquitectos | Inventario detallado de archivos |
| **[INDEX.md](./INDEX.md)** | 3 min | Todos | Este documento (navegación) |

---

## 💻 Código Principal

### Infraestructura AWS CDK (TypeScript)

```
lib/
├── ml-retries-stack.ts    ← Stack principal (S3 + Lambda + Step Functions)
                             Leer: Para entender qué recursos se crean

bin/
├── app.ts                 ← Entry point de CDK
                             Leer: Configuración inicial
```

### Handler de Lambda (Python)

```
lambda/
├── lambda_predict_reintento.py  ← Handler principal
                                  Leer: Cómo funciona la predicción
├── Dockerfile                    ← Imagen Docker
├── requirements.txt              ← Dependencias Python
```

### Scripts de Deployment

```
scripts/
├── setup-and-deploy.sh           ← Deployment automático
                                  Ejecutar: Primero
├── test-lambda.sh                ← Testing de Lambda
                                  Ejecutar: Después del deploy
├── test-state-machine.sh         ← Testing de State Machine
                                  Ejecutar: Después del deploy
```

---

## 🔍 ¿Qué Quiero Hacer?

### "Quiero empezar rápido"
→ [QUICKSTART.md](./QUICKSTART.md)

### "Quiero entender la arquitectura"
→ [PROJECT_STRUCTURE.txt](./PROJECT_STRUCTURE.txt) → [lib/ml-retries-stack.ts](./lib/ml-retries-stack.ts)

### "Quiero entender el código de la Lambda"
→ [lambda/lambda_predict_reintento.py](./lambda/lambda_predict_reintento.py) (tiene comentarios detallados)

### "Tengo un error"
→ [README.md - Sección Troubleshooting](./README.md#troubleshooting)

### "Quiero ver todos los archivos"
→ [MANIFEST.md](./MANIFEST.md)

### "Quiero saber cómo deployar"
→ [README.md - Sección Instalación](./README.md#instalación-y-configuración)

### "Quiero testear todo"
→ [README.md - Sección Testing](./README.md#testing)

### "Quiero configurar variables"
→ [README.md - Sección Configuración](./README.md#configuración-y-variables-de-entorno)

### "Quiero destruir la infraestructura"
→ [README.md - Sección Limpieza](./README.md#limpieza-y-destrucción)

---

## 📁 Estructura de Carpetas

```
dpa-tesis-2025-2/
├── bin/app.ts                          ← CDK Entry Point
├── lib/ml-retries-stack.ts             ← Stack Principal
├── lambda/
│   ├── lambda_predict_reintento.py     ← Handler Lambda
│   ├── Dockerfile                      ← Imagen Docker
│   └── requirements.txt                ← Dependencias
├── scripts/
│   ├── setup-and-deploy.sh             ← Deployment Automático
│   ├── test-lambda.sh                  ← Test Lambda
│   └── test-state-machine.sh           ← Test State Machine
├── INDEX.md                            ← Este archivo
├── QUICKSTART.md                       ← Inicio Rápido
├── README.md                           ← Documentación Completa
├── MANIFEST.md                         ← Inventario de Archivos
├── PROJECT_STRUCTURE.txt               ← Estructura Visual
├── package.json                        ← Dependencias Node.js
├── tsconfig.json                       ← Config TypeScript
├── cdk.json                            ← Config CDK
├── .env.example                        ← Template Env Vars
└── .gitignore                          ← Archivos Ignorados
```

---

## 🎯 Flujo Recomendado de Lectura

### Primer día - Entender

1. ✅ [QUICKSTART.md](./QUICKSTART.md) - 5 min
2. ✅ [PROJECT_STRUCTURE.txt](./PROJECT_STRUCTURE.txt) - 10 min
3. ✅ [README.md - Primeras 2 secciones](./README.md) - 15 min

### Segundo día - Desplegar

1. ✅ Ejecutar: `python3 ejecutar-evaluacion-algoritmos.py` - 5-10 min
2. ✅ Ejecutar: `./scripts/setup-and-deploy.sh` - 15 min
3. ✅ Ejecutar: `./scripts/test-lambda.sh` - 2 min
4. ✅ Ejecutar: `./scripts/test-state-machine.sh` - 5 min

### Tercer día - Profundizar (Opcional)

1. ✅ [lambda/lambda_predict_reintento.py](./lambda/lambda_predict_reintento.py) - 15 min
2. ✅ [lib/ml-retries-stack.ts](./lib/ml-retries-stack.ts) - 20 min
3. ✅ [README.md - Secciones completas](./README.md) - 30 min

---

## 🔗 Enlaces Rápidos

| Acción | Comando |
|--------|---------|
| Ver guía rápida | `cat QUICKSTART.md` |
| Ver estructura | `cat PROJECT_STRUCTURE.txt` |
| Ver documentación | `cat README.md` |
| Desplegar | `./scripts/setup-and-deploy.sh` |
| Testear Lambda | `./scripts/test-lambda.sh` |
| Testear State Machine | `./scripts/test-state-machine.sh` |
| Ver logs | `aws logs tail /aws/lambda/ml-retries-inference --follow` |
| Destruir | `npx cdk destroy` |

---

## 📊 Cheat Sheet de Comandos

```bash
# SETUP
npm install                              # Instalar dependencias
npm run build                            # Compilar TypeScript
npx cdk synth                            # Validar síntesis

# DEPLOY
./scripts/setup-and-deploy.sh            # Deploy automático (TODO)
npx cdk deploy                           # Deploy manual

# TESTING
./scripts/test-lambda.sh                 # Test Lambda directa
./scripts/test-state-machine.sh          # Test State Machine

# MONITOREO
aws logs tail /aws/lambda/ml-retries-inference --follow  # Ver logs

# LIMPIEZA
npx cdk destroy                          # Destruir stack
aws s3 rm s3://{bucket} --recursive      # Limpiar bucket
aws s3 rb s3://{bucket}                  # Eliminar bucket
```

---

## 🆘 Ayuda Rápida

### "¿Por dónde empiezo?"
→ Lee [QUICKSTART.md](./QUICKSTART.md) y ejecuta `./scripts/setup-and-deploy.sh`

### "¿Cómo deployo?"
→ Ejecuta `./scripts/setup-and-deploy.sh` (todo automático)

### "¿Cómo testeo?"
→ Ejecuta `./scripts/test-lambda.sh` y `./scripts/test-state-machine.sh`

### "¿Cómo veo logs?"
→ `aws logs tail /aws/lambda/ml-retries-inference --follow`

### "¿Tengo un error?"
→ Busca en [README.md - Troubleshooting](./README.md#troubleshooting)

### "¿Necesito más detalles?"
→ Lee [README.md](./README.md) completo

### "¿Dónde está el código?"
→ `lambda/lambda_predict_reintento.py` (bien comentado)

### "¿Cómo se estructura la infraestructura?"
→ `lib/ml-retries-stack.ts` (bien documentada)

---

## 📈 Progreso de Implementación

- ✅ Estructura CDK
- ✅ Lambda de inferencia
- ✅ Scripts de deployment
- ✅ Scripts de testing
- ✅ Documentación completa
- ✅ Guía rápida
- ✅ Dockerfile optimizado
- ✅ Validación de entrada
- ✅ Manejo de errores
- ✅ Logging detallado
- ✅ State Machine
- ✅ Permisos IAM mínimos

**Estado:** ✅ LISTO PARA PRODUCCIÓN

---

## 📞 Soporte Rápido

| Problema | Solución | Ver |
|----------|----------|-----|
| No sé por dónde empezar | Leer QUICKSTART.md | [QUICKSTART.md](./QUICKSTART.md) |
| Error al deployar | Troubleshooting en README | [README.md](./README.md#troubleshooting) |
| Lambda no funciona | Ver logs en CloudWatch | Comando: `aws logs tail ...` |
| Quiero entender todo | Leer documentación completa | [README.md](./README.md) |
| Modelo no se carga | Verificar S3 | [README.md](./README.md#troubleshooting) |
| Quiero cambiar threshold | Actualizar variable de entorno | [README.md](./README.md#configuración-y-variables-de-entorno) |

---

## 🎓 Conceptos Clave

- **S3 Bucket**: Almacena el modelo `mejor_modelo.pkl`
- **Lambda**: Carga modelo y realiza predicción en tiempo real
- **State Machine**: Orquesta múltiples reintentos en paralelo
- **Preprocesamiento**: Idéntico al del script original
- **Threshold**: Umbral configurable para decisión (default: 0.3)

---

## 💡 Tips Útiles

- Usa `./scripts/setup-and-deploy.sh` para todo automático
- Los logs están en `/aws/lambda/ml-retries-inference`
- El modelo se carga UNA SOLA VEZ en la Lambda (eficiente)
- Puedes cambiar THRESHOLD sin redeploy
- Usa `cdk diff` para ver cambios antes de deployar

---

## 📝 Checklist de Deployment

```
□ Node.js >= 18 instalado
□ AWS CLI configurado con credenciales
□ Docker instalado y corriendo
□ Python >= 3.9 instalado
□ mejor_modelo.pkl generado (python3 ejecutar-evaluacion-algoritmos.py)
□ Scripts con permisos ejecutables (chmod +x scripts/*.sh)
□ Ejecutar: ./scripts/setup-and-deploy.sh
□ Ejecutar: ./scripts/test-lambda.sh
□ Ejecutar: ./scripts/test-state-machine.sh
□ Ver logs: aws logs tail /aws/lambda/ml-retries-inference
```

---

**¿Preguntas?** Consulta la sección **Troubleshooting** en [README.md](./README.md)

Documento: `INDEX.md` | Actualizado: Noviembre 2025
