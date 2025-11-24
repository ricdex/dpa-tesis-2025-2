"""
Lambda Handler para Inferencia de Modelo ML de Reintentos de Pagos

Este módulo:
1. Carga el modelo entrenado (mejor_modelo.pkl) desde S3 al inicializarse.
2. Recibe eventos JSON con características de un reintento de pago.
3. Aplica el mismo preprocesamiento del modelo original.
4. Genera predicciones de probabilidad de éxito.
5. Devuelve una decisión binaria basada en un umbral configurable.

Estructura del evento esperado:
{
    "monto": float,                  # Monto de la transacción
    "delta_horas": float,            # Diferencia en horas entre intento 1 y 2
    "retry_hour": int,               # Hora del día del reintento (0-23)
    "retry_dayofweek": int,          # Día de la semana (0-6)
    "retry_is_weekend": int,         # 0/1, indica si es fin de semana
    "error_categoria": str,          # Categoría del error (cliente_4xx, servicio_5xx, etc)
    "detalle_fail": str,             # Descripción del error
    "retry_hora_bucket": str         # Bucket horario (madrugada, mañana, tarde, noche)
}

Variables de entorno:
- MODEL_BUCKET: Nombre del bucket S3 donde está el modelo
- MODEL_KEY: Ruta del archivo del modelo en S3 (ej: models/mejor_modelo.pkl)
- THRESHOLD: Umbral de decisión (0-1), por defecto 0.3
- LOG_LEVEL: Nivel de logging (DEBUG, INFO, WARNING, ERROR)
"""

import os
import json
import logging
import boto3
import joblib
import pandas as pd
from io import BytesIO
from typing import Dict, Any, Tuple

# ============================================
# Configuración de Logging
# ============================================

LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

# ============================================
# Configuración de AWS S3
# ============================================

s3_client = boto3.client('s3')

MODEL_BUCKET = os.environ.get('MODEL_BUCKET')
MODEL_KEY = os.environ.get('MODEL_KEY', 'models/mejor_modelo.pkl')
THRESHOLD = float(os.environ.get('THRESHOLD', '0.3'))

if not MODEL_BUCKET:
    logger.error("❌ FALTA variable de entorno MODEL_BUCKET")
    raise ValueError("Falta variable de entorno MODEL_BUCKET")

logger.info(f"✓ Configuración cargada:")
logger.info(f"  MODEL_BUCKET={MODEL_BUCKET}")
logger.info(f"  MODEL_KEY={MODEL_KEY}")
logger.info(f"  THRESHOLD={THRESHOLD}")
logger.info(f"  LOG_LEVEL={os.environ.get('LOG_LEVEL', 'INFO')}")

# ============================================
# Carga Global del Modelo (al inicializar Lambda)
# ============================================

_model = None
_model_loaded = False


def load_model_from_s3():
    """
    Carga el modelo pickled desde S3.
    Se ejecuta una sola vez al inicializar la Lambda (código global).
    """
    global _model, _model_loaded

    if _model_loaded:
        logger.info("Modelo ya cargado en memoria.")
        return _model

    try:
        logger.info(f"Cargando modelo de S3: s3://{MODEL_BUCKET}/{MODEL_KEY}")

        # Descargar el archivo del modelo desde S3
        response = s3_client.get_object(Bucket=MODEL_BUCKET, Key=MODEL_KEY)
        model_bytes = response['Body'].read()

        # Deserializar el modelo usando joblib
        _model = joblib.load(BytesIO(model_bytes))
        _model_loaded = True

        logger.info("✓ Modelo cargado exitosamente desde S3.")
        return _model

    except Exception as e:
        logger.error(f"Error al cargar el modelo desde S3: {str(e)}", exc_info=True)
        raise RuntimeError(f"No se pudo cargar el modelo desde S3: {str(e)}")


# Cargar el modelo al inicializar el módulo (solo una vez)
try:
    _model = load_model_from_s3()
    logger.info("✓ Modelo inicializado correctamente al startup de Lambda.")
except Exception as e:
    logger.error(f"✗ Error crítico al cargar el modelo: {str(e)}")
    _model = None


# ============================================
# Funciones Auxiliares
# ============================================

def validate_event(event: Dict[str, Any]) -> Tuple[bool, str]:
    """
    Valida que el evento contenga todos los campos requeridos.

    Retorna:
        (bool, str): (Es válido, Mensaje de error)
    """
    required_numeric = [
        'monto', 'delta_horas', 'retry_hour', 'retry_dayofweek', 'retry_is_weekend'
    ]
    required_categoric = [
        'error_categoria', 'detalle_fail', 'retry_hora_bucket'
    ]

    all_required = required_numeric + required_categoric

    for field in all_required:
        if field not in event:
            return False, f"Campo requerido faltante: {field}"

    # Validaciones de tipo
    for field in required_numeric:
        try:
            float(event[field])
        except (ValueError, TypeError):
            return False, f"Campo '{field}' debe ser numérico, recibido: {event[field]}"

    # Validar que sea string
    for field in required_categoric:
        if not isinstance(event[field], str):
            return False, f"Campo '{field}' debe ser string, recibido: {type(event[field])}"

    return True, ""


def prepare_features_dataframe(event: Dict[str, Any]) -> pd.DataFrame:
    """
    Convierte el evento en un DataFrame con las características en el orden correcto.

    El modelo espera las columnas en este orden:
    - Numéricas: monto, delta_horas, retry_hour, retry_dayofweek, retry_is_weekend
    - Categóricas: error_categoria, detalle_fail, retry_hora_bucket
    """
    num_cols = ['monto', 'delta_horas', 'retry_hour', 'retry_dayofweek', 'retry_is_weekend']
    cat_cols = ['error_categoria', 'detalle_fail', 'retry_hora_bucket']

    # Crear un diccionario con todos los campos
    data = {col: [event[col]] for col in (num_cols + cat_cols)}

    # Crear DataFrame con las columnas en el orden correcto
    df = pd.DataFrame(data)
    df = df[num_cols + cat_cols]  # Asegurar el orden

    logger.debug(f"DataFrame de features preparado:\n{df}")
    return df


def predict_retry_success(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Realiza la predicción del modelo sobre el evento.

    Parámetros:
        event: Diccionario con características del reintento

    Retorna:
        Dict con:
        - probabilidad_exito (float): Probabilidad de éxito (0-1)
        - reintentar (bool): Decisión binaria basada en el umbral
        - threshold_usado (float): Umbral utilizado
    """
    if _model is None:
        raise RuntimeError("El modelo no está cargado. Error crítico en la inicialización.")

    # Preparar el DataFrame de features
    df = prepare_features_dataframe(event)

    # Realizar predicción con predict_proba
    # predict_proba retorna [[prob_clase_0, prob_clase_1], ...]
    # Nos interesa la probabilidad de la clase 1 (éxito)
    probabilities = _model.predict_proba(df)
    probability_success = float(probabilities[0, 1])

    # Decisión binaria basada en el umbral
    decision = probability_success >= THRESHOLD

    logger.info(
        f"Predicción realizada: "
        f"monto={event['monto']}, "
        f"error={event['error_categoria']}, "
        f"prob_éxito={probability_success:.4f}, "
        f"umbral={THRESHOLD}, "
        f"reintentar={decision}"
    )

    return {
        'probabilidad_exito': round(probability_success, 4),
        'reintentar': decision,
        'threshold_usado': THRESHOLD,
    }


# ============================================
# Lambda Handler
# ============================================

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Handler principal de AWS Lambda.

    Parámetros:
        event: Evento de Lambda con características del reintento
        context: Contexto de Lambda

    Retorna:
        Dict con statusCode, body (JSON)

    Ejemplo de respuesta exitosa:
    {
        "statusCode": 200,
        "body": {
            "probabilidad_exito": 0.78,
            "reintentar": true,
            "threshold_usado": 0.3
        }
    }
    """
    logger.info(f"Evento recibido: {json.dumps(event)}")

    # Validar que el evento sea correcto
    is_valid, error_msg = validate_event(event)

    if not is_valid:
        logger.warning(f"Evento inválido: {error_msg}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': error_msg,
                'evento_recibido': event
            })
        }

    try:
        # Realizar predicción
        result = predict_retry_success(event)

        logger.info(f"Predicción exitosa: {json.dumps(result)}")

        return {
            'statusCode': 200,
            'body': result  # Retornar el diccionario directamente (se parsea en Step Functions)
        }

    except Exception as e:
        logger.error(f"Error al procesar la predicción: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Error interno en la predicción: {str(e)}',
                'timestamp': pd.Timestamp.now().isoformat()
            })
        }


# ============================================
# Testing (si se ejecuta directamente)
# ============================================

if __name__ == '__main__':
    # Configurar logging para testing
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # Evento de ejemplo (para testing local)
    test_event = {
        "monto": 150.0,
        "delta_horas": 5.0,
        "retry_hour": 10,
        "retry_dayofweek": 2,
        "retry_is_weekend": 0,
        "error_categoria": "cliente_4xx",
        "detalle_fail": "Saldo insuficiente",
        "retry_hora_bucket": "manana"
    }

    print("Testing del handler...")
    print(f"Evento de prueba: {json.dumps(test_event, indent=2)}")

    try:
        response = lambda_handler(test_event, None)
        print(f"\nRespuesta: {json.dumps(response, indent=2)}")
    except Exception as e:
        print(f"Error en testing: {str(e)}")
