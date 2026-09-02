> **DO NOT `terraform apply` THIS DIRECTORY DURING THIS PATH.**
>
> It costs **~$0.10/hour (~$73/month) for the EKS control plane alone**,
> before a single node or NAT gateway is added — and this path's Day 4 runs
> entirely on a free local `kind` cluster instead (see
> `../kind-cluster.yaml` and `../README.md`). This directory exists so a
> future dedicated EKS path has correct, readable Terraform to start from —
> not as a step in this lab.
>
> If you run `terraform init` here out of curiosity, that's fine (it only
> downloads providers). Do not run `terraform apply`.

## What this is

A minimal, readable reference EKS stack:

- `aws_eks_cluster` — the control plane, reading the `foundation` stack's
  public subnets via the same `terraform_remote_state` block every other
  day lab in this path uses.
- A managed node group (`aws_eks_node_group`) with its own node IAM role —
  the ECS "execution role" analog from `content/day04.md`'s mapping table.
- `aws_iam_openid_connect_provider` for the cluster's own OIDC issuer — the
  prerequisite for IRSA.
- A worked **IRSA** example: an `aws_iam_role` whose trust policy grants
  `sts:AssumeRoleWithWebIdentity` to a specific Kubernetes ServiceAccount
  (`system:serviceaccount:default:awsdevops-sample`), attached to a scoped
  (read-only ECR) permission. Read the comment directly above
  `resource "aws_iam_role" "irsa_sample_app"` in `main.tf` — it points back
  at Day 2's GitHub Actions OIDC trust policy and spells out why the two are
  the same mechanism with a different issuer.

## Why it's never applied here

This path's cost target for the whole week is $3–8 (see the top-level
`COST.md`). A single EKS control plane left running for a week would blow
past that on its own, before counting nodes. Day 4 gets you conversant in
the same K8s objects and the same IRSA trust-policy shape using `kind`,
which is $0 and takes seconds to create and destroy — see
`../kind-cluster.yaml` and `../teardown.md`.

## If a future EKS path picks this up

This file would need, at minimum: a `terraform.tfvars.example` (none is
shipped here on purpose, to keep this directory inert), a real value swapped
in for the `<OIDC_ISSUER>` placeholder in `main.tf`'s IRSA trust policy
(that placeholder becomes `aws_iam_openid_connect_provider.eks.url` with its
`https://` prefix stripped, once the provider actually exists), and a
decision about `endpoint_public_access` for a non-learning environment.
None of that is done here deliberately — this file is a starting point, not
a finished stack.
