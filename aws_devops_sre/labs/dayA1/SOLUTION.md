# Day A1 lab — solution reference

Read this after you have written your own command for a drill, not before.
Where more than one command is correct, this file says so.

Every expected output below is a **shape**, not a value. Account IDs are
`123456789012`, digests are `sha256:<64 hex>`, resource IDs are truncated
(`vpc-0abc...`). Yours will differ in every one of those places and match
in structure — and if the structure differs, that is the interesting part.

Two conventions used throughout:

- `--query` arguments are quoted as a whole, every time. Single quotes by
  default; **double** quotes when the JMESPath itself contains a
  single-quoted string literal, because shell single quotes do not nest
  (F19).
- Shell variables (`$VPC_ID`, `$BUILD_ID`) carry values set by an earlier
  command — usually in the same drill, sometimes in an earlier one: D8
  reuses the `$VPC_ID` you set back in D6. Nothing here pastes a value it
  could compute.

---

## D1 — Which identity and region will your next un-flagged command use?

Two commands, because it is two questions.

```bash
aws configure list
aws sts get-caller-identity
```

```text
      Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key     ****************ABCD  shared-credentials-file
secret_key     ****************WXYZ  shared-credentials-file
    region                us-east-1      config-file    ~/.aws/config
```

```json
{
    "UserId": "AIDA<...>",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/<YOUR_IAM_USER>"
}
```

**Why these two and not one.** `aws configure list` answers "what
resolved, and from where" — including the region, which
`get-caller-identity` does not report at all. `aws sts
get-caller-identity` answers "who does the service think I am," and it is
the only one of the two that involves the service: it is ground truth,
it returns `UserId` / `Account` / `Arn`, and it requires no permissions
beyond being authenticated (F4), so it still works when the identity that
resolved is allowed to do nothing else. Reciting the eight-step credential
provider chain from memory (F1) is not an answer to this drill; it
describes every laptop and yours specifically is a fact you can read.

If your `Arn` says `assumed-role` rather than `user`, you came in through
SSO or an assumed role — that is fine, and it changes what Break it stage
(d) will do to you.

---

## D2 — Which file did each of those resolved values come from?

The same command, read differently:

```bash
aws configure list
```

Read the **Type** and **Location** columns and ignore `Value` entirely
(F3). In the sample above: no profile was named, credentials came from the
shared credentials file (`~/.aws/credentials`), and the region came from
the config file (`~/.aws/config`). That is the whole answer, and it is a
sentence, not a table.

The values that would change in a brand-new terminal tab are exactly the
rows whose `Type` reads `env` — because those came from a variable
exported in *this* shell and nowhere else. A new tab loses them, which is
why "it worked in my other window" is a real bug report and not a
superstition. Rows reading `config-file`, `shared-credentials-file`, or
`iam-role` are properties of the machine, not the tab.

**Why not read the files directly.** `cat ~/.aws/config` tells you what is
written down; it does not tell you what won a precedence contest against
an environment variable and a command-line flag. The whole point of this
command is that it reports the outcome, not the inputs.

---

## D3 — What is the account number you are pointed at?

```bash
aws sts get-caller-identity --query 'Account' --output text
```

```text
123456789012
```

**Why `--output text` is safe here specifically.** The projection returns
exactly one scalar, so there is no second field for a positional read to
miscount (F8). The moment a projection returns more than one field — or a
field that is itself a list, or one that can be absent — `text` becomes a
trap and the answer is `json` plus a real JSON parse. D7 is that case.

Record this number. Break it stage (c) is a comparison against it.

---

## D4 — Which images does the ECR repository hold?

Enumerate the repositories first. ECR has no `list-repositories`
operation — `aws ecr help` shows what it does have, and the enumerating
verb is `describe-repositories`, which returns every repository when you
give it no `--repository-names`:

```bash
aws ecr describe-repositories --query 'repositories[].repositoryName'
```

```json
[
    "awsdevops-sample"
]
```

That is the `list-` / `describe-` / `get-` heuristic failing in a useful
way: it is a naming convention, not a rule the service models enforce, and
two seconds of `aws ecr help` settles it. The full object is worth one
look, because D5 needs one field from it:

```bash
aws ecr describe-repositories --repository-names awsdevops-sample
```

```json
{
    "repositories": [
        {
            "repositoryArn": "arn:aws:ecr:us-east-1:123456789012:repository/awsdevops-sample",
            "registryId": "123456789012",
            "repositoryName": "awsdevops-sample",
            "repositoryUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/awsdevops-sample",
            "createdAt": "<timestamp>",
            "imageTagMutability": "IMMUTABLE",
            "imageScanningConfiguration": {
                "scanOnPush": true
            }
        }
    ]
}
```

Now the images, both verbs:

```bash
aws ecr list-images --repository-name awsdevops-sample
aws ecr describe-images --repository-name awsdevops-sample
```

```json
{
    "imageIds": [
        {
            "imageDigest": "sha256:<64 hex>",
            "imageTag": "a1b2c3d4e5f6"
        }
    ]
}
```

```json
{
    "imageDetails": [
        {
            "registryId": "123456789012",
            "repositoryName": "awsdevops-sample",
            "imageDigest": "sha256:<64 hex>",
            "imageTags": [
                "a1b2c3d4e5f6"
            ],
            "imageSizeInBytes": 15000000,
            "imagePushedAt": "<timestamp>",
            "imageManifestMediaType": "application/vnd.oci.image.manifest.v1+json"
        }
    ]
}
```

**What the second verb gave you that the first did not:** size, push time,
the manifest media type, and — the one that matters for D7 — `imageTags`
as a **list**, where `list-images` flattened it into a single `imageTag`
per entry. An image with two tags appears twice in `list-images` and once
in `describe-images`. An image with no tags appears in both, with no tag
field at all in the first and an absent or empty `imageTags` in the second,
which is exactly the absent-field case that makes `--output text` fragile.

If `scanOnPush` produced findings, `describe-images` also carries an
`imageScanStatus` / `imageScanFindingsSummary` block. Its presence depends
on whether the scan has completed; do not build a projection that assumes
it is there.

---

## D5 — What is the digest behind a given tag?

```bash
aws ecr describe-images --repository-name awsdevops-sample \
  --image-ids imageTag=a1b2c3d4e5f6 \
  --query 'imageDetails[0].imageDigest' \
  --output text
```

```text
sha256:<64 hex>
```

**Why `--image-ids` rather than a `--query` filter over everything.**
`--image-ids` is a parameter the operation itself defines, so the *service*
selects the image and the response contains one entry. A projection such as
`--query "imageDetails[?contains(imageTags, 'a1b2c3d4e5f6')].imageDigest"`
returns the same string, but only after every image in the repository has
crossed the network and been parsed on your laptop — `--query` is
client-side JMESPath evaluated after the full response arrived (F6). With
one image in the repository the difference is invisible; the habit is what
you are drilling. Note the shorthand shape: `imageTag=<value>`, not a bare
string, because `--image-ids` takes a list of structures — `aws ecr
describe-images help` gives the full form.

**Why this repository's answer is stable.** `labs/foundation/main.tf`
creates the repository with `image_tag_mutability = "IMMUTABLE"`, so a tag
that exists cannot be moved to a different image — an attempt to overwrite
it is rejected rather than silently applied (F17). In a `MUTABLE`
repository the same command is a snapshot of a pointer that the next push
can move, which is the whole argument `content/day01.md` makes for
consuming digests rather than tags.

---

## D6 — Which subnets does the foundation VPC have?

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=awsdevops-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text)

aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].SubnetId'
```

```json
[
    "subnet-0abc...",
    "subnet-0def..."
]
```

Two subnets, in two availability zones — `labs/foundation/main.tf` creates
them with `count = 2` because Day 3's ALB refuses to exist in one AZ.

**Why `--filters` twice rather than `--query` twice.** `--filters` is
server-side: EC2 applies it before building the response, so fewer results
means fewer bytes and fewer paginated calls, and it helps if you are being
throttled. `--query` does none of those three things (F6). Both narrowings
here have a filter name that EC2 accepts — `tag:<Key>` for any tag and
`vpc-id` for the association — so there is no reason to pay for the full
account listing. The rule generalizes: if the operation offers a named
parameter for your condition, that is the answer; `--query` is what you use
when it does not.

`--query 'Vpcs[0].VpcId'` indexes rather than projecting because the filter
already guarantees at most one match, and `--output text` is safe because
the result is one scalar. If the tag matched two VPCs you would get the
first one silently, so check the count once (`--query 'length(Vpcs)'`)
before you trust `[0]` in anything that matters.

---

## D7 — Images as a two-column table, newest first

```bash
aws ecr describe-images --repository-name awsdevops-sample \
  --query 'reverse(sort_by(imageDetails,&imagePushedAt))[].{Tag:imageTags[0],Pushed:imagePushedAt}' \
  --output table
```

```text
-----------------------------------------------
|                DescribeImages               |
+---------------------------+-----------------+
|          Pushed           |      Tag        |
+---------------------------+-----------------+
|  <timestamp, newest>      |  a1b2c3d4e5f6   |
|  <timestamp, older>       |  f6e5d4c3b2a1   |
+---------------------------+-----------------+
```

Three pieces, in order. `sort_by(imageDetails,&imagePushedAt)` sorts
ascending by push time — the `&` makes an expression reference, which is
what `sort_by` requires rather than a plain field name. `reverse(...)`
turns it into newest-first. The multiselect **hash**
`{Tag:...,Pushed:...}` emits a named object per element, which is why the
table has column headers instead of two anonymous columns nobody can
identify.

`sort_by(imageDetails,&imagePushedAt)[::-1]` is the same thing with a
slice, and `sort_by(...)[-1]` is the "just the newest one" idiom from
`content/dayA1.md`. Any of the three is a correct answer; `reverse` reads
most clearly to the next person.

**Why `--output table` and not `text`.** The projection returns two fields
per row, and one of them (`imageTags[0]`) can be absent on an untagged
image. `text` is tab-separated with nested structures flattened, so a
positional `cut -f2` against it lands on a column decided by the data
rather than by you — right on the row you tested, wrong on the row that
matters (F8). `table` is for reading once with your eyes; if a program is
going to consume this, take `json` and parse it as JSON.

Column order in `table` output is JMESPath hash key order, which is not the
order you wrote the keys in. That is cosmetic here and would be a bug if
you were parsing it.

---

## D8 — Public-IP subnets as `Name`-tag / CIDR pairs

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
            "Name=map-public-ip-on-launch,Values=true" \
  --query "Subnets[].{Name:Tags[?Key=='Name']|[0].Value,Cidr:CidrBlock}" \
  --output table
```

```text
---------------------------------------------
|              DescribeSubnets              |
+-----------------+-------------------------+
|      Cidr       |          Name           |
+-----------------+-------------------------+
|  10.42.0.0/24   |  awsdevops-public-0     |
|  10.42.1.0/24   |  awsdevops-public-1     |
+-----------------+-------------------------+
```

Both foundation subnets set `map_public_ip_on_launch = true`, on purpose:
there is no NAT gateway anywhere in this path, so Fargate tasks and
anything else that needs the internet get a public IP instead.

**Two things to notice in that query.** First, `map-public-ip-on-launch`
is a filter name EC2 actually accepts, so the condition runs in the
service — `aws ec2 describe-subnets help` lists the filter vocabulary, and
checking it before writing JMESPath is the reflex worth building. Second,
`Tags[?Key=='Name']|[0].Value` is the standard three-step for pulling one
tag value out of a key/value list: filter the list, pipe into an index
(the `|` is required — `Tags[?Key=='Name'][0]` indexes *inside* the
projection and does not do what you want), then take the field.

**Why double quotes on the outside here.** The expression contains the
string literal `'Name'`, and shell single quotes do not nest — written
with single quotes on the outside, the shell would read three glued
fragments and leave the brackets unquoted, which in `zsh` is a glob and
fails with `no matches found` (F19). Double quotes suppress globbing
equally well. The alternative is the JSON-literal form `` [?Key==`"Name"`] ``
inside single quotes; never put that form inside double quotes, where a
backtick is command substitution.

A subnet with no `Name` tag yields `null` in the `Name` column rather than
dropping the row. That is correct behavior and worth seeing once.

---

## D9 — How many of this project's builds failed?

Two commands first, because that is how you learn the shape:

```bash
aws codebuild list-builds-for-project \
  --project-name awsdevops-build \
  --sort-order DESCENDING
```

```json
{
    "ids": [
        "awsdevops-build:<uuid>",
        "awsdevops-build:<uuid>"
    ]
}
```

```bash
aws codebuild batch-get-builds \
  --ids awsdevops-build:<uuid> awsdevops-build:<uuid> \
  --query 'builds[].buildStatus'
```

```json
[
    "FAILED",
    "SUCCEEDED"
]
```

Then the count, composed:

```bash
aws codebuild batch-get-builds \
  --ids $(aws codebuild list-builds-for-project \
            --project-name awsdevops-build \
            --sort-order DESCENDING \
            --query 'ids' --output text) \
  --query "length(builds[?buildStatus=='FAILED'])"
```

```text
1
```

**Why the chain.** `list-builds-for-project` returns IDs and nothing else;
status lives only in the fuller object, and the operation that returns
that object takes IDs. Argument to a `describe-`-shaped call comes out of a
`list-` — the basic interrogation shape. The inner command substitution is
unquoted on purpose so that `zsh` splits the tab-separated `--output text`
result into separate `--ids` arguments; quoting it would hand the operation
one long string and fail parameter validation.

**Is "failed" the same as "did not succeed"?** No, and your own output
answers it: run `--query 'builds[].buildStatus'` with no filter and read
the distinct values present. A build that timed out or was stopped is not
`FAILED`, and one still running is neither. If the question you were
actually asked is "how many did not succeed," the filter is
`[?buildStatus!='SUCCEEDED']` and it is a different number. Decide which
question you are answering before you report a count.

**Two limits to respect.** `list-builds-for-project` paginates, and CLI v2
auto-paginates it — on a project with a long history that is several API
calls and a long list. `batch-get-builds` accepts a bounded number of IDs
per call; check `aws codebuild batch-get-builds help` before you pipe an
unbounded list into it. And `--sort-order DESCENDING` is stated explicitly
rather than relying on a remembered default, which matters because D11
takes `ids[0]` and means it.

---

## D10 — Can Day 1's CodeBuild role push to the repository?

```bash
ROLE_ARN=$(aws codebuild batch-get-projects \
  --names awsdevops-build \
  --query 'projects[0].serviceRole' \
  --output text)

REPO_ARN=$(aws ecr describe-repositories \
  --repository-names awsdevops-sample \
  --query 'repositories[0].repositoryArn' \
  --output text)

aws iam simulate-principal-policy \
  --policy-source-arn "$ROLE_ARN" \
  --action-names ecr:PutImage \
  --resource-arns "$REPO_ARN" \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision}'
```

```json
[
    {
        "Action": "ecr:PutImage",
        "Decision": "allowed"
    }
]
```

Now the same simulation against a repository ARN that does not exist:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$ROLE_ARN" \
  --action-names ecr:PutImage \
  --resource-arns arn:aws:ecr:us-east-1:123456789012:repository/awsdevops-not-a-repo \
  --query 'EvaluationResults[].EvalDecision'
```

```json
[
    "implicitDeny"
]
```

**Why the two differ.** `labs/day01/main.tf` grants `ecr:PutImage` (with
the four layer-upload actions) on exactly one `Resource`: the foundation
repository's ARN, read from `terraform_remote_state`. Nothing in that role
grants the action on any other repository, and nothing denies it either —
so the decision is `implicitDeny`: *nothing grants this*. That is a
different fix from `explicitDeny` (*something actively forbids this* — go
find the SCP, the boundary, or the `Deny` statement and argue with it),
which is exactly why a three-way answer beats a yes/no (F16).

**Why the simulator rather than reading the policy.** Reading
`aws iam get-role-policy --role-name awsdevops-build-role --policy-name
awsdevops-build-policy` shows you what one document says. It does not
evaluate it against everything else that applies to the principal, and it
does not tell you what the result would be. When you hit `AccessDenied`,
the identity already resolved — re-checking your profile is the wrong
instinct — and the open question is what that principal is permitted to do.
This command answers that question; a policy document read hopefully does
not.

**Two honest limits.** The simulation evaluates policies attached to the
principal you name — `labs/foundation/` creates no ECR repository policy,
so there is nothing on the resource side for it to miss here, but on a
repository that had one, an identity-only simulation is a partial answer.
And IAM is eventually consistent (F18): if you applied Day 1 seconds ago,
a simulation can lag the write. Re-run it before concluding that a grant
you made moments earlier does not exist.

---

## D11 — Which commit produced the image, and what is its digest?

Separate commands first:

```bash
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name awsdevops-build \
  --sort-order DESCENDING \
  --query 'ids[0]' --output text)

aws codebuild batch-get-builds --ids "$BUILD_ID" \
  --query 'builds[0].{Build:id,Status:buildStatus,Commit:resolvedSourceVersion}'
```

```json
{
    "Build": "awsdevops-build:<uuid>",
    "Status": "SUCCEEDED",
    "Commit": "<40 hex>"
}
```

```bash
COMMIT=$(aws codebuild batch-get-builds --ids "$BUILD_ID" \
  --query 'builds[0].resolvedSourceVersion' --output text)

TAG=$(echo "$COMMIT" | cut -c1-12)

aws ecr describe-images --repository-name awsdevops-sample \
  --image-ids imageTag="$TAG" \
  --query 'imageDetails[0].imageDigest' --output text
```

```text
sha256:<64 hex>
```

Composed, with the newest **successful** build rather than the newest
build:

```bash
aws ecr describe-images --repository-name awsdevops-sample \
  --image-ids imageTag=$(aws codebuild batch-get-builds \
      --ids $(aws codebuild list-builds-for-project \
                --project-name awsdevops-build \
                --sort-order DESCENDING \
                --query 'ids' --output text) \
      --query "builds[?buildStatus=='SUCCEEDED']|[0].resolvedSourceVersion" \
      --output text | cut -c1-12) \
  --query 'imageDetails[0].imageDigest' --output text
```

**Why `resolvedSourceVersion` and not the source version you asked for.**
It is the commit CodeBuild actually checked out — a full 40-character SHA.
`labs/day01/buildspec.yml` derives the image tag from it with
`cut -c1-12`, and reading that file is how you learn the transformation
rather than guessing at it. A branch name would answer a different
question ("what branch") than the one this chain is about.

**Why filter to `SUCCEEDED`.** If Day 1's Break it / Fix it left a failed
build at the top of the list — it does: re-running against an unchanged
commit fails the push against the immutable tag — then `ids[0]` names a
build that pushed nothing. Its `resolvedSourceVersion` is still a real
commit, and in that particular case it even resolves to a tag that exists
(the earlier successful build put it there), which is precisely the kind
of coincidence that makes a wrong command look right. `[?...]|[0]` filters
then indexes; the pipe is required for the same reason as in D8.

**Why compose rather than paste.** A pasted digest is true until the next
push. The composed command is a question, and it stays answerable
tomorrow — which is the difference between a runbook and a note to self.
Compose only after each link has been run alone and read.

---

## D12 — Proving a resource is genuinely absent

Three states, three behaviors (F13). Check the exit status every time —
this is the drill where assuming it costs you.

**State 1 — empty array, exit 0.**

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/codebuild/awsdevops-not-a-project \
  --query 'logGroups'
echo $?
```

```json
[]
```

```text
0
```

Nothing matched and the API said so successfully. Note that this is a
`describe-`, and it did **not** raise: `--log-group-name-prefix` is a
server-side *filter*, and no match for a filter is an empty list rather
than an error. The same shape comes back from any `list-` that matches
nothing.

**State 2 — a raised service exception, non-zero exit.**

```bash
aws ecr describe-images --repository-name awsdevops-not-a-repo
echo $?
```

```text
An error occurred (RepositoryNotFoundException) when calling the
DescribeImages operation: The repository with name 'awsdevops-not-a-repo'
does not exist in the registry with id '123456789012'
```

Non-zero — record the exact value your CLI prints rather than trusting a
number from this file; v2 reserves distinct non-zero codes for different
failure classes. This is the clean example of a `describe-` that names a
resource and raises when it is not there. If you ever see *silence* from a
call in this state, something upstream swallowed stderr (a `2>/dev/null`
in a script, a pipeline that discarded it) and you are reading silence as
data.

**State 3 — exit 0, empty main array, and `failures[]`.**

Neither `labs/foundation/` nor `labs/day01/` creates any ECS resources, so
any cluster name is a name that does not exist in your account — which is
exactly the situation this state is about:

```bash
aws ecs describe-clusters --clusters awsdevops-not-a-cluster
echo $?
```

```json
{
    "clusters": [],
    "failures": [
        {
            "arn": "arn:aws:ecs:us-east-1:123456789012:cluster/awsdevops-not-a-cluster",
            "reason": "MISSING"
        }
    ]
}
```

```text
0
```

**Exit 0. No exception. No warning.** ECS's batch describes —
`describe-clusters`, `describe-services`, `describe-tasks` — return the
items they found in the main array and a parallel `failures[]` array
carrying `{arn, reason: "MISSING"}` for every identifier they could not
find. An empty `clusters` array here is not evidence of absence on its own,
and a command that exits 0 can still have found nothing. **Always check
`failures[]`:**

```bash
aws ecs describe-clusters --clusters awsdevops-not-a-cluster \
  --query 'failures'
```

The contrast that pins it down — the same missing name, but as the
`--cluster` *parameter* of a different operation:

```bash
aws ecs list-services --cluster awsdevops-not-a-cluster
echo $?
```

```text
An error occurred (ClusterNotFoundException) when calling the ListServices
operation: Cluster not found.
```

`ClusterNotFoundException` is real, and this is where it comes from:
operations whose `--cluster` parameter names a cluster that does not exist
(`describe-services`, `list-services`, `list-tasks`). It is never what
`describe-clusters --clusters` gives you — that call reports the same
absence in `failures[]` instead. Two commands, one missing cluster, two
completely different behaviors.

**The drill's real question — which verb entitles you to say "it is not
there"?** Only one whose contract distinguishes absence from emptiness:
a `describe-` that raises (state 2), or an ECS batch describe whose
`failures[]` you actually read (state 3). An empty array from state 1 is a
claim about one account, in one region, as seen by one identity — never a
claim about the world. Which is why the answer is only half a verb: the
other half is `aws configure list` and `aws sts get-caller-identity`,
because an empty result from the wrong region looks exactly like an empty
result from the right one.

**The opposite direction — a real resource, an empty array.**

```bash
aws iam list-attached-role-policies --role-name awsdevops-build-role
aws iam list-role-policies --role-name awsdevops-build-role
```

```json
{
    "AttachedPolicies": []
}
```

```json
{
    "PolicyNames": [
        "awsdevops-build-policy"
    ]
}
```

The role exists — `labs/day01/main.tf` creates it — and the first call is
genuinely, correctly empty, because Day 1 attaches its permissions as an
**inline** policy (`aws_iam_role_policy`) rather than as a managed policy.
Read the first result as "this role has no permissions" and you would be
wrong in a way nothing in the output corrects. Empty is a fact about the
question you asked, not about the resource. (Get the role name wrong and
this same operation raises `NoSuchEntity` — state 2 again, from IAM.)

---

## Break it / Fix it — families and fixes

Name the family from the output first. These are the answers.

### (a) Wrong region, quietly

**What failed:** **WHO**, the region half of it. The command, the
parameters, and your credentials were all correct.

**Family:** it *presents* as "not found vs. empty" — an empty result at
exit 0 — but there is no error to classify, which is the trap. Nothing in
the output says "you asked the wrong continent." An empty array from the
wrong region is byte-identical to an empty array from the right one.

**Fix:** `aws configure list`, and read the `region` row's `Type` and
`Location`. `Type: env` names the shell you are standing in as the source,
and `unset AWS_REGION` (plus `AWS_DEFAULT_REGION` if you have it exported)
puts it back. The generalization is the one worth keeping: before you tell
anyone a resource is gone, confirm the **WHO** that produced the emptiness.

#### The second half — no region at all

**What failed:** **WHO**, the same half of it — but this time the
resolution chain came up *empty* rather than coming up *wrong*. Hiding
`~/.aws/config` for one command (`AWS_CONFIG_FILE=/dev/null aws …`, after
`unset AWS_REGION AWS_DEFAULT_REGION`) leaves no step of the chain holding
a region.

**Family:** client-side validation. `You must specify a region` is produced
before anything is signed or sent, which is why it names your configuration
and not a service, and why the exit status is non-zero (read the one your
CLI prints). It rules out everything on the AWS side at once: permissions,
the account, the repository's existence — none of them can be the cause of
a request that was never made.

**Fix:** put a region back at any step of the chain — `--region <NAME>` on
the command, `export AWS_REGION=<NAME>` in the shell, or the `region =`
line in the profile block in `~/.aws/config`, which is where it normally
lives and which the stage hides for exactly one invocation so that the
chain has nothing left to find. Nothing persists; the prefix expires with
the command.

**Why the two halves are one stage.** They are the same missing piece
behaving in opposite directions, and the pair teaches what neither half
teaches alone. A wrong region is a *successful* call: it reaches AWS, and
AWS answers it honestly, about the wrong place — so the `[]` is a fact
about your configuration wearing the costume of a fact about the world. A
missing region is not a call at all, and it tells you so in one line. The
failure that shouts is the cheap one. The failure to fear is the one that
exits 0.

### (b) A profile header with the wrong prefix

**What failed:** **WHO**. **Family:** credential and expiry — the error
names a missing profile, and it rules out the operation and its parameters
entirely, because you never got far enough for them to matter.

**Fix:** `~/.aws/credentials` takes `[personal]` with **no** prefix;
`~/.aws/config` takes `[profile personal]` with it; `[default]` takes no
prefix in either file (F2). Writing `[profile personal]` into the
credentials file creates a profile named the literal string `profile
personal`, which nothing will ever select. Change the header back, or
restore the backup, and confirm with `aws configure list --profile
personal`.

Nothing about this failure is a permissions problem, and no amount of
re-authenticating touches it.

### (c) A stale `AWS_PROFILE` in this shell

**What failed:** **WHO**. **Family:** none — and that is the lesson. There
is no error to read, because nothing errored. The command succeeded
against an account you did not mean.

**Fix:** `aws sts get-caller-identity` is the only honest witness, and it
is only useful because you wrote D3's account ID down and can compare.
`aws configure list` then shows `profile` with `Type: env` and names the
culprit; `unset AWS_PROFILE` clears it. Note the precedence detail worth
carrying: a `--profile` flag on the command line would have beaten the
environment variable (F1, step 1 over step 2), which is why the same
command run two ways can reach two accounts.

### (d) An expired SSO session

**What failed:** **WHO**. **Family:** credential and expiry — *not*
authorization.

**Fix:** `aws sso login --profile <YOUR_SSO_PROFILE>`. That is the whole
repair, and the reason this stage exists is the diagnosis rather than the
repair: expiry surfaces as a token-loading or refresh error, **not** as
`AccessDenied` (F5). Cached tokens live under `~/.aws/sso/cache/`, and
`aws configure sso` is what wrote the `[sso-session NAME]` and
`[profile NAME]` blocks into `~/.aws/config` in the first place.

The mislocation to inoculate against: responding to this by re-reading an
IAM policy. Nothing about your permissions changed. Conversely, if the
error genuinely reads `AccessDenied`, you are in the authorization family
and the next command is `simulate-principal-policy` (D10), not another
login.

### (e) The truncation trap

**What failed:** **WHAT CAME BACK** — truncated before **WHAT DID I SEE**
ever ran. **Family:** none. Exit status 0, empty array, no warning, and a
confidently wrong answer.

**The order is the whole explanation.** `--max-items` is a client-side cap
that stops the output at N items and emits a continuation token; the
projection is applied to what survived the cap. So the filter searched a
two-item sample of a list with hundreds of entries and honestly reported no
matches. The `[]` is not a fact about IAM (F7).

**Fix — and first, the fix that does not exist.** The general rule is to
move the condition into a parameter the API accepts, so the *service*
narrows and the response you paginate is the one you wanted. On this
command that rule has **no implementation**. `list-policies` takes
`--scope`, `--path-prefix` and `--only-attached`; none of the three can
express an equality on `PolicyName` — `--scope` is a category (and already
in use here), `--path-prefix` filters on the policy path, `--only-attached`
on whether anything is using it. There is no server-side name filter on
`aws iam list-policies`. `aws iam list-policies help` shows you that in
about fifteen seconds, and checking is the point: a rule you apply without
confirming it has somewhere to land will have you hunting for a parameter
that was never there — in a lab whose whole subject is not being misled by
what the CLI tells you.

So the honest answers are these:

1. Drop the `--max-items` cap and let v2 auto-paginate the whole list, then
   project. You pay the full API and transfer cost, and you get a true
   answer. When no parameter can express your condition, this *is* the
   right answer, not a consolation prize (decision-rule table,
   `content/dayA1.md`).
2. Once you have the ARN, stop listing: `aws iam get-policy --policy-arn
   <ARN> --query 'Policy.PolicyName'` asks about exactly one policy and
   paginates nothing. A `list-` is how you get in when you know no
   identifier; the moment you hold one, the `get-`/`describe-` form is both
   cheaper and impossible to truncate.
3. Whichever you use: if you must cap, cap *after* you have understood the
   shape of the full result — and never combine a cap with a filter you
   intend to believe.

The rule itself stands, and `content/dayA1.md` gives the case where it
genuinely applies: `--family-prefix` on `ecs list-task-definitions` (Core
concept 4, and the decision-rule table's server-side-parameter row). There
the service can take the condition, so the truncation bug never has to
arise at all. The two commands are worth holding side by side — one shows
you what pushing the filter down looks like, the other shows you how to
recognise that there is nowhere to push it to.

`--page-size` is not a fix and does not belong in this list: it sets the
per-request API page size, changing how many items each underlying call
asks for, not how many you end up with. `--no-paginate` issues exactly one
API call and is a fine exploratory tool for bounding a command whose result
size you do not yet know — but it truncates too, so it earns the same
distrust as `--max-items` the moment a filter is involved.

---

## What you should now be able to do

- Turn an English question about an account into a command, starting from
  `aws <service> help` rather than a search engine.
- Say, for any command you wrote today, whether each narrowing ran in the
  service or on your laptop — and therefore whether it saved you anything.
- Read an empty result as a question rather than an answer, and know which
  of the three "nothing came back" states you are in before you say a
  resource is gone.
- Answer `AccessDenied` with a simulation instead of a policy document and
  a hope.
