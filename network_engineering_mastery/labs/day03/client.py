#!/usr/bin/env python3
"""client.py HOST PORT N

Open N sequential TCP connections to HOST:PORT. On each one: send "HEAD / HTTP/1.0",
half-close (FIN) right away, read until the server closes, then close. The client
sends the first FIN, so the client is the active closer and its sockets land in
TIME_WAIT. Prints how many connections worked, how many failed, and the first error.
"""
import socket
import sys


def one(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(3)
    try:
        s.connect((host, port))
        s.sendall(b"HEAD / HTTP/1.0\r\n\r\n")
        s.shutdown(socket.SHUT_WR)          # our FIN goes out before the server's
        while s.recv(4096):
            pass
    finally:
        s.close()


def main():
    if len(sys.argv) != 4:
        sys.exit("usage: client.py HOST PORT N")
    host, port, n = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    ok = errors = 0
    first = None
    for _ in range(n):
        try:
            one(host, port)
            ok += 1
        except OSError as e:
            errors += 1
            if first is None:
                first = str(e)
    print(f"ok={ok} errors={errors}")
    if first:
        print(f"first error: {first}")


if __name__ == "__main__":
    main()
