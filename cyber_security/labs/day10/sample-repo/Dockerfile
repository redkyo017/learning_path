# Day 10 lab image -- builds the toy payment-notifier app.
#
# This Dockerfile is scanned, never run as a live service (see
# ../docker-compose.yml and ../README.md): trivy/grype read the built
# image's filesystem for known-vulnerable package versions; nothing here
# needs a network target the way earlier days' attack labs did.

FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY config/ ./config/

CMD ["python", "src/app.py"]
