#!/usr/bin/env python3
"""Day 2 target: a tiny, deliberately plaintext "LegacyAuth" service.

Real protocol analog: this is the FTP control-channel pattern (banner ->
USER -> 331 -> PASS -> 230), simplified. Nothing here is encrypted, on
purpose -- the point of Day 2's MITM demo is to sniff a real cleartext
credential exchange between two containers, not to break a cipher.
"""
import socket

HOST, PORT = "0.0.0.0", 2121


def serve() -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen(5)
        print(f"LegacyAuth listening on {PORT}", flush=True)
        while True:
            conn, addr = s.accept()
            print(f"connection from {addr}", flush=True)
            with conn:
                try:
                    conn.sendall(b"220 LegacyAuth Service (LegacyCorp) ready\r\n")
                    conn.recv(4096)  # "USER admin"
                    conn.sendall(b"331 Password required for admin\r\n")
                    conn.recv(4096)  # "PASS ..."
                    conn.sendall(b"230 User admin logged in, proceed\r\n")
                except OSError:
                    pass


if __name__ == "__main__":
    serve()
