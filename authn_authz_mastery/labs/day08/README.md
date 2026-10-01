# Lab Day 08 — Consent Management

## Goal

Annotate a PSD2 consent object field by field and trace its status transitions through a complete lifecycle: creation → authorisation → ongoing use → expiry and revocation.

## What you will practise

- Reading a PSD2 consent object and explaining each field's purpose
- Mapping consent lifecycle transitions to the events that trigger them
- Understanding what immediate action the bank must take at each transition
- Linking consent revocation to token invalidation

## Files

| File | Purpose |
|---|---|
| `config/consent_object.json` | Full annotated PSD2 AIS consent JSON |
| `diagram.md` | Mermaid state diagram of consent lifecycle |
| `SOLUTION.md` | Field-by-field explanation, state machine in ASCII, token revocation walkthrough |

## Exercise

1. Open `config/consent_object.json`. For each top-level field, write one sentence explaining:
   - What it stores
   - Why it is required for PSD2 compliance

2. The consent has `recurringIndicator: true` and `validUntil` set. Calculate the maximum number of days the bank may set `validUntil` relative to the creation date. What PSD2 article governs this?

3. The consent is currently `valid`. The user calls the bank to revoke TPP access. Walk through the state machine in `diagram.md`:
   - What is the next status?
   - What triggers the transition?
   - What must the bank do immediately after the status changes?

4. Three months after the consent was created, the `validUntil` date passes. What happens to the consent status and to any outstanding access tokens?

5. Design a token revocation procedure using the `linkedTokenJtis` field in the consent object. Write pseudocode for the revocation function.

## Success signal

You can draw the consent state machine from memory — all six states and all five transitions with their triggers — and explain the immediate bank action at each transition without referring to the diagram.
