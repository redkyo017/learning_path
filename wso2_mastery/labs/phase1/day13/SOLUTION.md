# Day 13 Lab — SOLUTION

## The five OAuth2 debug logger lines

Copy these verbatim into `log4j2.properties` before the root logger:

```properties
logger.org-wso2-carbon-identity-oauth.name=org.wso2.carbon.identity.oauth
logger.org-wso2-carbon-identity-oauth.level=DEBUG
logger.org-wso2-carbon-identity-oauth2.name=org.wso2.carbon.identity.oauth2
logger.org-wso2-carbon-identity-oauth2.level=DEBUG
logger.org-wso2-carbon-identity-application-authentication.name=org.wso2.carbon.identity.application.authentication
logger.org-wso2-carbon-identity-application-authentication.level=DEBUG
```

And append to the `loggers =` list:

```properties
loggers = ..., org-wso2-carbon-identity-oauth, org-wso2-carbon-identity-oauth2, org-wso2-carbon-identity-application-authentication
```

---

## What each logger unlocks

| Logger key | Package | What you see at DEBUG |
|---|---|---|
| `org-wso2-carbon-identity-oauth` | `org.wso2.carbon.identity.oauth` | Client credential validation, grant type selection, OAuth client lookup |
| `org-wso2-carbon-identity-oauth2` | `org.wso2.carbon.identity.oauth2` | Token issuance, scope resolution, token persistence, introspection |
| `org-wso2-carbon-identity-application-authentication` | `org.wso2.carbon.identity.application.authentication` | Application-level auth context, pre-issue checks |

---

## Question answers

**Q1 — Package-level vs class-level logger**

Setting `org.wso2.carbon.identity.oauth2` to DEBUG enables DEBUG for every class
in that package and every sub-package.  This is a broad net — you see all token
issuance, introspection, revocation, and validation debug lines.

Setting `org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator` to DEBUG
enables only the debug lines from that one class.  You see token validation specifics
but miss issuance and client auth.

Use the broad package logger during initial diagnosis; narrow to the class once you
know which sub-system is the problem.

**Q2 — Forgot to add to the `loggers =` list**

The logger block is silently ignored.  Log4j2 only processes loggers whose keys
appear in the `loggers =` list.  No error is emitted; you simply do not see DEBUG lines.
This is the most common "why is DEBUG not working?" trap.

**Q3 — Restore INFO without restart**

Change `.level=DEBUG` to `.level=INFO` in each logger block:

```properties
logger.org-wso2-carbon-identity-oauth.level=INFO
logger.org-wso2-carbon-identity-oauth2.level=INFO
logger.org-wso2-carbon-identity-application-authentication.level=INFO
```

Save the file.  IS hot-reloads in up to 30 seconds.  The logger entries remain
registered — you can flip back to DEBUG instantly next time.
