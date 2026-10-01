# Day 02 Lab — Solution

## Security property at each step

**PAR POST body:**
- All authorization parameters submitted directly to the auth server over mTLS/TLS back-channel.
- `authorization_details` (payment details including amount/IBAN) never touches the browser.
- If a network proxy logs the redirect URL, it sees only an opaque `request_uri`.

**`request_uri` format:**
- `urn:ietf:params:oauth:request_uri:` prefix is required by RFC 9126.
- The opaque suffix is server-generated, non-guessable (must have at least 128 bits of entropy).
- Single-use: the server invalidates it after the first `/authorize` request uses it.

**`expires_in: 90`:**
- The client must redirect the user within 90 seconds.
- Expiry limits the window for `request_uri` guessing or replay.

## What happens if `request_uri` expires

The client redirects after 90 seconds. The auth server looks up `request_uri`, finds it expired, and returns `error=invalid_request&error_description=request_uri+expired`. The client must generate a new PKCE pair and POST a new PAR request. The expired `request_uri` is discarded.

## What would break without PAR

Without PAR, the client would send `authorization_details` (including payment amount, IBAN, payee name) in the redirect URL query string. That URL appears in:
- Browser history
- Referrer headers sent to the redirect_uri server
- Proxy and CDN access logs
- Mobile OS "recent apps" screenshots

PAR moves all of this to a back-channel TLS POST where none of those vectors apply.
