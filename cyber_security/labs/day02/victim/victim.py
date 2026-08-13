#!/usr/bin/env python3
"""Day 2 target: `victim` logs into `server`'s plaintext LegacyAuth
service every few seconds, in the clear, forever. This is the traffic an
ARP-spoof MITM position on `day02-mitm` lets an attacker read.
"""
import socket
import time

SERVER, PORT = "server", 2121


def login_once() -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(5)
        s.connect((SERVER, PORT))
        s.recv(4096)  # banner
        s.sendall(b"USER admin\r\n")
        s.recv(4096)  # 331
        s.sendall(b"PASS CorpVPN!Secret2024\r\n")
        s.recv(4096)  # 230


if __name__ == "__main__":
    while True:
        try:
            login_once()
        except OSError:
            pass
        time.sleep(5)
