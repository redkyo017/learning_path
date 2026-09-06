#!/usr/bin/env python3
"""Lab HTTP service for the Linux Operator Mastery fleet.

Standard library only. One file. No dependencies, on purpose: the point of
this service is to be a *predictable* process to point /proc, cgroup files,
strace and tcpdump at -- not to be interesting software.

Endpoints (all GET):

    /                     200, body "ok"
    /healthz              200, body "healthy"
    /burn?seconds=N       spins a CPU for N seconds in a background thread
                          (Day 4: cpu.stat throttling)
    /balloon?mb=N         allocates N MiB in THIS process and holds it. Past
                          mem_limit the OOM killer takes python; PID 1 exits
                          behind it and the container is replaced, along with
                          the cgroup that recorded the kill
    /balloon?mb=N&child=1 forks; the child allocates and holds N MiB and is
                          the one the OOM killer takes. The parent answers
                          202 with the child's pid, python and PID 1 survive,
                          the container does not exit, and oom_kill in
                          memory.events stays readable in the cgroup it
                          incremented in
    /log?n=N              appends N lines to $LOG_PATH
                          (Day 1: fills the 24m tmpfs on /var/log)
    /fail?code=C          responds with status C (200-599; 1xx is rejected
                          because it cannot be rendered as a final response)
    /fail?code=C&sticky=1 responds C *and* makes / and /healthz answer C from
                          then on (Day 6, fault 5: the failure has to persist)
    /fail?code=200        clears the sticky state, with or without sticky=1

Sticky mode covers the two health endpoints, `/` and `/healthz`, and only
those. The control endpoints -- /fail, /burn, /balloon, /log -- always answer
for themselves, so the fault can always be cleared and Day 4 can still drive
/burn while Day 6's fault is armed.

Environment:

    BIND_ADDR        default 0.0.0.0
    PORT             default 8080
    LOG_PATH         default /var/log/app.log
    IGNORE_SIGTERM   default 0; set to 1 to make the process ignore SIGTERM
                     (Day 2: docker stop then has to wait out the grace
                     period and SIGKILL)
"""

import os
import random
import signal
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

BIND_ADDR = os.environ.get("BIND_ADDR", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))
LOG_PATH = os.environ.get("LOG_PATH", "/var/log/app.log")
IGNORE_SIGTERM = os.environ.get("IGNORE_SIGTERM", "0") == "1"

# Module level on purpose: a local list would be collected the moment the
# request handler returned and the OOM kill would never reproduce.
BALLOON = []
BALLOON_LOCK = threading.Lock()

# Sticky failure state. None means "not sticky".
STICKY_CODE = None
STICKY_LOCK = threading.Lock()

MAX_BURN_SECONDS = 3600
MAX_BALLOON_MB = 4096
MAX_LOG_LINES = 1000000


def now_iso():
    """Timestamp in the exact shape the log fixtures use."""
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def say(msg):
    """One line to stdout, flushed, so `docker logs -f app` is live."""
    sys.stdout.write("%s %s\n" % (now_iso(), msg))
    sys.stdout.flush()


def on_sigterm(signum, frame):
    if IGNORE_SIGTERM:
        say("ignoring SIGTERM")
        return
    say("got SIGTERM, shutting down")
    # Exit straight from the handler: deterministic status 0, no chance of a
    # worker thread keeping the interpreter alive.
    os._exit(0)


def clamp(value, low, high):
    return max(low, min(high, value))


def int_arg(query, name, default):
    """Parse one integer query parameter. Raises ValueError if malformed."""
    values = query.get(name)
    if not values:
        return default
    return int(values[0])


def burn(seconds):
    """Busy-loop on the monotonic clock. Deliberately not time.sleep()."""
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        pass
    say("burn finished after %ds" % seconds)


def balloon(mb):
    """Allocate mb MiB of *resident* memory and keep a reference to it."""
    for _ in range(mb):
        # Filled with a non-zero byte: a zeroed bytearray can stay backed by
        # the shared zero page and never count against the cgroup.
        chunk = bytearray(b"\xa5" * (1024 * 1024))
        with BALLOON_LOCK:
            BALLOON.append(chunk)
    return len(BALLOON)


def balloon_forever(mb):
    """Runs in the forked child of /balloon?child=1. Never returns.

    Every exit path is os._exit(): a forked child that fell back into the
    HTTP server loop would answer requests with a second copy of the
    application, which is a far more confusing bug than the one this
    endpoint exists to cause.
    """
    try:
        held = []
        for _ in range(mb):
            held.append(bytearray(b"\xa5" * (1024 * 1024)))
        while True:
            time.sleep(3600)
    except BaseException:
        pass
    os._exit(0)


def log_lines(n):
    """Append n lines to LOG_PATH, flushing every one of them."""
    written = 0
    with open(LOG_PATH, "a") as handle:
        for _ in range(n):
            line = "%s INFO req_id=%08x status=200 latency_ms=%d path=/x\n" % (
                now_iso(),
                random.getrandbits(32),
                random.randint(1, 250),
            )
            handle.write(line)
            handle.flush()
            written += 1
    return written


class Handler(BaseHTTPRequestHandler):
    server_version = "linuxops-app/1.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        say("access %s" % (fmt % args))

    def reply(self, code, body):
        payload = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        # Control endpoints run before the sticky gate and are never gated by
        # it. A fault you cannot clear is not a fault, it is a broken lab, and
        # Day 4 still needs /burn while Day 6's fault 5 is armed.
        if path == "/fail":
            return self.handle_fail(query)
        if path == "/burn":
            return self.handle_burn(query)
        if path == "/balloon":
            return self.handle_balloon(query)
        if path == "/log":
            return self.handle_log(query)

        # Everything below is what a health check or a proxy would call, and
        # that is exactly what sticky mode is meant to poison.
        with STICKY_LOCK:
            stuck = STICKY_CODE
        if stuck is not None:
            return self.reply_sticky(stuck)

        if path == "/":
            return self.reply(200, "ok\n")
        if path == "/healthz":
            return self.reply(200, "healthy\n")
        return self.reply(404, "no such endpoint: %s\n" % path)

    def reply_sticky(self, code):
        self.reply(code, "sticky failure: / and /healthz answer %d "
                         "until GET /fail?code=200\n" % code)

    def handle_fail(self, query):
        global STICKY_CODE
        try:
            code = int_arg(query, "code", 500)
        except ValueError:
            return self.reply(400, "code must be an integer\n")
        # 1xx is refused rather than clamped: send_response() would emit an
        # informational status as if it were final and the client would see a
        # malformed response.
        if code < 200 or code > 599:
            return self.reply(400, "code must be between 200 and 599\n")
        sticky = query.get("sticky", ["0"])[0] == "1"

        # Any code=200 clears, with or without sticky=1. Clearing a fault must
        # not depend on remembering a second query parameter.
        if code == 200:
            with STICKY_LOCK:
                was = STICKY_CODE
                STICKY_CODE = None
            if was is None:
                return self.reply(200, "nothing was armed\n")
            say("sticky failure cleared (was %d)" % was)
            return self.reply(200, "sticky cleared (was %d)\n" % was)

        if sticky:
            with STICKY_LOCK:
                STICKY_CODE = code
            say("sticky failure armed: code=%d" % code)
            return self.reply(code, "sticky failure armed: %d\n" % code)
        return self.reply(code, "fail %d\n" % code)

    def handle_burn(self, query):
        try:
            seconds = clamp(int_arg(query, "seconds", 5), 0, MAX_BURN_SECONDS)
        except ValueError:
            return self.reply(400, "seconds must be an integer\n")
        worker = threading.Thread(target=burn, args=(seconds,), daemon=True)
        worker.start()
        say("burn started: %ds" % seconds)
        return self.reply(200, "burning %d seconds\n" % seconds)

    def handle_balloon(self, query):
        try:
            mb = clamp(int_arg(query, "mb", 0), 0, MAX_BALLOON_MB)
        except ValueError:
            return self.reply(400, "mb must be an integer\n")
        if query.get("child", ["0"])[0] == "1":
            return self.handle_balloon_child(mb)
        held = balloon(mb)
        say("balloon: +%d MiB, holding %d MiB" % (mb, held))
        return self.reply(200, "holding %d MiB\n" % held)

    def handle_balloon_child(self, mb):
        """Fork a child to hold the memory, so the cgroup outlives the kill.

        Without this, the OOM killer takes python, PID 1 (`sh`) runs its
        `exit $?`, the container exits 137 and the restart policy replaces it
        with a NEW runc task in a NEW leaf cgroup -- where memory.events is
        back at oom_kill=0. The learner would read zero and a verify script
        would pass on it. With this, the killer takes the child instead, this
        process and PID 1 survive, and the counter stays readable.
        """
        try:
            pid = os.fork()
        except OSError as err:
            say("fork failed: %s" % err)
            return self.reply(500, "fork failed: %s\n" % err)

        if pid == 0:
            # The child must be the guaranteed OOM victim: if the kernel ever
            # picked the parent instead, PID 1 would exit with it and take the
            # cgroup counters this lab reads down with the container.
            # Raising one's OWN oom_score_adj needs no privilege (lowering it
            # does, which is why the parent's is left alone). If the write is
            # refused, fall back to the heuristic -- the child outweighs the
            # parent long before the ceiling anyway.
            try:
                with open("/proc/self/oom_score_adj", "w") as adj:
                    adj.write("500")
            except Exception:
                pass
            # Drop the inherited sockets -- the parent owns this request and
            # the listening socket -- then never come back.
            try:
                self.connection.close()
            except Exception:
                pass
            try:
                self.server.socket.close()
            except Exception:
                pass
            balloon_forever(mb)
            os._exit(0)          # unreachable; belt and braces

        # Parent. No wait() here: SIGCHLD is SIG_IGN, so the kernel reaps.
        say("balloon child forked: pid=%d mb=%d" % (pid, mb))
        return self.reply(202, "balloon child pid=%d holding %d MiB\n"
                               % (pid, mb))

    def handle_log(self, query):
        try:
            n = clamp(int_arg(query, "n", 100), 0, MAX_LOG_LINES)
        except ValueError:
            return self.reply(400, "n must be an integer\n")
        try:
            written = log_lines(n)
        except OSError as err:
            say("log write failed: %s" % err)
            return self.reply(507, "write to %s failed: %s\n" % (LOG_PATH, err))
        return self.reply(200, "wrote %d lines to %s\n" % (written, LOG_PATH))


def main():
    signal.signal(signal.SIGTERM, on_sigterm)
    # Auto-reap: with SIGCHLD set to SIG_IGN the kernel reaps children itself
    # and never leaves a zombie. /balloon?child=1 forks and deliberately does
    # not wait, and Day 2's lab counts zombies across the whole container --
    # this service must not manufacture any of its own.
    signal.signal(signal.SIGCHLD, signal.SIG_IGN)
    directory = os.path.dirname(LOG_PATH)
    if directory:
        try:
            os.makedirs(directory, exist_ok=True)
        except OSError as err:
            say("cannot create %s: %s" % (directory, err))
    say("app.py pid=%d bind=%s:%d log_path=%s ignore_sigterm=%d"
        % (os.getpid(), BIND_ADDR, PORT, LOG_PATH, 1 if IGNORE_SIGTERM else 0))
    server = ThreadingHTTPServer((BIND_ADDR, PORT), Handler)
    server.daemon_threads = True
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        say("got SIGINT, shutting down")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
