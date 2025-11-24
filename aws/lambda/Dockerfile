# Dockerfile para Lambda DockerImageFunction
# Basado en la imagen oficial de AWS Lambda para Python 3.11

FROM public.ecr.aws/lambda/python:3.11

# Instalar herramientas de compilación necesarias para NumPy y scikit-learn
RUN yum install -y gcc gcc-c++ make gfortran && yum clean all

# Copiar el archivo de requisitos y instalarlo
COPY requirements.txt ${LAMBDA_TASK_ROOT}/

RUN pip install --prefer-binary --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copiar el código del handler
COPY lambda_predict_reintento.py ${LAMBDA_TASK_ROOT}/

# Asegurar permisos correctos en los archivos
RUN chmod 644 ${LAMBDA_TASK_ROOT}/lambda_predict_reintento.py && \
    chmod 755 ${LAMBDA_TASK_ROOT}

# Establecer la variable de handler
# Formato: archivo.función
CMD [ "lambda_predict_reintento.lambda_handler" ]
