# Day 4 target: a small Flask auth app with two deliberate weaknesses --
# see app.py's module docstring for both. Reached only as `target` on the
# shared `cyberlab` network; no ports published to the host.
FROM python:3.12-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python3", "app.py"]
