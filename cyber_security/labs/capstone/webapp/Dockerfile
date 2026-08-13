# Capstone webapp: "Northwind Ops Portal" -- see app.py's module
# docstring for the two independent, deliberately-planted bug pairs.
# Reached only as `webapp` on the shared `cyberlab` network; no ports
# published to the host.
FROM python:3.12-slim

# Needed for the Stage-3 pivot: once command injection lands a shell on
# THIS container, that shell has to be able to reach `host` on the
# `internal` network itself -- attacker's own container never can (see
# docker-compose.yml). `ping` (iputils-ping) also backs the legitimate
# (non-malicious) use of /admin/diagnostics.
RUN apt-get update && apt-get install -y --no-install-recommends \
        iputils-ping \
        openssh-client \
        sshpass \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG OPS_PASSWORD=Fall2024-Temp!

WORKDIR /opt/webapp

RUN useradd -m -s /usr/sbin/nologin appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Planted misconfig: a leftover ops note, sitting right next to the app
# code, readable by whatever user runs the app -- exactly the kind of
# "we'll clean it up later" leftover that a real command-injection
# foothold finds in five seconds. See content/day20-capstone-attack.md
# Stage 3 and content/day21-capstone-defend.md's remediation section
# (rotate the credential, and never leave one sitting in a web root at
# all -- Day 10's future secrets-sprawl lesson, previewed here).
RUN mkdir -p /opt/webapp/.internal /var/log/webapp && \
    printf 'Internal ops backend: ssh %s@%s\nTemporary password (rotate before Friday -- JIRA-4521): %s\n' \
        "opsuser" "host" "${OPS_PASSWORD}" > /opt/webapp/.internal/ops-notes.txt && \
    chown -R appuser:appuser /opt/webapp /var/log/webapp

USER appuser

EXPOSE 5000

CMD ["python3", "app.py"]
