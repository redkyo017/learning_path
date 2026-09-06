# syntax=docker/dockerfile:1.7
# The lab HTTP service. arm64 multi-arch base, tag-pinned (see fleet/README.md).
FROM python:3.12-alpine

# Without this, stdout through a pipe is block-buffered and `docker logs`
# looks frozen. app.py flushes explicitly too; belt and braces.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Defaults, restated in docker-compose.yml so both are greppable.
ENV BIND_ADDR=0.0.0.0 \
    PORT=8080 \
    LOG_PATH=/var/log/app.log \
    IGNORE_SIGTERM=0

WORKDIR /srv
COPY app.py /srv/app.py

EXPOSE 8080

# ---------------------------------------------------------------------------
# INTENTIONAL DEFECT -- Day 2 (process table / the syscall boundary).
#
# Shell form. PID 1 in this container is `/bin/sh`, not python. A
# non-interactive shell does not forward SIGTERM to its children, so
# `docker stop app` sends SIGTERM to PID 1, nothing happens, and the daemon
# waits out the full 10s grace period before SIGKILL. Prove it before you fix
# it -- never take a Dockerfile comment's word for what PID 1 is:
#
#     docker compose -p linuxops exec app ps -o pid,ppid,args
#     docker compose -p linuxops exec app cat /proc/1/cmdline | tr '\0' ' '
#     docker compose -p linuxops exec app cat /proc/1/status   # Name, SigIgn
#
# The `; exit $?` is load-bearing, and it is the most useful thing on this
# page. Given a single simple command, busybox ash and dash both optimise
# `sh -c "cmd"` into a bare exec(): the shell replaces itself with python,
# python becomes PID 1, and the container stops cleanly. A second command
# after the semicolon removes that option -- the shell has to stay resident to
# run it -- so PID 1 is a shell, always, on every build.
#
# That is why some real-world images with shell-form entrypoints handle
# signals correctly by accident and others hang for ten seconds on every
# deploy: one word of shell syntax decides which process the kernel delivers
# the signal to. The trailing exit is also why the difference is invisible in
# `docker inspect` -- you have to read /proc/1.
ENTRYPOINT ["sh", "-c", "python /srv/app.py; exit $?"]

# The corrected exec form -- Day 2's fix. Swap the two lines and rebuild:
# ENTRYPOINT ["python", "/srv/app.py"]
#
# What IGNORE_SIGTERM actually does, stated precisely, because the obvious
# guess is wrong:
#
# With the shell form above, `docker stop app` signals PID 1 and PID 1 only.
# PID 1 is `sh`, and a non-interactive shell waiting on a child neither dies
# on SIGTERM nor forwards it, so python never sees the signal at all. The ten
# second wait comes entirely from the shell. IGNORE_SIGTERM has *no*
# observable effect on `docker stop` in this configuration -- the branch it
# controls is never reached.
#
# To exercise it, send the signal to python directly, from inside the
# container:
#
#     docker compose -p linuxops exec app sh -c \
#       'kill -TERM $(pgrep -f "/srv/app[.]py")'
#     docker compose -p linuxops logs app | tail -1
#
# Inside the container the same command reads:
#
#     kill -TERM $(pgrep -f '/srv/app[.]py')
#
# (double quotes above only because the outer sh -c already used the single
#  ones; nothing inside them is expanded by the shell)
#
# The brackets are not decoration. `pgrep -f` matches against the whole
# command line, and the command line of the wrapper shell running this very
# substitution contains the pattern -- so an unbracketed `/srv/app.py` matches
# python AND the shell doing the matching, and the kill hits both. pgrep skips
# its own pid, not its parent's. `[.]` still matches a literal dot but no
# longer appears in the pattern as written, so the wrapper's command line
# cannot match it. Any pattern that could appear in the command line of the
# process doing the search needs this trick; the classic `grep "[p]ython"` is
# the same idea.
#
# (busybox pgrep has -f. If you would rather not trust that, the busybox-safe
#  long way is: ps -o pid,args | grep "[p]ython /srv" | awk "{print \$1}")
#
# With IGNORE_SIGTERM=0 the process logs "got SIGTERM, shutting down" and
# exits 0; with IGNORE_SIGTERM=1 it logs "ignoring SIGTERM" and stays up.
# After the entrypoint is switched to the exec form above, python is PID 1 and
# IGNORE_SIGTERM=1 then produces the slow `docker stop` on its own -- which is
# the second half of Day 2's lesson: the same environment variable is inert or
# decisive depending on which process the kernel hands the signal to.
# ---------------------------------------------------------------------------
