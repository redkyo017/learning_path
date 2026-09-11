# Day A1 lab — twelve questions, answered by CLI only

**Goal:** turn twelve English questions about an AWS account into the
commands that answer them, against infrastructure you built yourself
earlier in this path.

**Success signal:** every drill answered with a command you could
reconstruct tomorrow, from the four-way split, without looking it up.

> **The console is forbidden for the duration of this lab.** Not
> discouraged — forbidden. No browser tab, not "just to check the answer,"
> not "only to find the name." The console resolves a different identity
> than your terminal does, so it can show you a resource your CLI genuinely
> cannot see and leave you further from the answer than you started; and an
> answer it gives you is not a command you can paste into a runbook
> tomorrow. If you find yourself reaching for it, the next command is
> `aws sts get-caller-identity`, then `aws configure list`.

Read `content/dayA1.md` first. This README assumes you already know the
four labels — **WHO**, **WHAT**, **WHAT CAME BACK**, **WHAT DID I SEE** —
the `list-` / `describe-` / `get-` heuristic, the difference between a
server-side filter and a client-side projection, and the four error
families. It does not re-teach any of that. It makes you use it twelve
times.

Budget ~110 minutes for the drills and ~20 more for Break it / Fix it.
This lab creates nothing and costs nothing beyond what is already
standing.

---

## Before you start

- **`labs/foundation/` must be applied.** Every drill in groups 2 and 3
  interrogates its VPC, its two public subnets, or the `awsdevops-sample`
  ECR repository.
- **`labs/day01/` must be applied**, and **at least one build must have
  run to completion**, so ECR holds an image and CodeBuild holds a build
  record. Groups 3 and 4 have nothing to read otherwise. If you tore Day 1
  down, re-apply it (`labs/day01/README.md`, steps 1–3) and destroy it
  again at the end — `teardown.md` in this directory says how.
- **The region is `us-east-1`** unless you deliberately changed
  `aws_region`. Drill D1 is where you confirm that rather than assume it.
- **Nothing here runs a command for you.** Every command is yours to type
  and read the output of. That is the entire exercise: a drill you paste
  from `SOLUTION.md` teaches you nothing.

**How to grade yourself.** Write your command down *before* you run it,
then run it, then compare with `SOLUTION.md`. A drill counts as answered
only if you produced the command yourself. Getting a different command
that returns the same answer is a pass — there is more than one correct
way to ask most of these, and `SOLUTION.md` says so where it matters.

**Two allowances, and their limits.** You may use `terraform output` in
`labs/foundation/` or `labs/day01/` to *check* an answer the CLI gave you.
You may not use it to *produce* one — the drill is the AWS API call, and
Terraform state is a local file that can be stale, missing, or describing
a different account than the one your credentials reached. And you
may read `aws <service> <operation> help` as much as you like; it is the
service model, it is generated from the same description the CLI
implements, and reaching for it is the habit this day is trying to build.

**Add `--no-cli-pager` to anything whose output you are capturing or
piping.** CLI v2 sends output through a pager by default, and a pager
waiting for a keypress with no keyboard attached is a hang, not an error.
The commands below leave it off for readability; add it the moment you put
one in a script.

---

## D1–D3 — WHO

Three drills, no service calls of consequence. If you cannot answer these,
every answer after them is unsigned — an empty array from the wrong
account looks exactly like an empty array from the right one.

### D1 — Which identity and region will your next un-flagged command use?

Type `aws ecr describe-repositories` with no `--profile` and no `--region`,
and it will reach exactly one account in exactly one region. Which ones?
Answer from your own machine's current state, not from the documented
precedence order — then prove the answer rather than asserting it.

**Hint:** two questions hide in this one, and they resolve through two
separate chains. One command shows you what resolved; a different one
proves who you are to the service. You need both, and neither one is a
guess.

### D2 — Which file did each of those resolved values come from?

For every setting that resolved in D1 — profile, access key, secret key,
region — name the mechanism that supplied it and, where there is one, the
file on disk it came out of. Then say which of them would change if you
opened a brand-new terminal tab.

**Hint:** the `Value` column is the least interesting one on that output.
Two other columns are the reason the command exists. An answer of `env`
should make you ask when you exported it and whether you meant to.

### D3 — What is the account number you are pointed at?

Get the twelve-digit account ID, on its own, with no surrounding JSON — the
form you could assign to a shell variable and compare against the account
you *meant* to be in.

**Hint:** the ground-truth identity command returns three fields and you
want one of them. A projection that returns exactly one scalar is the one
case where `--output text` is safe.

---

## D4–D6 — single calls

One API call each (plus, in two of them, a call to find the name the first
call needs). The skill is picking the right verb and the right parameter,
not composing anything clever.

### D4 — Which images does the ECR repository hold?

You know there is a repository because you applied `labs/foundation/`. Do
not type its name from memory: enumerate the repositories in this account
and region first, then ask that repository what images it holds. Do it
twice — once with the verb that returns identifiers, once with the verb
that returns detail — and say what the second one gave you that the first
did not.

**Hint:** ECR does not have every verb you might expect it to; `aws ecr
help` settles which enumerating verb exists in about two seconds. Then
`list-` versus `describe-` is the ordinary heuristic, and the point of
running both is to feel the difference rather than read about it.

### D5 — What is the digest behind a given tag?

Pick one tag from D4 — a twelve-character commit short-SHA, put there by
Day 1's buildspec. Return the `sha256:...` digest that tag currently points
at, as a bare string. Then say, in one sentence, why this repository's
answer to that question is stable and a mutable repository's would not be.

**Hint:** `describe-images` takes a parameter that lets the *service* pick
the image, rather than making you fetch every image and pick one on your
laptop. Find it in that operation's help; it is a structured parameter, not
a plain string. The repository's `imageTagMutability` setting is the other
half of the answer, and the repository enumeration you ran at the start of
D4 already printed it.

### D6 — Which subnets does the foundation VPC have?

Find the VPC by its `Name` tag — you did not write down its ID and you are
not allowed to look it up in the console — then list the subnets that
belong to it. Only that VPC's subnets: an account with a default VPC has
several more, and an answer that includes them is wrong.

**Hint:** both halves of this are the same trick, and the trick is
server-side. EC2's describe operations take a parameter that narrows the
result *in the service*, and it accepts tag keys as well as attributes. If
you find yourself pulling every subnet in the account and filtering on your
laptop, you have answered a different question at higher cost.

---

## D7–D9 — projections

Now the response is bigger than the answer. Everything in this group
happens after the bytes arrived; none of it can change what the API did.

### D7 — Show the images as a two-column table of tag and push time, newest first.

Two columns, labeled so a human reads them without counting fields, newest
at the top. No `jq`, no `sort`, no `awk` — the projection and the output
format do all of it.

**Hint:** sort by a field with an expression reference, reverse the result,
then emit a named object per element rather than a bare list. One of the
three output formats is built for reading with your eyes once; two of them
are not. And remember that `imageTags` is a list — an image can carry more
than one tag, or none at all.

### D8 — Show only the subnets that auto-assign public IPs, as `Name`-tag / CIDR pairs.

Both of the foundation subnets do auto-assign; a default VPC's subnets
usually do too, so keep D6's VPC narrowing in place. Output one row per
subnet with the `Name` tag value and the CIDR block, labeled.

**Hint:** there are two places you could apply the public-IP condition, and
only one of them reduces what crosses the network — check whether EC2's
filter vocabulary has a name for this attribute before you reach for
JMESPath. Pulling a tag *value* out of a list of key/value pairs is the
fiddly part: filter the tag list, index it, then take the field. Watch your
quotes when a string literal turns up inside the expression.

### D9 — How many of this project's builds failed?

Count them. A number, not a list you count by eye. Then answer the
follow-up honestly: is "failed" the same question as "did not succeed"?
Look at the actual status values your builds carry before you answer.

**Hint:** the operation that enumerates a project's builds returns IDs
only; the operation that returns status takes IDs. That is the standard
two-link chain, and running it as two commands first is the right way in.
JMESPath has a function that turns a filtered list into a count. Check the
ID-enumerating operation's help for the parameter that controls result
order, and the ID-consuming operation's help for how many IDs it accepts
per call.

---

## D10–D12 — chains and proofs

The last three are the ones worth being able to do under pressure. Each of
them answers a question that a single call cannot.

### D10 — Can Day 1's CodeBuild role actually push an image to that repository?

Not "does the policy look like it should." Establish it — get the three-way
answer the simulator gives, for `ecr:PutImage` against the foundation
repository's ARN. Find both ARNs by CLI: the role ARN from the build
project itself, the repository ARN from ECR.

Then run the same simulation a second time against a repository ARN in your
account that does not exist, and explain why the two answers differ.

**Hint:** the API is in IAM, it takes a principal ARN plus one or more
action names plus one or more resource ARNs, and it returns a decision per
action rather than a yes/no. Three values are possible and the difference
between two of them decides whether your fix is "add a permission" or "go
find what is denying it." Read Day 1's `main.tf` afterward to check your
explanation of the second result, not before.

### D11 — Which commit produced the image that is in ECR, and what is its digest?

Reconstruct the whole chain — build record → resolved commit SHA → image
tag → digest — and land on a single digest string. Do it as separate
commands first and read each result. Then compose it into one command you
could hand to someone who asked "what is in the registry and where did it
come from?"

**Hint:** the build record carries the *full* commit SHA it actually
checked out, under a field name you can find in the build object from D9.
The tag is a fixed-length prefix of that SHA — `labs/day01/buildspec.yml`
shows you exactly which transformation, and you should read it rather than
assume. Then it is D5 again. Compose with command substitution, not by
pasting values; the pasted version stops being true tomorrow.

### D12 — Prove that a named resource is genuinely absent — and say which verb told you so.

Pick three names that do not exist in your account and ask three different
services about them. You are looking for three *different* behaviors, not
three ways of seeing the same one:

1. A call that returns an **empty array at exit 0**.
2. A call that **raises a service exception** and exits non-zero.
3. A call that returns **exit 0, an empty main array, and a `failures[]`
   entry** — which is neither of the first two, and is the one that will
   cost you an afternoon if you do not know it exists.

For each, record: the exact command, the exit status (`echo $?` on the very
next line — check it, do not assume it), and the shape of what came back.
Then answer the drill's real question: **which of the three did you have to
run in order to be entitled to say "that resource is not there"?**

Then do one more, in the opposite direction: find a call against a resource
that *does* exist in `labs/day01/` which nonetheless returns an empty
array, and say why an empty array is not evidence of absence.

**Hint:** for (2), ECR is the clean example — ask it to describe images in
a repository that was never created. For (3), the one service in this
path that you have *not* created anything in — ECS — is the place to look:
its batch describes take a list of identifiers, and they report the ones they
could not find in a parallel array instead of raising. Ask an ECS batch
describe about a cluster name that does not exist in your account, then ask
an ECS operation whose `--cluster` is a *parameter* about the same name,
and notice that only one of the two errors. For the opposite-direction
case, Day 1's role has exactly one policy and there are two different
operations for listing a role's policies.

---

## Break it / Fix it

Five deliberate failures. The discipline that makes them worth twenty
minutes is one rule: **name the family before you read the fix.** Say out
loud which of the four things failed — **WHO**, **WHAT**, **WHAT CAME
BACK**, **WHAT DID I SEE** — and which of Core concept 6's four error
families the output belongs to, *then* repair it. Write both down. A
failure you diagnosed is worth ten you recovered from by retrying.

Run them in order. **Do not skip the restore steps in (b) and (c)** — they
leave a credentials file and a shell that will confuse you an hour from
now, and the confusion will not announce itself as being your own doing.

### (a) Wrong region, quietly

Take any `list-` from the drills above that you know returns results, and
run it against a region that is **enabled on your account and empty of your
resources** — `us-west-2` is the usual choice:

```bash
export AWS_REGION=us-west-2
aws ecr describe-repositories --query 'repositories[].repositoryName'
echo $?
```

The enabled part matters. An opt-in region your account has never
activated — `ap-east-1`, `me-south-1` — answers with an authentication
error instead, which is a different lesson and would spoil this one.

Nothing errors. You get an empty result and exit status 0. **Name the
family before continuing.** Then find the culprit without guessing:

```bash
aws configure list
```

Read the `region` row's `Type` and `Location`. It names the shell you are
standing in.

That was the quiet half. Now the loud one — because **a wrong region and no
region at all are two different bugs**, and only one of them has the decency
to say so.

Take the region away entirely. `unset AWS_REGION` is also the first half's
repair, so the same command closes the first bug and opens the second:

```bash
unset AWS_REGION AWS_DEFAULT_REGION
AWS_CONFIG_FILE=/dev/null aws ecr describe-repositories
echo $?
```

The `AWS_CONFIG_FILE=` prefix applies to that one command and expires with
it — nothing to restore. What it does is hide the `region` your profile
block in `~/.aws/config` would otherwise supply, so that for the length of
one invocation *no* step of the resolution chain has a region to give.
This time there is an error, immediately: the CLI tells you that
**`You must specify a region`**, and then tells you how to set one. The
exit status is non-zero; read the number your own CLI prints rather than
trusting one from this file. Write the wording down next to the empty array
from the first half.

**One caveat, the same shape as the opt-in-region one above.** This works
when your credentials come from `~/.aws/credentials` or from environment
variables. If you reach AWS through SSO, or you normally select a profile
that exists only in `~/.aws/config`, hiding that file takes your
credentials with it, and you will get a credential or profile-not-found
error instead — a different family, and the wrong lesson. If that is you,
read this half rather than forcing it.

**Now the contrast, which is why both halves live in one stage.** Same
missing piece — a region — and two opposite behaviours:

- **Wrong region:** the request *left your machine*, reached AWS, and came
  back with a truthful answer to a question you did not mean to ask. Exit
  0, empty array, no error, nothing to classify. Nothing will ever tell
  you; you have to ask.
- **No region:** the request *never left your machine*. That is the
  client-side family from Core concept 6, and the error's own wording gives
  it away — it talks about your configuration, not about anything in AWS,
  which is precisely how you know that permissions, the account, and the
  repository's existence are all off the table.

**The loud failure is the cheap one.** A bug that announces itself costs
you eight seconds; the one that returns `[]` at exit 0 costs you an
afternoon and your credibility in the meeting where you said the resource
was gone. Name the family for each before you go on.

**Restore:** the second half already did the unsetting, so what is left is
confirming it took. `unset` on a variable that is already gone is a no-op,
so run it again rather than remembering whether you did:

```bash
unset AWS_REGION AWS_DEFAULT_REGION
aws configure list
```

The `region` row must go back to whatever D2 recorded — value, `Type` and
`Location`, all three. If D2 recorded a `Type` that was not `env` and this
now reads `env`, something in your shell or your login files is still
exporting a region; find it before you go on, and re-run `aws configure
list` until the row matches D2 exactly.

### (b) A profile header with the wrong prefix

Back up the file first, because you are about to edit it by hand:

```bash
cp ~/.aws/credentials ~/.aws/credentials.bak
```

Now add a block to `~/.aws/credentials` with the **wrong** header form —
`[profile personal]` rather than `[personal]` — and try to use it:

```bash
aws sts get-caller-identity --profile personal
```

**Name the family before reading on.** The error names a missing profile.
It is not a permissions problem, it is not a region problem, and no amount
of re-authenticating will touch it. What you actually created was a profile
whose name is the literal string `profile personal`, and nothing will ever
select it.

**Restore:** put the header back to `[personal]` (or delete the block
entirely if it was only ever for this exercise), then confirm:

```bash
aws configure list --profile personal
```

If you would rather not hand-edit, restore the backup:

```bash
mv ~/.aws/credentials.bak ~/.aws/credentials
```

Either way, do not leave a half-edited credentials file behind.

### (c) A stale `AWS_PROFILE` in this shell

Export a profile that is not the one you mean, then run a command with no
`--profile` at all:

```bash
export AWS_PROFILE=personal
aws sts get-caller-identity
```

This one does not fail. That is the entire point, and it is the failure
mode worth actually fearing: it succeeds, against the wrong account,
silently, and every subsequent "the resource isn't there" you say out loud
is wrong. **Name the family**, then prove what happened:

```bash
aws configure list
```

`profile` will read `Type: env`. Compare the `Account` from
`get-caller-identity` against the one you recorded in D3 — that comparison,
not the absence of an error, is what tells you the truth.

**Restore:**

```bash
unset AWS_PROFILE
aws sts get-caller-identity --query 'Account' --output text
```

That must print D3's account ID again. If it does not, stop and fix it
before going any further; every drill answer you already recorded is under
suspicion until it does.

### (d) An expired SSO session

If you reach a company account through IAM Identity Center, let that
session lapse — come back to this stage tomorrow morning, which is the
honest version — and run any command against that profile. If you would
rather not wait, move the cached token aside:

```bash
mv ~/.aws/sso/cache ~/.aws/sso/cache.bak
aws sts get-caller-identity --profile "<YOUR_SSO_PROFILE>"
```

**Read the error before you touch anything, and write down its exact
wording.** It is a token-loading or refresh failure. It is *not*
`AccessDenied`, and the difference is the whole stage: nothing about your
permissions changed, so anyone who responds to this by re-reading an IAM
policy has mislocated the bug entirely. Name the family, then say what it
rules out.

**Restore:**

```bash
mv ~/.aws/sso/cache.bak ~/.aws/sso/cache   # only if you moved it
aws sso login --profile "<YOUR_SSO_PROFILE>"
aws sts get-caller-identity --profile "<YOUR_SSO_PROFILE>"
```

If you have no SSO profile — this path can be done entirely from a personal
account with long-lived keys — read the stage, and read F5's claim in
`content/dayA1.md` Core concept 2 about what expiry looks like, and move
on. Do not fabricate the failure by deleting keys; that produces a
different error in a different family and would teach you the wrong
association.

### (e) The truncation trap

This one needs a list long enough that your match is not near the front.
Your own resources are too few, so use the AWS-managed IAM policies —
there are hundreds of them, they cost nothing to list, and you have not
created any of them, which is what makes them honest test data.

First, establish that the list is long, and pick a real name from the far
end of it:

```bash
aws iam list-policies --scope AWS --query 'length(Policies)'
aws iam list-policies --scope AWS --query 'Policies[-1].PolicyName' --output text
```

Now go looking for that exact name — the one you proved a moment ago is in the
list — with a small cap in front of the filter:

```bash
aws iam list-policies --scope AWS --max-items 2 \
  --query "Policies[?PolicyName=='<NAME_FROM_ABOVE>'].Arn"
```

It returns `[]`. Cheerfully, at exit status 0, with nothing in the output
suggesting that only two items were ever examined. **Name which of the four
things went wrong, and in which order the two client-side steps ran**,
before you read on.

Then get the right answer — and before you reach for one, check whether the
fix you *expect* to exist actually does. The standing rule is to push the
condition into a parameter the service accepts and let the narrowing happen
before the response is built. `list-policies` offers `--scope`,
`--path-prefix` and `--only-attached`, and **not one of the three can
express an equality on `PolicyName`** — `--scope AWS` is already spent
choosing the category, and the other two filter by path and by attachment,
neither of which is a name. **This operation has no server-side name
filter.** Run `aws iam list-policies help` and find that absence yourself;
finding it is the habit, not the disappointment.

So the honest answers here are two, and neither is a server-side filter.
Drop the cap and let v2 auto-paginate the whole list, then project:

```bash
aws iam list-policies --scope AWS \
  --query "Policies[?PolicyName=='<NAME_FROM_ABOVE>'].Arn"
```

Or, once that has handed you an ARN, stop listing altogether and ask about
the one policy directly — no pagination to get wrong, because there is no
list:

```bash
aws iam get-policy --policy-arn <ARN_FROM_ABOVE> --query 'Policy.PolicyName'
```

Keep "prefer server-side narrowing" as the general rule. This command is a
case where the rule has **no implementation**, and knowing that a rule has
nowhere to land is worth as much as the rule — it is what stops you hunting
for twenty minutes for a parameter that was never there. Core concept 4 in
`content/dayA1.md`, and the decision-rule table under it, use
`--family-prefix` on `ecs list-task-definitions` as the case where the rule
genuinely applies: there the service *can* take the condition, so the
truncation bug never has to arise. Hold the two commands side by side and
you have both halves — when to push the filter down, and how to recognise
that there is nowhere to push it to.

Nothing to restore here — every command in this stage reads.

---

## Success signal

You are done when all five of these are true:

- Twelve drills answered, each with a command **you** wrote, and each
  answer written down next to the command that produced it.
- For every drill, you can say which of the four things — **WHO**,
  **WHAT**, **WHAT CAME BACK**, **WHAT DID I SEE** — you were working on,
  and for D5, D6, D8 and D9, whether the narrowing you used ran in the
  service or on your laptop.
- All five Break it stages named to a family *before* the fix was read.
- D12's three states reproduced with their exit statuses recorded, and you
  can state which verb entitles you to say a resource is absent.
- No browser was opened at any point.

Compare with `SOLUTION.md` last, not first. Then `teardown.md` in this
directory — it is short, because this lab creates nothing, but it has one
thing in it you can get wrong.
