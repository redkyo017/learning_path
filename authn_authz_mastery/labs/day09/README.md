# Lab Day 09 — SCA: Step-Up Authentication

## Goal

Trace a complete step-up authentication flow: a user session with a normal-strength token attempts a high-value payment to a new payee, triggering an SCA challenge. Follow the HTTP exchange from the initial 401 to the final payment authorisation.

## What you will practise

- Reading the `WWW-Authenticate` challenge response and understanding each parameter
- Constructing the OIDC step-up authorization request (`acr_values`, `max_age`, `prompt`)
- Understanding how dynamic linking binds the authentication to the specific payment
- Comparing the initial access token claims against the step-up token claims

## Files

| File | Purpose |
|---|---|
| `config/sca_step_up_flow.http` | Annotated HTTP exchange for the full step-up flow |
| `diagram.md` | Mermaid sequence diagram of the step-up flow |
| `SOLUTION.md` | Explanation of each HTTP response, step-up trigger, and dynamic linking mechanism |

## Exercise

1. Open `config/sca_step_up_flow.http`. For each HTTP request/response pair, answer:
   - What is the state of the user's authentication at this point?
   - What does the bank check to produce this response?

2. The first payment attempt returns a 401. Identify the three parameters in the `WWW-Authenticate` header and explain what each instructs the client to do.

3. In the step-up authorization request, `max_age=0` is set. What does this mean and why is it required?

4. The step-up access token has a different `acr` claim than the initial token. What value does the initial token carry and what value does the step-up token carry? Why does the resource server check this claim?

5. Explain dynamic linking in your own words using the payment amounts and payee IBAN in the HTTP file as concrete examples.

## Success signal

You can identify the SCA trigger, the factors used, the dynamic linking mechanism, and the difference between the initial and step-up access tokens without referring to the solution, and you can explain what a fraudster cannot do even if they intercept the step-up authentication code.
