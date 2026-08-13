#!/usr/bin/env python3
"""
Day 3 lab - conceptual CBC padding-oracle attack demo.

WHAT THIS IS: a self-contained, pure-Python simulation of a CBC padding-
oracle attack. It uses a TOY stand-in "cipher" (plain byte-XOR with a
secret key) instead of real AES, purely so the script has zero external
dependencies. This matters for what the demo does and does NOT prove:

  - It does NOT show a weakness in AES. The toy cipher here is trivially
    breakable on its own and is not meant to represent AES's strength.
  - It DOES show the actual attack technique real padding-oracle attacks
    (e.g. against real AES-CBC servers, as in the 2002 Vaudenay attack
    and tools like PadBuster) use: the attack only depends on (a) CBC's
    XOR-chaining structure and (b) a server that leaks, via a distinguish-
    able response, whether decrypted PKCS#7 padding was valid -- it does
    NOT depend on breaking the block cipher itself. Swap the toy
    `block_transform` function for real AES-128 decryption and the exact
    same attack loop recovers real AES-CBC plaintext, one byte at a time,
    without ever learning the key.

AUTHORIZED USE ONLY: this script only decrypts its own locally-generated
sample ciphertext. It contacts no network and targets no external system.

Run: python3 padding_oracle_demo.py
"""

BLOCK_SIZE = 16

# --- Toy "cipher": a fixed-key XOR permutation standing in for AES-128's
# single-block decrypt (and, since XOR is its own inverse, encrypt too)
# function. NOT cryptographically secure -- see module docstring. The
# attack loop below never looks inside this function; it only ever gets
# a valid/invalid signal back from padding_oracle(), exactly like a real
# attacker against a real server.
_SECRET_KEY = bytes(range(1, BLOCK_SIZE + 1))  # fixed for reproducible output


def block_transform(block: bytes) -> bytes:
    return bytes(b ^ k for b, k in zip(block, _SECRET_KEY))


# --- PKCS#7 padding ---------------------------------------------------

def pkcs7_pad(data: bytes) -> bytes:
    pad_len = BLOCK_SIZE - (len(data) % BLOCK_SIZE)
    return data + bytes([pad_len]) * pad_len


def pkcs7_unpad_or_raise(data: bytes) -> bytes:
    pad_len = data[-1]
    if pad_len == 0 or pad_len > BLOCK_SIZE:
        raise ValueError("bad padding")
    if data[-pad_len:] != bytes([pad_len]) * pad_len:
        raise ValueError("bad padding")
    return data[:-pad_len]


# --- Toy CBC mode -------------------------------------------------------

def cbc_encrypt(plaintext: bytes, iv: bytes) -> bytes:
    padded = pkcs7_pad(plaintext)
    blocks = [padded[i:i + BLOCK_SIZE] for i in range(0, len(padded), BLOCK_SIZE)]
    ciphertext = b""
    prev = iv
    for block in blocks:
        xored = bytes(a ^ b for a, b in zip(block, prev))
        ct_block = block_transform(xored)
        ciphertext += ct_block
        prev = ct_block
    return ciphertext


def cbc_decrypt_raw(ciphertext: bytes, iv: bytes) -> bytes:
    blocks = [ciphertext[i:i + BLOCK_SIZE] for i in range(0, len(ciphertext), BLOCK_SIZE)]
    plaintext = b""
    prev = iv
    for block in blocks:
        decrypted = block_transform(block)
        plaintext += bytes(a ^ b for a, b in zip(decrypted, prev))
        prev = block
    return plaintext


def padding_oracle(ciphertext: bytes, iv: bytes) -> bool:
    """Simulates a server that decrypts and reveals ONLY whether padding
    was valid -- exactly the narrow signal a real vulnerable server leaks
    (a different error message, a timing difference, a distinct HTTP
    status). No plaintext or key is ever returned."""
    try:
        pkcs7_unpad_or_raise(cbc_decrypt_raw(ciphertext, iv))
        return True
    except ValueError:
        return False


# --- The attack: recover one ciphertext block's plaintext without the key

def recover_block(target_block: bytes, real_prev_block: bytes, iv: bytes) -> bytes:
    """Recovers the plaintext of `target_block` using ONLY the oracle's
    valid/invalid signal, by forging a fake preceding block one byte at a
    time and asking the oracle to decrypt [forged_prev || target_block]
    against the fixed `iv`. `real_prev_block` (the actual ciphertext
    block -- or the real IV, for block 0) is needed only at the very end
    to turn the recovered intermediate value into real plaintext; the
    oracle queries themselves never use it."""
    intermediate = bytearray(BLOCK_SIZE)  # D(target_block), solved byte by byte
    recovered = bytearray(BLOCK_SIZE)

    for pad_val in range(1, BLOCK_SIZE + 1):
        pos = BLOCK_SIZE - pad_val  # solving right to left
        forged = bytearray(BLOCK_SIZE)
        for i in range(pos + 1, BLOCK_SIZE):
            forged[i] = intermediate[i] ^ pad_val

        found = False
        for guess in range(256):
            forged[pos] = guess
            if padding_oracle(bytes(forged) + target_block, iv):
                intermediate[pos] = guess ^ pad_val
                recovered[pos] = intermediate[pos] ^ real_prev_block[pos]
                found = True
                break
        if not found:
            raise RuntimeError("oracle attack failed to find a valid padding byte")

    return bytes(recovered)


def main():
    # Fixed (not random) IV so this demo's output is reproducible run to
    # run -- a real system would use a fresh random IV per message; that
    # choice has no bearing on the padding-oracle attack itself, which
    # never needs to guess or know the IV's value, only supply it back
    # unchanged to the oracle.
    iv = bytes(range(200, 216))
    secret = b"padding-oracles leak plaintext without ever needing the key!"
    ciphertext = cbc_encrypt(secret, iv)
    print(f"Secret plaintext (attacker does NOT get this):\n  {secret!r}\n")
    print(f"Ciphertext the attacker DOES have ({len(ciphertext)} bytes):\n  {ciphertext.hex()}\n")

    blocks = [ciphertext[i:i + BLOCK_SIZE] for i in range(0, len(ciphertext), BLOCK_SIZE)]
    real_prev_blocks = [iv] + blocks[:-1]

    recovered_padded = b""
    print("Recovering plaintext one block, one byte, at a time -- using ONLY")
    print("the oracle's valid/invalid padding signal (no key, no real decrypt):\n")
    for idx, (block, prev) in enumerate(zip(blocks, real_prev_blocks)):
        plain_block = recover_block(block, prev, iv)
        recovered_padded += plain_block
        print(f"  block {idx}: {plain_block!r}")

    recovered = pkcs7_unpad_or_raise(recovered_padded)
    print(f"\nFully recovered plaintext:\n  {recovered!r}")
    assert recovered == secret, "recovery mismatch -- see script comments"
    print("\nMatches the real secret exactly -- recovered with zero knowledge of the key.")


if __name__ == "__main__":
    main()
