"""
Day 7 mitmproxy addon -- request tampering demo.

Loaded by the `proxy` service (see ../docker-compose.yml) via:

    mitmdump --listen-port 8080 -s /home/mitmproxy/scripts/tamper_addon.py \
             --set flow_detail=3 -w /home/mitmproxy/flows/day07.flow

Concept it demonstrates (see content/day07-http.md, Section 2, Step 3):
mitmproxy sits BETWEEN the attacker container's curl and `juiceshop`, and
can rewrite a request in flight before it ever reaches the app. The app
has no way to tell the difference between what its real caller sent and
what this proxy changed underneath it -- HTTP gives the server nothing
but "here is a request," with no built-in guarantee the request in hand
is what the client thinks it sent.

What it does: any request to Juice Shop's product-search endpoint
(`/rest/products/search?q=...`) has its `q` query parameter silently
rewritten to TAMPER_VALUE, no matter what the caller actually asked for.
The original value is stashed on the flow's metadata so it still shows up
in `docker compose logs proxy` for comparison.

This is a deliberately simple, single-parameter tamper -- the point of
today's lab is proving the mechanism (a proxy can rewrite requests
invisibly to both ends), not building a realistic exploit chain. Day 8
covers turning tampered input into an actual injection attack.
"""
from mitmproxy import http

TAMPER_PATH = "/rest/products/search"
TAMPER_VALUE = "juice"


def request(flow: http.HTTPFlow) -> None:
    if flow.request.path.startswith(TAMPER_PATH) and "q" in flow.request.query:
        original = flow.request.query["q"]
        if original != TAMPER_VALUE:
            flow.request.query["q"] = TAMPER_VALUE
            flow.comment = f"tampered: q={original!r} -> q={TAMPER_VALUE!r}"
