#!/bin/sh
# Day 3 lab - ECB vs CBC pattern-leakage demo ("ECB penguin", text edition).
#
# Encrypts a plaintext made of several REPEATED 16-byte blocks under
# AES-128-ECB and AES-128-CBC using the SAME key, then hex-dumps both
# ciphertexts 16 bytes (32 hex chars) per line so identical plaintext
# blocks are visually obvious as identical ciphertext lines under ECB,
# and NOT identical under CBC -- the same leak that makes the famous
# "ECB penguin" image demo work, without needing an image viewer.
#
# AUTHORIZED USE ONLY: this script only encrypts the fixed sample
# plaintext below, locally, with openssl. It targets no external system.

set -eu

KEY="000102030405060708090a0b0c0d0e0f"
IV="00112233445566778899aabbccddeeff"

# 4 identical "AAAAAAAAAAAAAAAA" (16-byte) blocks, then one different
# block -- 80 bytes total (5 x 16), so -nopad needs no extra padding.
PLAINTEXT="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBB"

hexdump_blocks() {
  # 16 bytes (32 hex chars) per line, one line per AES block.
  od -An -tx1 -v | tr -d ' \n' | fold -w32
}

echo "Plaintext, 16 bytes (one AES block) per line:"
printf '%s' "$PLAINTEXT" | fold -w16
echo

echo "== AES-128-ECB ciphertext (same key, no IV) =="
printf '%s' "$PLAINTEXT" | openssl enc -aes-128-ecb -K "$KEY" -nopad -e | hexdump_blocks
echo

echo "== AES-128-CBC ciphertext (same key, fixed IV) =="
printf '%s' "$PLAINTEXT" | openssl enc -aes-128-cbc -K "$KEY" -iv "$IV" -nopad -e | hexdump_blocks
echo

echo "Observation:"
echo "  ECB: the 4 identical plaintext blocks produce 4 IDENTICAL ciphertext"
echo "       lines above -- an observer who never sees the key or plaintext"
echo "       can still tell those 4 blocks held the same data."
echo "  CBC: every ciphertext line differs, even though 4 of the 5 plaintext"
echo "       blocks were byte-for-byte identical -- CBC's chaining (each"
echo "       block is XORed with the previous ciphertext block before"
echo "       encryption) destroys that pattern."
