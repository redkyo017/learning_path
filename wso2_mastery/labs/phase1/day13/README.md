# Day 13 Lab — Reading log4j2.properties in WSO2 IS

## Goal

This is a source-reading lab.  No code to write, no servers to start.  You will:

1. Locate `log4j2.properties` in the WSO2 IS checkout or Docker image.
2. Identify which loggers are active and at what levels.
3. Add the five OAuth2 debug loggers.
4. Explain what changes when INFO is switched to DEBUG.

---

## Prerequisites

- WSO2 IS running in Docker (from Day 5/6) **or** the IS zip extracted locally.
- If using Docker: `docker exec <is-container> bash` gives you a shell.

---

## Task 1 — Find the config file

**In Docker:**

```bash
docker exec <is-container> cat /home/wso2carbon/wso2is-7.3.0/repository/conf/log4j2.properties | head -50
```

**In a local extraction:**

```bash
cat wso2is-7.3.0/repository/conf/log4j2.properties | head -50
```

Answer: what is the default level of the root logger?

---

## Task 2 — Identify the OAuth2 loggers

Scan the file for any existing logger entries that mention `oauth`:

```bash
grep -i oauth wso2is-7.3.0/repository/conf/log4j2.properties
```

Are there any OAuth2-specific loggers already defined?  What levels are they at?

---

## Task 3 — Add the five debug loggers

Edit `log4j2.properties` and add the following block **before** the root logger line:

```properties
logger.org-wso2-carbon-identity-oauth.name=org.wso2.carbon.identity.oauth
logger.org-wso2-carbon-identity-oauth.level=DEBUG
logger.org-wso2-carbon-identity-oauth2.name=org.wso2.carbon.identity.oauth2
logger.org-wso2-carbon-identity-oauth2.level=DEBUG
logger.org-wso2-carbon-identity-application-authentication.name=org.wso2.carbon.identity.application.authentication
logger.org-wso2-carbon-identity-application-authentication.level=DEBUG
```

Then find the `loggers =` line and append the three new keys:

```properties
loggers = ..., org-wso2-carbon-identity-oauth, org-wso2-carbon-identity-oauth2, org-wso2-carbon-identity-application-authentication
```

---

## Task 4 — Observe hot-reload

If IS is running, save the file and wait 30 seconds.  Then issue a token request:

```bash
curl -k -X POST https://localhost:9443/oauth2/token \
  -u "<clientId>:<clientSecret>" \
  -d "grant_type=client_credentials"
```

Watch the IS logs:

```bash
docker logs -f <is-container> 2>&1 | grep DEBUG | head -20
```

You should see DEBUG lines from `org.wso2.carbon.identity.oauth2.*`.

---

## Questions

1. What is the difference between setting `org.wso2.carbon.identity.oauth2` to DEBUG
   vs setting `org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator` to DEBUG?

2. What happens if you add the logger block but forget to add the keys to the `loggers =` list?

3. After diagnosing your issue, how do you restore INFO-level logging without restarting IS?

See `SOLUTION.md` for answers.
