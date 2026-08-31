# Day 11 Lab — Key Manager: Client Registration

## What this lab builds

A self-contained Go server that implements the full WSO2 3rd-party Key Manager
REST interface.  After this lab you can point a real WSO2 APIM instance at
this server as its Key Manager.

## Setup

```bash
cd labs/phase1/day11/keymanager
go mod init keymanager
go get github.com/golang-jwt/jwt/v5
```

## Run

```bash
go run main.go
# Key Manager listening on :9444
```

## Exercise

`deleteApplicationHandler` is intentionally incomplete — see the `// TODO`
comment in `main.go`.  Complete it before running the curl workflow below.

## Curl workflow

### 1. Health check

```bash
curl http://localhost:9444/health
# {"status":"UP"}
```

### 2. Register an application

```bash
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/keymanager/application \
  -H "Content-Type: application/json" \
  -d '{"applicationName":"MyApp","grantTypes":["client_credentials"],"callbackUrl":""}' \
  | tee /tmp/km_app.json | jq .
```

Expected response (201 Created):

```json
{
  "clientId": "dGVzdC1jbGllbnQ",
  "clientSecret": "c2VjcmV0LXZhbHVl",
  "clientName": "MyApp",
  "grantTypes": ["client_credentials"],
  "callbackUrl": ""
}
```

### 3. Issue an access token using the returned credentials

```bash
CLIENT_ID=$(jq -r .clientId /tmp/km_app.json)
CLIENT_SECRET=$(jq -r .clientSecret /tmp/km_app.json)

curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" \
  | tee /tmp/km_token.json | jq .
```

### 4. Introspect the token

```bash
TOKEN=$(jq -r .access_token /tmp/km_token.json)

curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/introspect \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "token=${TOKEN}" | jq .active
# true
```

### 5. Delete the application

```bash
curl -s -X DELETE \
  "http://localhost:9444/api/am/keymanager/v1/keymanager/application/${CLIENT_ID}" \
  -w "HTTP %{http_code}\n"
# HTTP 204
```

### 6. Confirm token is now invalid (client no longer validates)

```bash
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/introspect \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "token=${TOKEN}"
# HTTP 401 — client credentials no longer valid after deletion
```

## JWKS

```bash
curl http://localhost:9444/api/am/keymanager/v1/jwks | jq .
```

## What to observe

- The `clientId` and `clientSecret` are random 22-character base64url strings.
- After deletion, the dynamic client can no longer authenticate (the static
  `test-client` fallback still works for smoke-testing).
- The JWKS endpoint returns the public key that APIM would cache to validate
  JWTs locally.
