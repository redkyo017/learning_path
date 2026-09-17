# Day 51 — Go OAuthGrantHandler Dispatch Lab

## Goal
Build and test a custom OAuth2 token endpoint that dispatches to different grant handlers based on `grant_type`. Understand handler dispatch order, error handling, and extending with custom grant types.

## Setup
```bash
cd labs/phase4/day51
go run main.go
# Output: "Custom grant handler blueprint on :8091"
```

## Test 1: Client Credentials Grant (200 OK)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=client_credentials&client_id=demo-client-id&client_secret=demo-secret&scope=read'
```

Expected output:
```json
{
  "access_token": "cc-tok-<timestamp>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "read"
}
```

Log output: `token issued grant=client_credentials client=demo-client-id`

## Test 2: Password Grant (ROPC) with Valid Credentials (200 OK)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=password&username=alice&password=pass123&scope=write'
```

Expected output:
```json
{
  "access_token": "ropc-alice-<timestamp>",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "write"
}
```

## Test 3: Password Grant with Invalid Credentials (400 Bad Request)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=password&username=alice&password=wrong&scope=write'
```

Expected output (HTTP 400):
```json
{
  "error": "invalid_grant",
  "error_description": ""
}
```

## Test 4: Custom Device Code Grant (200 OK)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:device_code&password=device-abc'
```

Expected output:
```json
{
  "access_token": "device-carol-<timestamp>",
  "token_type": "Bearer",
  "expires_in": 900
}
```

Note: `expires_in` is 900 (15 minutes) for device grant, vs. 3600 for others.

## Test 5: Invalid Device Code (400 Bad Request)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:device_code&password=invalid-code'
```

Expected output (HTTP 400):
```json
{
  "error": "authorization_pending",
  "error_description": ""
}
```

## Test 6: Unsupported Grant Type (400 Bad Request)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=unsupported_grant&client_id=demo'
```

Expected output (HTTP 400):
```json
{
  "error": "unsupported_grant_type",
  "error_description": "unsupported_grant"
}
```

## Test 7: Missing grant_type (400 Bad Request)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'client_id=demo'
```

Expected output (HTTP 400):
```json
{
  "error": "invalid_request",
  "error_description": "grant_type required"
}
```

## Test 8: Invalid Credentials for Client Credentials (401 Unauthorized)
```bash
curl -X POST http://localhost:8091/oauth2/token \
  -d 'grant_type=client_credentials&client_id=demo-client-id&client_secret=wrong'
```

Expected output (HTTP 401):
```json
{
  "error": "invalid_client",
  "error_description": ""
}
```

## Health Check
```bash
curl http://localhost:8091/health
```

Expected output:
```json
{"status":"UP"}
```

## Dispatch Behavior
1. **Request parsing:** Extract `grant_type`, `client_id`, `client_secret`, `username`, `password`, `scope`
2. **Validation:** `grant_type` is required
3. **Dispatch:** Iterate handlers in order; first match wins
4. **Handler flow:**
   - `CanHandle(grant_type)` → `ValidateGrant(req)` → `IssueToken(req)` or error
5. **Error handling:**
   - `invalid_client`: HTTP 401 (authentication failure)
   - Other errors: HTTP 400 (request error)
   - No handler matches: HTTP 400 with `unsupported_grant_type`

## Credentials for Testing
- **Client Credentials:** client_id=`demo-client-id`, secret=`demo-secret`
- **ROPC Users:** alice/pass123, bob/pass456
- **Device Code:** device_code=`device-abc` (passed in password field for simplicity)
