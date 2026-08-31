# Day 11 — Application Registration: Request/Response & In-Memory Registry

## Why Application Registration Matters

When a developer subscribes their app to an API, APIM needs an OAuth 2.0
client on the Key Manager side so it can issue tokens scoped to that app.
It cannot create that client by itself — it has to ask the Key Manager.

The call is `POST /api/am/keymanager/v1/keymanager/application`.
Your Key Manager creates the client, returns its credentials, and APIM stores
the mapping in `AM_APPLICATION_KEY_MAPPING`.

---

## Request and Response Shapes

### Register Application

**Request**

```json
POST /api/am/keymanager/v1/keymanager/application
Content-Type: application/json

{
  "applicationName": "MyApp",
  "grantTypes": ["client_credentials"],
  "callbackUrl": ""
}
```

| Field | Type | Description |
|-------|------|-------------|
| `applicationName` | string | APIM application name; becomes the OAuth client name |
| `grantTypes` | string[] | Grant types the client may use |
| `callbackUrl` | string | Redirect URI; empty for `client_credentials` apps |

**Response (201 Created)**

```json
{
  "clientId": "dGVzdC1jbGllbnQ",
  "clientSecret": "c2VjcmV0LXZhbHVl",
  "clientName": "MyApp",
  "grantTypes": ["client_credentials"],
  "callbackUrl": ""
}
```

The Key Manager generates `clientId` and `clientSecret`.  APIM stores them
and returns them to the developer portal; the developer never sees them
being created.

### Delete Application

```
DELETE /api/am/keymanager/v1/keymanager/application/{clientId}
```

No request body.  Returns **204 No Content** on success.

---

## The AM_APPLICATION_KEY_MAPPING Table

APIM's database holds one row per (application, key manager) pair:

```
APPLICATION_ID  |  CONSUMER_KEY (= clientId)  |  KEY_MANAGER
────────────────┼─────────────────────────────┼──────────────
42              │  dGVzdC1jbGllbnQ             │  MyGoKM
```

When the gateway receives a token, it reads the `consumer_key` claim (or
derives it from the subscription), looks up this table, and knows *which*
Key Manager to call for introspection.

Without this mapping, the gateway would not know whether to call WSO2 IS,
your Go service, or Keycloak.

---

## In-Memory Client Registry Pattern

Production Key Managers persist clients in a database.  For a learning
implementation we use `sync.Map` — a concurrent-safe Go map.

```go
type ClientRecord struct {
    ClientID     string   `json:"clientId"`
    ClientSecret string   `json:"clientSecret"`
    ClientName   string   `json:"clientName"`
    GrantTypes   []string `json:"grantTypes"`
    CallbackURL  string   `json:"callbackUrl"`
}

var clientRegistry sync.Map // key: clientID → value: ClientRecord
```

### Register (POST)

```go
func registerApplicationHandler(w http.ResponseWriter, r *http.Request) {
    var req struct {
        ApplicationName string   `json:"applicationName"`
        GrantTypes      []string `json:"grantTypes"`
        CallbackURL     string   `json:"callbackUrl"`
    }
    json.NewDecoder(r.Body).Decode(&req)

    clientID := generateID()     // 22-char base64url random string
    clientSecret := generateID()
    rec := ClientRecord{
        ClientID: clientID, ClientSecret: clientSecret,
        ClientName: req.ApplicationName,
        GrantTypes: req.GrantTypes, CallbackURL: req.CallbackURL,
    }
    clientRegistry.Store(clientID, rec)
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(rec)
}
```

### Delete (DELETE)

```go
import "path"

func deleteApplicationHandler(w http.ResponseWriter, r *http.Request) {
    clientID := path.Base(r.URL.Path) // extract last path segment
    clientRegistry.Delete(clientID)
    w.WriteHeader(http.StatusNoContent)
}
```

`path.Base("/api/am/keymanager/v1/keymanager/application/abc123")` returns
`"abc123"`.  This avoids manual string splitting.

---

## Token Handler — Client Lookup from Registry

Once clients are registered dynamically, the token handler must validate
credentials against `clientRegistry`, not a hardcoded map:

```go
func validateClient(id, secret string) bool {
    v, ok := clientRegistry.Load(id)
    if !ok {
        return false
    }
    rec := v.(ClientRecord)
    return rec.ClientSecret == secret
}
```

Static clients (e.g. `"test-client"`) can remain as a fallback during
development; production removes them.

---

## Practical Checkpoint

1. What HTTP status does a successful application registration return?  Why
   not 200?
2. What does `path.Base` return for
   `/api/am/keymanager/v1/keymanager/application/abc123`?
3. Why does the Key Manager need to validate the caller's credentials on the
   `introspect` and `revoke` endpoints, but *not* on `registerApplication`?
   (APIM calls registration over a trusted internal network; introspect is
   called per-request by the gateway and must authenticate to prevent probing.)

---

## Lab (Day 11)

See `labs/phase1/day11/keymanager/` — a self-contained Go server implementing
all Key Manager endpoints including the client registry.

---

## Exercises

**Exercise 1 — Registration round-trip**

Write the two curl commands to:
(a) Register a new app called `"BillingService"` with `client_credentials` grant.
(b) Delete it using the `clientId` returned from step (a).

**Hint:** Use the response body from (a) to get the `clientId` for (b).

**Solution sketch:**
```bash
# (a) Register
curl -s -X POST http://localhost:9444/api/am/keymanager/v1/keymanager/application \
  -H "Content-Type: application/json" \
  -d '{"applicationName":"BillingService","grantTypes":["client_credentials"],"callbackUrl":""}' \
  | tee /tmp/app.json

CLIENT_ID=$(jq -r .clientId /tmp/app.json)

# (b) Delete
curl -s -X DELETE \
  "http://localhost:9444/api/am/keymanager/v1/keymanager/application/${CLIENT_ID}" \
  -w "%{http_code}"
# expected: 204
```

**Exercise 2 — Token with dynamic client**

After registering an app, use its `clientId` and `clientSecret` to obtain
an access token via the `client_credentials` grant.

**Hint:** The token endpoint accepts HTTP Basic Auth where username = clientId
and password = clientSecret.

**Solution sketch:**
```bash
CLIENT_SECRET=$(jq -r .clientSecret /tmp/app.json)

curl -s -X POST http://localhost:9444/api/am/keymanager/v1/oauth2/token \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" \
  | jq .access_token
```

**Exercise 3 — path.Base**

Without running Go, what does `path.Base` return for each of these inputs?

```
/api/am/keymanager/v1/keymanager/application/xyz789
/keymanager/application/
/keymanager/application
```

**Hint:** `path.Base` returns the last non-empty element.  A trailing slash
makes the last element empty.

**Solution sketch:**
```
"xyz789"       → last segment
"application"  → trailing slash consumed, last segment is "application"
"application"  → same
```

The second and third cases mean APIM must *not* append a trailing slash.
In practice it does not; the DELETE request always looks like `.../application/{id}`.
