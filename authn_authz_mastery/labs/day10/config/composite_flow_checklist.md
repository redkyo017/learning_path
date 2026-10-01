# Phase 1 Composite Flow Checklist

Complete this checklist from memory. For each security property, identify which protocol provides it and which Phase 1 day covered it. Do not refer to Days 01–09 until you have attempted every row.

After completing the checklist, check your answers in `../SOLUTION.md`.

---

| Security Property | Protocol | Day covered |
|------------------|----------|-------------|
| Authorization request parameters off the front channel | ? | ? |
| Fine-grained authorization data (payment amount, payee) | ? | ? |
| Client authentication without shared secrets | ? | ? |
| Auth response tamper protection | ? | ? |
| Authorization code interception protection | ? | ? |
| Token binding to client key (application layer) | ? | ? |
| Token binding to TLS certificate (transport layer) | ? | ? |
| Headless authentication (no browser) | ? | ? |
| Transaction binding (dynamic linking) | ? | ? |
| User provisioning and deprovisioning | ? | ? |
| Consent lifecycle management | ? | ? |
| SCA factor requirements | ? | ? |

---

## Stretch question

Describe the data dependency between PAR and the consent record. What specific field is passed from one to the other, and what breaks if it is not?

Your answer:

---

## Reflection

Which protocol interaction surprised you most? Which handoff point is most likely to be implemented incorrectly in a real system? Note your thoughts here before checking the solution.

Your answer:
