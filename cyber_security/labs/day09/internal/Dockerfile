# Day 9 internal target: a tiny stdlib-only Python HTTP service. No pip
# install needed -- see app.py's module docstring for what it serves and
# why. Reached ONLY as `internal` (or by its pinned link-local address,
# 169.254.169.254) from the `day09-app` network -- never from `cyberlab`,
# and therefore never directly from the `attacker` container.
FROM python:3.12-alpine

WORKDIR /app
COPY app.py .

EXPOSE 80

CMD ["python3", "app.py"]
