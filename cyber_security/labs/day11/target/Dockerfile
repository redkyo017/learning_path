# Day 11 target -- one small Flask app carrying three replayed attack
# surfaces (scannable port, weak /login, SQLi-vulnerable /search). See
# app.py's module docstring for the full detail on each.
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# The access log lives here so the `detection` container (mounting the
# same `weblogs` volume, see ../docker-compose.yml) can read it. Created
# up front so `tail -F` in the detection container has something to follow
# even before the first request arrives.
RUN mkdir -p /var/log/webapp && touch /var/log/webapp/access.log

EXPOSE 5000

CMD ["python", "app.py"]
