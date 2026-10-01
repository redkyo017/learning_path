# Day 02 Lab — PAR Request Trace

**Goal:** Read the annotated PAR HTTP exchange and explain the security property enforced at each step.

**Success signal:** You can explain why each HTTP header, parameter, and response field exists in the PAR flow without referring to RFC 9126.

**Steps:**
1. Open `config/par_request.http` and read the annotated request/response pair.
2. For each annotated comment, verify you understand what would break if that element were missing.
3. Trace what happens if the `request_uri` expires before use.
4. Check your understanding against `SOLUTION.md`.
