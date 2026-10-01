# Day 12 Lab — Solution

## Scenario trace

### Scenario 1: Regular user, known IP, no special role
- Step 1 executes → succeeds
- `isMemberOfRole('payment-approvers')` → false → skip rule 1
- `isFraudFlagged` → not 'true' → skip rule 2
- `context.request.ip === lastKnownIP` → true (known IP) → skip rule 3
- **Result: Step 1 only. User authenticates with username/password.**

### Scenario 2: User in `payment-approvers`, known IP
- Step 1 executes → succeeds
- `isMemberOfRole('payment-approvers')` → true → executeStep(2) for TOTP
- `return` prevents rule 2 and rule 3 from evaluating
- **Result: Steps 1 + 2 (Basic + TOTP). IP is irrelevant for this role.**

### Scenario 3: Regular user, new IP
- Step 1 executes → succeeds
- `isMemberOfRole('payment-approvers')` → false
- `isFraudFlagged` → not 'true'
- `context.request.ip !== lastKnownIP` → true (new IP) → executeStep(3) for Email OTP
- **Result: Steps 1 + 3 (Basic + Email OTP).**

### Scenario 4: User with `isFraudFlagged: true`
- Step 1 executes → succeeds (credentials are valid)
- `isMemberOfRole('payment-approvers')` → false
- `isFraudFlagged === 'true'` → true → `fail({errorCode: 'ACCOUNT_BLOCKED'})` called
- **Result: Authentication denied. Access token never issued.**

## What `return` does in scenario 2
Without `return` after rule 1, the script would continue to rules 2 and 3.
For a payment-approver on a new IP, both TOTP (rule 1) and Email OTP (rule 3) would trigger,
adding an unnecessary third factor. The `return` ensures mutually exclusive rule evaluation.
