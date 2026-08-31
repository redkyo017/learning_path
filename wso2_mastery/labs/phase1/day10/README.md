# Day 10 Lab — Reading KeyManagerInterface.java

## Goal

Locate the `KeyManagerInterface` in the WSO2 APIM source tree, list every
method it declares, and map each method to the REST endpoint table in
`content/phase1/day10.md`.

This is a **source-reading exercise** — no new Go code.

---

## Prerequisites

- Git clone of the WSO2 APIM ACP (API Control Plane) source:
  ```
  https://github.com/wso2/apim-apps   (frontend)
  https://github.com/wso2/carbon-apimgt  (backend — contains KeyManagerInterface)
  ```
- You can browse the interface online without cloning:
  ```
  https://github.com/wso2/carbon-apimgt/blob/master/components/apimgt/org.wso2.carbon.apimgt.api/src/main/java/org/wso2/carbon/apimgt/api/model/KeyManager.java
  ```

---

## Tasks

### Task 1 — Locate the interface

In a local clone:

```bash
find . -name "KeyManager.java" | head -5
```

Expected path:

```
components/apimgt/org.wso2.carbon.apimgt.api/src/main/java/
  org/wso2/carbon/apimgt/api/model/KeyManager.java
```

Note: the interface is called `KeyManager` (not `KeyManagerInterface`) in the
source code.  `KeyManagerInterface` is how WSO2 documentation refers to it.

### Task 2 — List all method signatures

Open the file and extract every `public` method signature.  Focus on:

- `registerApplication`
- `updateApplication`
- `deleteApplication`
- `generateApplicationKeys`
- `getNewApplicationAccessToken`
- `getTokenMetaData`
- `introspectToken`
- `revokeAccessToken`
- `getJWKS`
- `getKeyManagerConfiguration`

### Task 3 — Map methods to REST endpoints

Complete the mapping table:

| Java method | HTTP method | Path (from day10.md) |
|-------------|-------------|----------------------|
| `registerApplication` | | |
| `deleteApplication` | | |
| `generateApplicationKeys` / `getNewApplicationAccessToken` | | |
| `getTokenMetaData` / `introspectToken` | | |
| `revokeAccessToken` | | |
| `getJWKS` | | |
| *(userinfo — no direct Java method; provided by OIDC layer)* | GET | `/oauth2/userinfo` |

Fill in the HTTP method and path for each row.

### Task 4 — Identify the connector class

Search for `KeyManagerConnector` in the same source tree:

```bash
grep -r "KeyManagerConnector" --include="*.java" -l
```

Open the file and note:
- Which REST client it uses to call the external Key Manager.
- How it constructs the endpoint URL (is the base URL configurable?).

### Task 5 — Reflection questions

Answer in your notes:

1. Does `KeyManager.java` contain any HTTP code, or is it a pure Java interface?
2. Which class provides the default implementation (the one that calls WSO2 IS)?
3. What would you need to write to make a *Java* Key Manager plugin rather than
   a REST-based one?

---

## Expected Findings

After completing the tasks you should have:

- A complete table of Java method → HTTP method + path (7 rows).
- The name of the class that implements `KeyManager` for WSO2 IS (hint: search
  for `implements KeyManager` in the source).
- An understanding that your Go service implements the *HTTP contract* that
  `KeyManagerConnector` calls, not the Java interface directly.

---

## Hint

The interface file is in `org.wso2.carbon.apimgt.api` — the pure API module
with no implementation.  The REST connector that calls your Go service is in
`org.wso2.carbon.apimgt.impl`.  The split mirrors the interface/implementation
pattern you use in Go (interface type vs concrete struct).
