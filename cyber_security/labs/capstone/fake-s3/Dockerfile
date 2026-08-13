# Capstone fake-s3: a tiny Flask app standing in for a single S3-style
# bucket, reachable on the shared `cyberlab` network (see
# ../docker-compose.yml) -- directly from `attacker`, no pivot needed,
# exactly like real S3 is internet-reachable from anywhere once you hold
# valid credentials.
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["python3", "app.py"]
