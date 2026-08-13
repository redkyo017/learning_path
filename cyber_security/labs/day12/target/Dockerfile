# Day 12 target: a small Flask app chaining a live SQL-injection auth
# bypass (Day 8's class) and a live IDOR/broken-access-control bug
# (Day 9's class) on one box -- see app.py's module docstring for both.
# Reached only as `target` on the shared `cyberlab` network; no ports
# published to the host.
FROM python:3.12-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python3", "app.py"]
