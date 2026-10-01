# Day 17 Lab — FIDO2 / Passkeys

## Goal

Trace the FIDO2 registration and assertion HTTP exchanges in IS 7.3, identifying the role of each
field. By working through the annotated HTTP exchange, you will understand what the server issues,
what the authenticator signs, and what IS 7.3 verifies — without needing to read the WebAuthn spec.

## Success signal

You can answer all of the following without notes:
- What does the `challenge` in the registration start response prevent?
- Why does `userVerification: required` appear in both the start request and the authenticator response?
- What does IS 7.3 store after a successful registration?
- How does IS 7.3 use the stored data during assertion?

## Steps

1. Open `config/fido2_registration.http`.
2. Read each annotated block. For each comment marked `# QUESTION:`, write your answer before reading
   the next block.
3. After completing the registration ceremony trace, repeat for the assertion ceremony.
4. Check your understanding against `SOLUTION.md`.

## Stretch exercise

A bank wants to allow passwordless login for their mobile banking app using passkeys (resident keys).
Without referring to `day17.md`, describe:
1. What change to the registration start request enables resident key storage on the authenticator?
2. What changes to the assertion start request allow the user to authenticate without providing a username?

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — lab instructions |
| `diagram.md` | Mermaid sequence diagrams for registration and assertion ceremonies |
| `config/fido2_registration.http` | Annotated FIDO2 registration + assertion HTTP exchange |
| `SOLUTION.md` | Answer guide for all questions and stretch exercise |
