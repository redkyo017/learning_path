pod-identity-trust.json: the trust policy for EVERY EKS Pod Identity role (no cluster name, no OIDC issuer, no account ID in it).
The AWS Load Balancer Controller permissions policy is NOT stored here: download the iam_policy.json of the controller
release you install (labs/eks/README.md Step 5), so the policy and the controller version match.
