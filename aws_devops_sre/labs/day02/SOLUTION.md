# Day 2 lab — solution notes

## The correct GitHub Actions OIDC trust policy, in full

This is what `aws_iam_role.gha_oidc` in `oidc.tf` renders, with placeholder
values filled in for a repo `octocat/awsdevops-sample` on branch `main`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:octocat/awsdevops-sample:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Two things have to be true simultaneously for STS to hand out credentials:

1. **`:aud` equals `sts.amazonaws.com`** — proves the token was minted
   specifically to be presented to AWS STS, not some other relying party
   that happens to trust GitHub's OIDC issuer.
2. **`:sub` equals `repo:octocat/awsdevops-sample:ref:refs/heads/main`
   exactly** — proves the token came from a workflow run triggered by a
   push to that exact branch of that exact repo. Not a pull request run.
   Not a different branch. Not a different repo, even one owned by the same
   account.

`StringEquals` is what makes both of those exact-match checks — the whole
policy is void of protection if either condition is swapped for
`StringLike` with a wildcard.

## The blast radius of the wildcard version (the Break-it exercise)

Trust condition under test:

```json
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:octocat/awsdevops-sample:*"
  }
}
```

`sub` for a GitHub Actions token isn't only `repo:OWNER/REPO:ref:refs/heads/BRANCH`
— GitHub mints it in several other forms depending on what triggered the
run, including (among others):

- `repo:OWNER/REPO:ref:refs/heads/<any-branch>` — any branch, not just `main`.
- `repo:OWNER/REPO:pull_request` — a run triggered by a pull request event.
- `repo:OWNER/REPO:ref:refs/tags/<any-tag>` — any tag push.
- `repo:OWNER/REPO:environment:<name>` — a run deployed against a named
  GitHub Environment.

The trailing `*` in `repo:OWNER/REPO:*` matches **all of the above**, not
just "other branches." Enumerated:

1. **Any branch, created by anyone with push access to the repo** (which,
   depending on the repo's settings, can include outside collaborators)
   can trigger a workflow whose token satisfies this condition and assumes
   the role — no review of that branch's workflow file required before the
   token is issued.
2. **Any pull-request-triggered workflow run** — including, depending on
   the repo's "Fork pull request workflows" setting, a workflow modified by
   a contributor's fork — can potentially match `repo:OWNER/REPO:*` and
   assume the role, if the repo is configured to grant `id-token: write` to
   fork-triggered `pull_request` runs (the safer GitHub default restricts
   this, but it's a setting, not a guarantee, and it's easy to have loosened
   for other reasons).
3. **Whatever the role's permissions policy grants becomes reachable from
   any of the above** — in this lab, that's push access to the foundation
   ECR repository. A malicious or compromised branch/PR workflow could push
   an arbitrary image under a tag, which is dangerous specifically because
   Day 2's whole point is that downstream stages should promote by digest,
   not tag — but a careless deploy stage that does resolve by tag would
   ship that image.

**One-sentence answer:** the wildcard `sub` condition grants any branch,
pull request, or tag-triggered workflow in the repo — not just `main` — the
ability to assume a role that can push arbitrary images to the foundation
ECR repository.

**Why the lab says "reason about, do not perform":** actually opening a
fork PR to test this would (a) require configuring the repo's fork-PR
`id-token` permission in a way that's a bad default to leave enabled even
temporarily, (b) potentially push a real image under a real tag to your
foundation ECR repo, which then needs cleanup, and (c) teaches nothing that
walking through the `sub` claim's grammar doesn't already teach for free.
The IAM policy simulator (`aws iam simulate-principal-policy`) is the safe
way to test a suspected overly-broad condition if you want empirical
confirmation instead of reasoning it through by hand.

## The digest-vs-tag answer (Exercise 3)

A pipeline that "redeploys yesterday's execution" ships different code than
it shipped yesterday when the deploy stage's configuration names a
**mutable tag** (`:latest`, `:staging`) instead of consuming the **digest**
recorded in the `Build` stage's `imageDetail.json`. Re-running an execution
re-triggers the deploy action; a deploy action configured against a tag
re-resolves that tag *at the moment it runs*, not at the moment the original
`Build` stage ran. If any push landed a new image under that tag in the
meantime, the redeploy ships those new bytes — with no error, no warning,
and a pipeline execution history that shows nothing except "succeeded" both
times. This lab's `DeployStaging` and `DeployProd` actions consume
`imageDetail.json` from the `Build` stage's output artifact specifically to
avoid this: the same file, produced once, is the only thing either deploy
action ever reads.

## Expected `aws codepipeline get-pipeline-state` output shape

```json
{
  "pipelineName": "awsdevops-pipeline",
  "stageStates": [
    {
      "stageName": "Source",
      "actionStates": [
        { "actionName": "Source", "latestExecution": { "status": "Succeeded" } }
      ],
      "latestExecution": { "pipelineExecutionId": "<uuid>", "status": "Succeeded" }
    },
    {
      "stageName": "Build",
      "actionStates": [
        { "actionName": "Build", "latestExecution": { "status": "Succeeded" } }
      ],
      "latestExecution": { "pipelineExecutionId": "<uuid>", "status": "Succeeded" }
    },
    {
      "stageName": "DeployStaging",
      "actionStates": [
        { "actionName": "DeployStaging", "latestExecution": { "status": "Succeeded" } }
      ],
      "latestExecution": { "pipelineExecutionId": "<uuid>", "status": "Succeeded" }
    },
    {
      "stageName": "Approval",
      "actionStates": [
        {
          "actionName": "PromoteToProd",
          "latestExecution": { "status": "InProgress" }
        }
      ],
      "latestExecution": { "pipelineExecutionId": "<uuid>", "status": "InProgress" }
    },
    {
      "stageName": "DeployProd",
      "actionStates": [
        { "actionName": "DeployProd" }
      ]
    }
  ]
}
```

The pipeline sits `InProgress` at `Approval` until you approve or reject it
via the console or `aws codepipeline put-approval-result`. `DeployProd`
shows no `latestExecution` until the approval is granted and the pipeline
moves forward — that's the gate doing its job.
