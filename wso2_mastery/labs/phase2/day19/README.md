# Lab: Day 19 — Source Reading Exercise

## Task

This lab is a **source reading exercise**. You will examine the JWT validation implementation
in the WSO2 API Manager source code and answer specific questions about how tokens are validated.

## Objectives

- Locate `JWTValidatorImpl.java` in the WSO2 API Manager source
- Trace the `validateToken()` method and understand each validation step
- Identify WSO2's key rotation and caching strategy
- Extract subscription metadata from JWT claims

## Requirements

You will need:
- WSO2 API Manager 4.7.0 source code (or the compiled JAR)
- A text editor or IDE to search through Java files
- The ability to read Java code and trace method calls

## Steps

### Step 1: Locate JWTValidatorImpl.java

The WSO2 API Manager gateway uses a JWT validator to validate incoming tokens.

**Find**: `JWTValidatorImpl.java`

**Location hints**:
- If you have WSO2 AM source downloaded: search for `**/JWTValidatorImpl.java`
- If you're using the compiled JAR: extract the JAR and search inside

```bash
find . -name "JWTValidatorImpl.java"
# or
jar xf wso2am-universal-gw-4.7.0.jar && find . -name "JWTValidatorImpl.java"
```

### Step 2: Trace the validateToken Method

Open `JWTValidatorImpl.java` and find the `validateToken` method:

```java
public JWTValidationInfo validateToken(String token, RequestContext requestContext)
    throws JWTClientException
```

This is the entry point for JWT validation. Trace through this method and document:

1. **How does it extract the Bearer token?**
   - Does it parse the `Authorization` header directly?
   - Does it strip the `Bearer` prefix?

2. **How does it extract the `kid` from the JWT header?**
   - Does it decode the JWT header without verification?
   - Where does it read the `kid` claim?

3. **How does it fetch the public key?**
   - What is the JWKS endpoint URL?
   - Does it use an HTTP client library?
   - Is there caching logic?

4. **What happens if the `kid` is not found in the cached JWKS?**
   - Does it re-fetch immediately?
   - Does it use a fallback key?
   - Does it return an error?

### Step 3: Identify the JWKS Cache Strategy

Look for cache-related code in `JWTValidatorImpl.java` or in classes it depends on
(e.g., `JWKSCache`, `KeyCache`).

**Questions to answer:**

1. What is the cache key? (Is it the JWKS endpoint URL? The `kid`?)
2. What is the default cache TTL?
3. How does the cache handle key rotation?

Search for keywords like:
- `cache`
- `TTL`
- `expires`
- `getCache`
- `loadCache`

### Step 4: Identify Subscription Claims

Look for where `JWTValidatorImpl.java` extracts custom claims from the token.

**Search for**:
- `http://wso2.org/claims/subscriber`
- `http://wso2.org/claims/applicationname`
- `http://wso2.org/claims/applicationtier`
- `http://wso2.org/claims/version`
- `http://wso2.org/claims/keytype`

Document:
1. Which of these claims are extracted?
2. Where are they stored? (In a context object? A response object?)
3. What happens if a claim is missing?

### Step 5: Answer the Questions

Create a file `FINDINGS.txt` with your answers:

```
QUESTION 1: How does JWTValidatorImpl extract the Bearer token?
ANSWER: [Your answer based on code inspection]

QUESTION 2: What is the JWKS endpoint URL format?
ANSWER: [Your answer]

QUESTION 3: How does WSO2 handle key rotation (missing `kid` in cache)?
ANSWER: [Your answer]

QUESTION 4: Which subscription claims does WSO2 extract?
ANSWER: [Your answer]

QUESTION 5: What is the default cache TTL for JWKS responses?
ANSWER: [Your answer based on code inspection]

QUESTION 6: What happens if the JWKS endpoint is unreachable?
ANSWER: [Your answer: fail-closed or fail-open?]
```

## Tips

- Use your IDE's "Go to Definition" / "Go to References" feature to trace method calls
- Pay attention to exception handling — what errors are thrown on failure?
- Look for constants like `TOKEN_CACHE_TIMEOUT` or `JWKS_ENDPOINT`
- If you're unfamiliar with Java: `@Override` marks method overrides, `try-catch` handles
  exceptions, `synchronized` means thread-safe, `Cache` and `Map` are collections

## Expected Output

After completing this exercise, you should be able to explain:

1. The 7-step JWT validation process WSO2 uses
2. Why JWKS is cached and how cache invalidation works
3. How the gateway extracts subscription metadata from JWT claims
4. Why fail-closed semantics are critical for security

## Verifying Your Work

Compare your `FINDINGS.txt` with `SOLUTION.md` in this directory. Your answers should match
the documented validation steps.

