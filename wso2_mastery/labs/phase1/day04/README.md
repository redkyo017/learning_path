# Day 4 Lab — Reading JWTTokenGenerator.java

No new Go code today. This lab guides you through the WSO2 IS source to find exactly where
JWTs are assembled, and through decoding a sample JWT manually.

## Part 1: Finding JWTTokenGenerator.java

Clone (or browse) the WSO2 IS source at the version your deployment uses:

```bash
# Example for wso2is-7.0.0
git clone --depth 1 --branch v7.0.0 \
  https://github.com/wso2/product-is.git wso2is-7.0.0
```

Or browse on GitHub: https://github.com/wso2/product-is

The JWT token generator lives in the identity server kernel, not in `product-is` directly.
Look in `wso2/carbon-identity-framework` or `wso2/identity-inbound-auth-oauth`:

```
components/
  org.wso2.carbon.identity.oauth/
    src/main/java/org/wso2/carbon/identity/oauth2/token/
      JWTTokenGenerator.java     ← or OauthTokenIssuerImpl.java depending on version
```

For IS 6.x/7.x the relevant file is:
```
https://github.com/wso2-extensions/identity-inbound-auth-oauth/blob/master/
  components/org.wso2.carbon.identity.oauth/src/main/java/
  org/wso2/carbon/identity/oauth2/token/JWTTokenIssuer.java
```

## Part 2: Find buildJWTClaimSet

Once you have the file open, search for `buildJWTClaimSet`. Answer these questions:

1. What library is used to build the claims? (hint: look at the import for `com.nimbusds`)
2. Where is the subscriber claim (`http://wso2.org/claims/subscriber`) added?
3. Where is the `keytype` claim added? What determines whether the value is `PRODUCTION`
   or `SANDBOX`?
4. Where is `kid` set on the JWT header?

Expected findings:
- The Nimbus Jose+JWT library (`com.nimbusds.jwt.JWTClaimsSet.Builder`) builds the payload
- Custom claims are added via `.claim(claimURI, value)` calls
- The `keytype` comes from the `OAuthTokenReqMessageContext` — it reflects whether the
  application registered a production or sandbox key
- The `kid` is derived from the signing certificate's thumbprint (SHA-256 hex or alias)

## Part 3: Decode a sample WSO2 JWT manually

If you have access to a live WSO2 IS instance, issue a token:

```bash
curl -s -k -u <client_id>:<client_secret> \
  -d "grant_type=client_credentials" \
  https://<is-host>:9443/oauth2/token
```

If you don't have a live instance, use the output of the Day 5 lab server (run it locally).

Once you have a JWT (the `access_token` value):

```bash
TOKEN="<paste token here>"

# Decode the header (part 1)
echo $TOKEN | cut -d'.' -f1 | base64 -d 2>/dev/null; echo

# Decode the payload (part 2)
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null; echo

# Pretty-print with python3 (no dependencies needed)
echo $TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

Note on padding: `base64 -d` expects padding (`=` characters). If you see an error, add padding:

```bash
PART=$(echo $TOKEN | cut -d'.' -f2)
# Calculate padding needed: length must be multiple of 4
PAD=$(( 4 - ${#PART} % 4 ))
if [ $PAD -ne 4 ]; then
  PADDED="${PART}$(printf '=%.0s' $(seq 1 $PAD))"
else
  PADDED="$PART"
fi
echo $PADDED | base64 -d | python3 -m json.tool
```

## Part 4: Claim classification exercise

Take the decoded payload and fill in this table:

| Claim key | Value (from your token) | Category |
|-----------|------------------------|----------|
| `iss` | | RFC 7519 standard |
| `sub` | | RFC 7519 standard |
| `iat` | | RFC 7519 standard |
| `exp` | | RFC 7519 standard |
| `jti` | | RFC 7519 standard |
| `http://wso2.org/claims/subscriber` | | WSO2 custom |
| `http://wso2.org/claims/applicationname` | | WSO2 custom |
| `http://wso2.org/claims/applicationtier` | | WSO2 custom |
| `http://wso2.org/claims/version` | | WSO2 custom |
| `http://wso2.org/claims/keytype` | | WSO2 custom |

Note which claims are present and which are absent — not all deployments include every claim.

## Part 5: kid rotation exercise (written)

Write a bullet-point sequence of steps to rotate the RSA signing key in WSO2 IS without
causing any API gateway to return 401 for valid in-flight tokens.

Key questions to answer:
- When does the gateway refresh its JWKS cache?
- What must be true about the JWKS during the rotation window?
- When is it safe to remove the old key from the JWKS?

(Answers in Day 4 content file, Exercise 3 solution sketch.)

## What you should take away

After this lab you should be able to:
- Navigate the WSO2 IS Java source to find the JWT assembly code
- Decode any JWT payload from the command line
- Identify all 5 WSO2-specific claim URIs from memory
- Explain the `kid` → JWKS lookup chain in one sentence
