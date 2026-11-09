# Build from the repository root: docker build -f services/operations/Dockerfile .
FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir boto3==1.43.118 psycopg[binary]==3.3.6 && useradd -u 10001 -m app
COPY services/operations/bootstrap_database.py ./bootstrap_database.py
# RDS CA bundle for sslmode=verify-full (AWS publishes it at this address)
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /app/certs/rds-global-bundle.pem
USER 10001
CMD ["python","/app/bootstrap_database.py"]
