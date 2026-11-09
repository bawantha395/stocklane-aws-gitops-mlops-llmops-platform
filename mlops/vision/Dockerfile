# Build from the repository root: docker build -f mlops/vision/Dockerfile .
FROM python:3.12-slim
WORKDIR /opt/program
COPY mlops/vision/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY services/vision/app/encoder.py ./app/encoder.py
COPY services/vision/app/__init__.py ./app/__init__.py
COPY mlops/vision/train.py mlops/vision/dataset.py mlops/vision/serve.py mlops/vision/entrypoint.py ./
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["python","/opt/program/entrypoint.py"]
