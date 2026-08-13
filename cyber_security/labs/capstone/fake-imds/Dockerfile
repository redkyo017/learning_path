# Capstone fake-imds: a tiny Flask app standing in for real EC2 instance
# metadata, bound to the real, literal link-local address 169.254.169.254
# on the `imds` network (see ../docker-compose.yml). Runs as the image's
# default root user deliberately -- port 80 matches real IMDS exactly,
# this container holds no real secret of any kind (every credential
# value it serves is synthetic, see app.py), and it is reachable from
# nothing but `webapp` -- there is no privilege boundary here worth
# dropping root for.
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 80

CMD ["python3", "app.py"]
