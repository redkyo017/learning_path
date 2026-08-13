#!/bin/sh
# IOC:TROJANIZED-BINARY -- replaces the real coreutils /bin/true. Behavior
# is deliberately unchanged (still exits 0) precisely to make the point
# that you cannot rely on "does it behave badly?" to catch this: the file
# on disk is simply no longer the original binary. A hash comparison
# against a pre-tampering baseline (see /opt/evidence/baseline-hashes.txt,
# captured earlier in the Dockerfile, before this file replaced it) is
# what actually catches it.
exit 0
