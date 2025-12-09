# ejecutar-evaluacion-algoritmos.py
"""
Script de evaluación de algoritmos para tesis:
- Recopilación y limpieza del dataset
- Generación de variables derivadas
- Entrenamiento y validación de modelos ML
- Cálculo de uplift de negocio (baseline vs modelo)
"""

import os
from typing import List, Tuple, Dict

import numpy as np
import pandas as pd

from sklearn.model_selection import train_test_split, StratifiedKFold, GridSearchCV
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix
)
import joblib

# XGBoost opcional
try:
    from xgboost import XGBClassifier
    HAS_XGB = True
except ImportError:
    HAS_XGB = False
    print("[AVISO] xgboost no instalado, se omitirá el modelo XGBoost.")


# ==============================
# 1) Recopilación y limpieza
# ==============================

EXCEL_PATH = "suscripciones.xlsx"  # usar el archivo


def detectar_columna(df: pd.DataFrame, posibles: List[str], requerido=True) -> str:
    cols_lower = {c.lower(): c for c in df.columns}
    for name in posibles:
        if name.lower() in cols_lower:
            return cols_lower[name.lower()]
    if requerido:
        raise ValueError(f"No se encontró ninguna de {posibles} en columnas {list(df.columns)}")
    return None


def cargar_y_limpiar(path_excel: str) -> pd.DataFrame:
    if not os.path.isfile(path_excel):
        raise FileNotFoundError(f"No se encontró {path_excel}")

    df = pd.read_excel(path_excel)

    col_fecha = detectar_columna(df, ["fecha"])
    col_id = detectar_columna(df, ["ID Suscripcion", "ID Suscripción", "id_suscripcion"])
    col_monto = detectar_columna(df, ["monto"])
    col_http = detectar_columna(df, ["http_status_code", "status_code"])
    col_detalle = detectar_columna(df, ["detalle", "descripcion_error"], requerido=False)

    df[col_fecha] = pd.to_datetime(df[col_fecha], errors="coerce")
    df[col_monto] = pd.to_numeric(df[col_monto], errors="coerce")
    df[col_http] = pd.to_numeric(df[col_http], errors="coerce")

    df = df.dropna(subset=[col_fecha, col_id, col_monto, col_http])
    df = df.drop_duplicates()

    df = df.rename(
        columns={
            col_fecha: "fecha",
            col_id: "id_suscripcion",
            col_monto: "monto",
            col_http: "http_status_code",
        }
    )
    if col_detalle:
        df = df.rename(columns={col_detalle: "detalle"})
    else:
        df["detalle"] = "SIN_DETALLE"

    # nos quedamos solo con suscripciones que tienen al menos 2 intentos (coherente con la tesis)
    counts = df["id_suscripcion"].value_counts()
    ids_validos = counts[counts >= 2].index
    df = df[df["id_suscripcion"].isin(ids_validos)].copy()

    df = df.sort_values(["id_suscripcion", "fecha"]).reset_index(drop=True)

    return df


# ==============================
# 2) Dataset de (fallo + segundo intento) y features
# ==============================

def construir_pares(df: pd.DataFrame) -> pd.DataFrame:
    pares = []
    for sid, g in df.groupby("id_suscripcion"):
        g = g.sort_values("fecha").reset_index(drop=True)
        i = 0
        while i < len(g) - 1:
            fail = g.iloc[i]
            if int(fail["http_status_code"]) == 201:
                i += 1
                continue
            second = g.iloc[i + 1]
            pares.append(
                {
                    "id_suscripcion": sid,
                    "fecha_fail": fail["fecha"],
                    "fecha_second": second["fecha"],
                    "monto": float(fail["monto"]),
                    "http_fail": int(fail["http_status_code"]),
                    "detalle_fail": str(fail["detalle"]),
                    "http_second": int(second["http_status_code"]),
                }
            )
            i += 2

    df_pares = pd.DataFrame(pares)
    if df_pares.empty:
        raise ValueError("No se encontraron pares (fallo + segundo intento).")

    # etiqueta objetivo: éxito en segundo intento
    df_pares["target_exito_second"] = (df_pares["http_second"] == 201).astype(int)

    # variables de tiempo
    df_pares["delta_horas"] = (
        df_pares["fecha_second"] - df_pares["fecha_fail"]
    ).dt.total_seconds() / 3600.0
    df_pares["delta_horas"] = df_pares["delta_horas"].clip(lower=0)

    df_pares["retry_hour"] = df_pares["fecha_second"].dt.hour
    df_pares["retry_dayofweek"] = df_pares["fecha_second"].dt.dayofweek
    df_pares["retry_is_weekend"] = df_pares["retry_dayofweek"].isin([5, 6]).astype(int)

    # categoría de error
    def cat_http(code: int) -> str:
        if 400 <= code < 500:
            return "cliente_4xx"
        elif 500 <= code < 600:
            return "servicio_5xx"
        elif code == 201:
            return "exito_201"
        else:
            return f"otro_{int(code)}"

    df_pares["error_categoria"] = df_pares["http_fail"].apply(cat_http)

    # bucket horario
    def bucket_hora(h: int) -> str:
        if 0 <= h < 6:
            return "madrugada"
        elif 6 <= h < 12:
            return "manana"
        elif 12 <= h < 18:
            return "tarde"
        else:
            return "noche"

    df_pares["retry_hora_bucket"] = df_pares["retry_hour"].apply(bucket_hora)

    return df_pares


def preparar_features(df_pares: pd.DataFrame):
    num_cols = ["monto", "delta_horas", "retry_hour", "retry_dayofweek", "retry_is_weekend"]
    cat_cols = ["error_categoria", "detalle_fail", "retry_hora_bucket"]

    df = df_pares.dropna(subset=num_cols + cat_cols + ["target_exito_second"]).copy()
    X = df[num_cols + cat_cols]
    y = df["target_exito_second"].astype(int)
    return X, y, num_cols, cat_cols


# ==============================
# 3) Modelos y evaluación
# ==============================

def construir_preprocesador(num_cols, cat_cols):
    numeric = StandardScaler()
    categoric = OneHotEncoder(handle_unknown="ignore")
    pre = ColumnTransformer(
        transformers=[
            ("num", numeric, num_cols),
            ("cat", categoric, cat_cols)
        ]
    )
    return pre


def evaluar_modelo(nombre: str, modelo, X_test, y_test, threshold: float = 0.5) -> Dict[str, float]:
    proba = modelo.predict_proba(X_test)[:, 1]
    y_pred = (proba >= threshold).astype(int)

    acc = accuracy_score(y_test, y_pred)
    prec = precision_score(y_test, y_pred, zero_division=0)
    rec = recall_score(y_test, y_pred, zero_division=0)
    f1 = f1_score(y_test, y_pred, zero_division=0)
    try:
        auc = roc_auc_score(y_test, proba)
    except ValueError:
        auc = np.nan
    cm = confusion_matrix(y_test, y_pred)

    print(f"\n=== {nombre} (threshold={threshold:.2f}) ===")
    print("Matriz de confusión:")
    print(cm)
    print(f"Accuracy : {acc:.4f}")
    print(f"Precision: {prec:.4f}")
    print(f"Recall   : {rec:.4f}")
    print(f"F1       : {f1:.4f}")
    if not np.isnan(auc):
        print(f"AUC-ROC  : {auc:.4f}")

    return {
        "modelo": nombre,
        "threshold": threshold,
        "accuracy": acc,
        "precision": prec,
        "recall": rec,
        "f1": f1,
        "auc_roc": auc,
    }


def main():
    print("=== 1) Carga y limpieza ===")
    df = cargar_y_limpiar(EXCEL_PATH)
    print(f"Registros tras limpieza: {len(df)}")

    print("\n=== 2) Construcción de pares (fallo + segundo intento) ===")
    df_pares = construir_pares(df)
    print(f"Casos (pares) construidos: {len(df_pares)}")
    print("Distribución global de la etiqueta:")
    print(df_pares["target_exito_second"].value_counts(normalize=True))

    print("\n=== 3) Features y split estratificado ===")
    X, y, num_cols, cat_cols = preparar_features(df_pares)
    print("Distribución etiqueta después de limpiar NaN:")
    print(y.value_counts(normalize=True))

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        stratify=y,
        random_state=42
    )

    print(f"Tamaño train: {len(X_train)}, test: {len(X_test)}")

    pre = construir_preprocesador(num_cols, cat_cols)

    # -------- Modelos --------
    modelos = {}

    # 1) Regresión Logística
    pipe_log = Pipeline(
        steps=[
            ("preprocess", pre),
            ("clf", LogisticRegression(max_iter=1000, class_weight="balanced", solver="liblinear"))
        ]
    )
    modelos["logistic_regression"] = pipe_log

    # 2) Random Forest
    pipe_rf = Pipeline(
        steps=[
            ("preprocess", pre),
            ("clf", RandomForestClassifier(
                n_estimators=200,
                max_depth=None,
                min_samples_leaf=1,
                class_weight="balanced",
                random_state=42,
                n_jobs=-1
            ))
        ]
    )
    modelos["random_forest"] = pipe_rf

    # 3) XGBoost (opcional)
    if HAS_XGB:
        pipe_xgb = Pipeline(
            steps=[
                ("preprocess", pre),
                ("clf", XGBClassifier(
                    objective="binary:logistic",
                    eval_metric="logloss",
                    n_estimators=200,
                    max_depth=5,
                    learning_rate=0.1,
                    subsample=0.9,
                    colsample_bytree=0.9,
                    random_state=42,
                    n_jobs=-1
                ))
            ]
        )
        modelos["xgboost"] = pipe_xgb

    resultados = []
    mejor_modelo = None
    mejor_nombre = None
    mejor_f1 = -1

    print("\n=== 4) Entrenamiento y evaluación ===")
    for nombre, modelo in modelos.items():
        modelo.fit(X_train, y_train)

        # probamos 3 thresholds para ver cuál da mejor F1
        best_metrics = None
        best_t = 0.5
        for t in [0.3, 0.4, 0.5]:
            metrics = evaluar_modelo(nombre, modelo, X_test, y_test, threshold=t)
            if metrics["f1"] > (best_metrics["f1"] if best_metrics else -1):
                best_metrics = metrics
                best_t = t

        best_metrics["modelo"] = nombre
        best_metrics["threshold"] = best_t
        resultados.append(best_metrics)

        if best_metrics["f1"] > mejor_f1:
            mejor_f1 = best_metrics["f1"]
            mejor_modelo = modelo
            mejor_nombre = nombre

    df_res = pd.DataFrame(resultados)
    # Crear carpeta models si no existe
    os.makedirs("models", exist_ok=True)

    df_res.to_csv("models/metrics_resultados.csv", index=False)
    print("\nMétricas guardadas en models/metrics_resultados.csv")
    print(df_res)

    if mejor_modelo is not None:
        joblib.dump(mejor_modelo, "models/mejor_modelo.pkl")
        print(f"\nMejor modelo: {mejor_nombre} (F1={mejor_f1:.4f}) guardado en models/mejor_modelo.pkl")

    # -------- 5) Uplift de negocio --------
    print("\n=== 5) Uplift de negocio (baseline vs modelo) ===")
    if mejor_modelo is not None:
        proba = mejor_modelo.predict_proba(X_test)[:, 1]
        baseline_rate = y_test.mean()

        df_eval = pd.DataFrame({"y": y_test, "proba": proba})
        df_eval = df_eval.sort_values("proba", ascending=False).reset_index(drop=True)

        # por ejemplo, reintentamos solo el 70% más probable
        top_frac = 0.7
        n_top = int(len(df_eval) * top_frac)
        df_top = df_eval.iloc[:n_top]

        ml_rate = df_top["y"].mean()
        uplift = ml_rate - baseline_rate

        print(f"Tasa baseline (reintentar todo): {baseline_rate:.4f}")
        print(f"Tasa con modelo (top 70%):      {ml_rate:.4f}")
        print(f"Uplift (puntos porcentuales):  {uplift*100:.2f}%")
    else:
        print("No hay modelo entrenado para calcular uplift.")


if __name__ == "__main__":
    main()
