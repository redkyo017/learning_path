# Day 11 Solution — deleteApplicationHandler

## The Exercise

`deleteApplicationHandler` in `main.go` has a `// TODO` block:

```go
// TODO: extract clientID from r.URL.Path using path.Base
//       then call clientRegistry.Delete(clientID)
```

## Complete Implementation

Replace the `// TODO` comment with these two lines:

```go
clientID := path.Base(r.URL.Path)
clientRegistry.Delete(clientID)
```

### Why path.Base?

`path.Base` returns the last element of a path after the final `/`:

```
Input:  /api/am/keymanager/v1/keymanager/application/dGVzdC1jbGllbnQ
Output: dGVzdC1jbGllbnQ
```

This avoids manual string splitting and handles edge cases (trailing slashes,
multiple segments) correctly.

### Full deleteApplicationHandler

```go
func deleteApplicationHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodDelete {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }
    clientID := path.Base(r.URL.Path)
    clientRegistry.Delete(clientID)
    w.WriteHeader(http.StatusNoContent)
}
```

After this change, the `var _ = path.Base` guard at the bottom of `main.go`
is redundant (the import is now genuinely used) but harmless — you can remove it.

## Verification

```bash
# Register an app
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/keymanager/application \
  -H "Content-Type: application/json" \
  -d '{"applicationName":"Test","grantTypes":["client_credentials"],"callbackUrl":""}' \
  | tee /tmp/app.json

CLIENT_ID=$(jq -r .clientId /tmp/app.json)

# Delete it
curl -s -X DELETE \
  "http://localhost:9444/api/am/keymanager/v1/keymanager/application/${CLIENT_ID}" \
  -w "HTTP %{http_code}\n"
# HTTP 204

# Confirm the client no longer authenticates
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "${CLIENT_ID}:$(jq -r .clientSecret /tmp/app.json)" \
  -d "grant_type=client_credentials"
# {"error":"invalid_client"}
```
