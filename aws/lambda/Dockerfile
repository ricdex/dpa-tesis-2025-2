# Dockerfile para Lambda DockerImageFunction
# Basado en la imagen oficial de AWS Lambda para Python 3.11

FROM public.ecr.aws/lambda/python:3.11

# Copiar el archivo de requisitos y instalarlo
COPY requirements.txt ${LAMBDA_TASK_ROOT}/

RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copiar el código del handler
COPY lambda_predict_reintento.py ${LAMBDA_TASK_ROOT}/

# Establecer la variable de handler
# Formato: archivo.función
CMD [ "lambda_predict_reintento.lambda_handler" ]
