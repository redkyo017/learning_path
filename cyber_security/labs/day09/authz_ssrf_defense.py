#!/usr/bin/env python3
"""Day 9 Defense Lab demo -- runs ENTIRELY locally, no server/network
involved (same pattern as Day 3's ecb_cbc_demo.sh / padding_oracle_demo.py):
stage this file into the shared loot dir with a plain `cp`, then run it
inside the already-running `attacker` container. Its job is to give you a
real, edit-it-yourself, before/after re-verification of the two defenses
this lab's live target CAN'T show you a rebuild-and-reverify for, since we
don't own Juice Shop's source: the broken-access-control (IDOR) fix and the
SSRF allowlist fix. See content/day09-access-ssrf-csrf.md Section 3.

Run it as-is first (the VULNERABLE versions, matching what Steps 1-2 of the
Attack Lab exploit), read the FAIL lines, then edit the two functions marked
"BEFORE" below to their commented-out "AFTER" versions and re-run to see the
same inputs produce the opposite, correct result -- the exact same code,
different logic, different outcome, nothing else changed.
"""
import sys

# ---------------------------------------------------------------------------
# Defense 1: broken access control / IDOR
#
# The bug Step 1 of the Attack Lab exploits: an endpoint that trusts the
# object ID in the URL/request and never checks whether the CALLER actually
# owns that object. This function represents that check.
# ---------------------------------------------------------------------------


def can_access_basket(requesting_user_id, basket_owner_id, is_admin=False):
    """BEFORE (vulnerable, matches this lab's live IDOR): any authenticated
    user can load ANY basket ID, because the only thing checked is that a
    caller is logged in at all -- not that the caller is who they claim to
    be relative to THIS specific object."""
    return True  # <-- the entire bug is right here: no ownership check.

    # AFTER (fixed) -- uncomment this and delete/comment the `return True`
    # above to re-verify:
    # return is_admin or requesting_user_id == basket_owner_id


# ---------------------------------------------------------------------------
# Defense 2: SSRF allowlist + link-local block
#
# The bug Step 2 of the Attack Lab exploits: an endpoint that fetches
# whatever URL a caller supplies with NO restriction on the destination.
# This function represents the fetcher's decision of whether a URL is safe
# to actually request.
# ---------------------------------------------------------------------------

# A BLOCKLIST of private/link-local prefixes looks like the obvious fix, but
# it isn't the one used below on purpose: blocklists are bypassable (DNS
# rebinding, decimal/octal IP encoding, redirects the fetcher follows blindly,
# a new private range nobody added yet) in exactly the way an ALLOWLIST
# structurally can't be. Kept here only as a documented "why not":
BLOCKED_HOST_PREFIXES_NOT_USED_BELOW = ("169.254.", "127.", "10.", "172.16.", "192.168.")
ALLOWED_HOSTS = {"images.example-cdn.test"}  # the only legitimate use case: fetching a real avatar CDN


def is_allowed_fetch_target(url_host):
    """BEFORE (vulnerable, matches this lab's live SSRF): fetch anything,
    no questions asked."""
    return True  # <-- the entire bug is right here: no destination check.

    # AFTER (fixed) -- uncomment this and delete/comment the `return True`
    # above to re-verify. Default-deny, allowlist-only: this rejects
    # 169.254.169.254 (today's `internal` target, and the REAL cloud
    # metadata address Day 15 attacks), `internal` by its DNS name, loopback,
    # and everything else NOT explicitly the one legitimate destination --
    # with no prefix list to keep in sync and nothing to bypass by phrasing
    # the same blocked address a different way:
    # return url_host in ALLOWED_HOSTS


# ---------------------------------------------------------------------------
# Test harness -- prints PASS/FAIL against representative cases. Re-run
# after editing either function above; PASS/FAIL flips, nothing else does.
# ---------------------------------------------------------------------------

IDOR_CASES = [
    # (requesting_user_id, basket_owner_id, is_admin, expected_after_fix)
    (42, 42, False, True),  # you accessing your own basket: always allowed
    (42, 7, False, False),  # you accessing someone else's basket: must be denied
    (42, 7, True, True),  # an admin accessing anyone's basket: allowed
]

SSRF_CASES = [
    # (host, expected_after_fix)
    ("169.254.169.254", False),  # today's `internal` target / real cloud IMDS -- must be denied
    ("127.0.0.1", False),  # loopback -- must be denied
    ("images.example-cdn.test", True),  # the one legitimate use case -- must be allowed
    ("internal", False),  # the service's DNS name inside day09-app -- must be denied too
]


def run():
    print("=== Defense 1: broken access control / IDOR ===")
    for uid, owner, admin, expected in IDOR_CASES:
        got = can_access_basket(uid, owner, admin)
        status = "PASS" if got == expected else "FAIL"
        print(
            f"  can_access_basket(user={uid}, owner={owner}, admin={admin}) "
            f"-> {got}  (secure-expected={expected})  [{status}]"
        )

    print()
    print("=== Defense 2: SSRF allowlist + link-local block ===")
    for host, expected in SSRF_CASES:
        got = is_allowed_fetch_target(host)
        status = "PASS" if got == expected else "FAIL"
        print(
            f"  is_allowed_fetch_target({host!r}) -> {got}  "
            f"(secure-expected={expected})  [{status}]"
        )

    print()
    print(
        "If every line above says FAIL, you're running the BEFORE "
        "(vulnerable) versions -- exactly what makes Steps 1-2 of the "
        "Attack Lab work. Edit the two functions to their AFTER versions "
        "(commented out above) and re-run: every line should flip to PASS."
    )


if __name__ == "__main__":
    run()
    sys.exit(0)
