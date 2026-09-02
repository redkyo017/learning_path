# Day 4 teardown

## Delete the cluster

```bash
kind delete cluster --name awsdevops-day04
```

That's the entire teardown for today.

## Cost impact: $0.00

Nothing in this lab ever created an AWS resource — the cluster, Pods,
Deployment, and Service all lived inside local Docker containers on your
machine. Deleting the `kind` cluster (or just leaving your laptop off) costs
nothing either way.

## Prove `eks/` was never applied

`labs/day04/eks/` is authored reference Terraform for a future EKS path and
was never meant to be applied during this one (see the banner at the top of
`eks/README.md`). Confirm no EKS cluster exists in your account:

```bash
aws eks list-clusters
```

Expected output:

```json
{
    "clusters": []
}
```

If you see anything in that list with `awsdevops` in the name, something
went off-script — stop and investigate before continuing to Day 5;
`aws eks describe-cluster --name <name>` will show you what's running and
`aws eks delete-cluster --name <name>` (after deleting any node groups
first) will remove it. It was not supposed to exist.
