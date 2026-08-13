# Day 2 target half #2: `victim` only exists on `day02-mitm`, the
# isolated segment private to this lab. It is NOT on the shared
# `cyberlab` network, and so is not directly reachable from the attacker
# container until the attacker deliberately joins `day02-mitm` (see
# ../README.md) -- deliberately mirroring the real gap between "I can
# enumerate a host" and "I'm on the same L2 segment as its traffic."
FROM python:3.12-alpine

COPY victim.py /victim.py

CMD ["python3", "/victim.py"]
