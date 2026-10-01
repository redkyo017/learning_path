# Day 03 Lab — RAR Authorization Details Trace

**Goal:** Write valid `authorization_details` for two banking scenarios and trace how the values flow from the PAR request to the resource server enforcement check.

**Success signal:** You can write `authorization_details` for a payment initiation and an account information request from memory, and explain how a resource server uses each field.

**Steps:**
1. Open `config/authorization_details.json` — two annotated examples.
2. For each field, note: (a) which party writes it, (b) which party reads it, (c) what happens if the field is missing or wrong.
3. Write a third `authorization_details` object for a standing order (recurring payment) of €50/month. See `SOLUTION.md` for one possible answer.
