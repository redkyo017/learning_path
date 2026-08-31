# Lab Day 2 — Go Client Credentials Token Server

## Goal
Run a minimal Go OAuth2 server and issue a `client_credentials` token with `curl`.

## Prerequisites
- Go 1.22+
- `curl`

## Run
```bash
go run main.go
```

Server listens on `http://localhost:9443`.

## Test

### Issue a token
```bash
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&scope=read:api"
```

Expected response:
```json
{"access_token":"<random>","token_type":"Bearer","expires_in":3600,"scope":"read:api"}
```

### Invalid client — should return 401
```bash
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'bad-client:bad-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"
```

Expected response (HTTP 401):
```json
{"error":"invalid_client"}
```

### Wrong grant type — should return 400
```bash
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Authorization: Basic $(echo -n 'test-client:test-secret' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password"
```

Expected response (HTTP 400):
```json
{"error":"unsupported_grant_type"}
```

### Missing Authorization header — should return 401
```bash
curl -s -X POST http://localhost:9443/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"
```

Expected response (HTTP 401):
```json
{"error":"invalid_client"}
```

## Exercises
See `content/phase1/day02.md` §Exercises.

## Teardown
See `teardown.md`.
