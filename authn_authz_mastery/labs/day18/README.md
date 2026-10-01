# Day 18 Lab — RAR + Consent Portal

## Goal

Trace the RAR consent flow from PAR request through consent record storage, selective revocation,
and the follow-up refresh token rejection. The annotated HTTP exchange walks through IS 7.3's consent
management API end to end.

## Success signal

You can answer all of the following without notes:
- Where does IS 7.3 store consent records after a user approves in the consent portal?
- What happens to existing access tokens immediately after consent revocation?
- How does the consent portal receive `authorization_details` — which parameter, in which request?
- What `error` code does IS 7.3 return when a refresh token's underlying consent is revoked?

## Steps

1. Open `config/consent_api.http`.
2. Read each annotated block in sequence. For each comment marked `# QUESTION:`, write your answer
   before reading the next block.
3. Complete the stretch exercise after working through all blocks.
4. Check your answers against `SOLUTION.md`.

## Stretch exercise

A TPP holds an access token (expires in 5 minutes) and a refresh token, both issued when the user
consented to `payment_initiation`. The user revokes the consent. The TPP's access token has
2 minutes left.

Without looking at `day18.md`, answer:
1. Can the TPP still use the access token for the next 2 minutes? Why or why not?
2. What happens when the 2 minutes expire and the TPP tries to refresh?
3. What design decision for payment tokens does this reveal?

## Files

| File | Purpose |
|------|---------|
| `README.md` | This file — lab instructions |
| `diagram.md` | Mermaid sequence: PAR → consent portal → approval → token → revocation → refresh rejected |
| `config/consent_api.http` | Annotated consent management API HTTP exchange |
| `SOLUTION.md` | Answers to all questions and stretch exercise |
