# Teardown — Day A1

**This lab creates nothing.** There is no Terraform in this directory on
purpose: every drill reads, and every resource it reads was created by
`labs/foundation/` or `labs/day01/`. No meter started when you began, and
none stops when you finish.

That leaves exactly four things to do.

## 1. Leave `labs/foundation/` standing

Do not destroy it. It is meant to survive the whole week, Day A2's stack
borrows its VPC, its public subnets, and the `awsdevops-sample` ECR
repository, and there is nothing hourly in it to save money on — the VPC,
internet gateway, subnets, and route tables are free, and one ~15 MB image
in ECR is a fraction of a cent per month. See `../foundation/teardown.md`
for the correct end-of-week order.

## 2. If you re-applied `labs/day01/` for this lab, destroy it again

If Day 1's stack was already up before you started, leave it however you
found it. If you re-applied it so that D9, D10 and D11 had a build project
and a build record to interrogate, take it back down now, following
`../day01/teardown.md` rather than improvising:

```bash
cd labs/day01
terraform destroy
```

Then do the one check that file calls out, because it is the part
`terraform destroy` cannot do for you — CodeBuild auto-creates its log
group the moment a build runs, and an auto-created log group is a real AWS
resource that never enters Terraform state:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/codebuild/awsdevops-build \
  --query 'logGroups[*].logGroupName'
```

If anything is still listed after `terraform destroy` completed, delete it
directly:

```bash
aws logs delete-log-group --log-group-name /aws/codebuild/awsdevops-build
```

**Leave the images in ECR.** Day 1's build output is evidence its Success
Criterion asks for, Day A2's cycles need at least one image (and cycle C1
needs two), and storage for them is a rounding error.

## 3. Undo what Break it / Fix it changed on your laptop

Nothing in this lab changed anything in AWS — but stages (b), (c) and (d)
changed state on your machine, and that state does not announce itself an
hour later. Confirm all three, rather than remembering that you meant to:

```bash
aws configure list
```

- No `AWS_REGION` or `AWS_DEFAULT_REGION` left over from stage (a); the
  `region` row must read what D2 recorded.
- No `AWS_PROFILE` left over from stage (c); the `profile` row must not
  read `Type: env` unless it did before you started.
- `~/.aws/credentials` back to correct headers after stage (b) — `[NAME]`
  with no prefix — and no `~/.aws/credentials.bak` left lying around with
  a copy of your keys in it.
- `~/.aws/sso/cache` back in place after stage (d), and
  `aws sso login --profile <YOUR_SSO_PROFILE>` run if you let the session
  lapse.

Then the identity check, which is the same one that opened D1 and should
now give the same answer it gave then:

```bash
aws sts get-caller-identity
```

## 4. Verify, rather than assume

From `aws_devops_sre/` (step 2 left you in `labs/day01` if you ran it):

```bash
cd ../..
bash labs/verify-teardown.sh
```

This is a read-only audit — it only calls `describe-*` and `list-*`, and
it never removes anything. Expect **zero unexpected resources**: no NAT
gateways, no load balancers, and nothing from Day 3 or Day A2 still
running. The foundation stack's VPC and ECR repository are expected to be
there and are not what this script is hunting for.

## Cost after teardown

**$0.00 from this lab**, because it started nothing. Whatever
`labs/foundation/` costs you is unchanged, and it is approximately zero.
