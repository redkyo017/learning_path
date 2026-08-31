# WSO2 Mastery — Top 1% Strategy

## Strategy (the unconventional top-1% approach)

**The trap beginners fall into:** They read WSO2 documentation (which describes what
the product does) instead of reading source code (which reveals why it works that way).
They spend weeks learning the admin UI before understanding the engine. They treat WSO2
as a black box and get permanently stuck at "it's not working, check the logs."

**The top-1% move:** Work backwards from the protocols. OAuth2/OIDC (RFC 6749/7519/7662),
JWT, JMS/AMQP, and HTTP are language-agnostic. WSO2 IS is an OAuth2 server written in Java
on OSGi — but the *protocol* is the same whether it's Java or Go. By porting the critical
path to Go, you're forced to understand every decision WSO2 made, because you have to
make the same decisions yourself. You don't need to understand OSGi bundles; you need to
understand the token endpoint contract.

**Mistakes that waste 80% of beginners' time:**
1. Reading the OSGi bundle loader and Carbon kernel before touching the actual feature code.
2. Starting with admin REST APIs instead of the core token/mediation engine.
3. Skipping log4j2 config — half of debugging WSO2 is knowing which logger to turn on.
4. Trying to run a full WSO2 stack locally before understanding what each process does.
5. Conflating WSO2 IS (identity provider, key manager) with WSO2 APIM (gateway + lifecycle).
   They share a codebase history but serve completely different runtime roles.

**The daily loop (every day of the plan):**
1. Read 1-2 WSO2 source files related to the day's topic (use the checked-out repos).
2. Build the Go equivalent — even a 50-line stub that handles the same contract.
3. Test it against the WSO2 spec (JWT claims, HTTP response shapes, error codes).
4. Write one paragraph in a personal "why" log: why did WSO2 make this design choice?

---

## The Daily Loop (do this every single day)
1. Open the WSO2 source file named in the day's "WSO2 source reading" section.
2. Read 50–100 lines. Ask: what problem is this solving?
3. Build the Go equivalent — even 30 lines that handle the same HTTP contract.
4. Test it: `curl` or a Go test against your server.
5. Write one sentence in a personal "why" log: why did WSO2 make this design choice?
