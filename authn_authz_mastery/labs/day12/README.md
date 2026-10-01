# Day 12 Lab — Adaptive Auth Script Analysis

**Goal:** Read the adaptive auth script in `config/adaptive_auth_script.js` and predict which
authentication steps execute for four user scenarios.

**Success signal:** You can trace the JavaScript execution path for each scenario and identify
which `executeStep()` calls fire, without running the script.

**Scenarios to trace:**
1. Regular user, known IP, no special role
2. User in `payment-approvers` role, known IP
3. Regular user, new IP address (first login from this IP)
4. User with `isFraudFlagged: true` claim

**Steps:**
1. Read `config/adaptive_auth_script.js` carefully.
2. For each scenario, trace which `executeStep()` calls execute and why.
3. Check your predictions against `SOLUTION.md`.
