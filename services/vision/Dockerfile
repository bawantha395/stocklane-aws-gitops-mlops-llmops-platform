# Build from the repository root: docker build -f services/vision/Dockerfile .
FROM python:3.12-slim
WORKDIR /app
COPY services/vision/requirements.lock ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && useradd -u 10001 -m app && mkdir -p /data/images /models/baseline && chown -R 10001:10001 /app /data /models
COPY --chown=10001:10001 services/vision/app ./app
COPY --chown=10001:10001 services/vision/tools/fetch_model.py services/vision/tools/reindex.py ./tools/
# RDS CA bundle for sslmode=verify-full (AWS publishes it at this address)
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /app/certs/rds-global-bundle.pem
USER 10001
EXPOSE 8083
# The model is fetched by the init container. On every start, index this release's vectors first
# (old-version vectors stay for rollback), then serve. Indexing is idempotent and tolerant: a failure is logged, never fatal.
CMD ["sh","-c","python /app/tools/reindex.py || echo 'reindex skipped, see the error above'; exec uvicorn app.main:create_app --factory --host 0.0.0.0 --port 8083 --no-server-header"]
