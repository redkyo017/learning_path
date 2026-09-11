# Day A1 — INTERROGATE: what is actually there?

**Appendix:** AWS CLI mastery (depends on Days 1–3)
**Time:** ~3.4h (content ~70m · lab ~110m · break/fix ~20m · teardown ~5m)
**Cost if you follow teardown:** ~$0.02

## Why this matters

Across five days this path has handed you roughly 46 distinct command
shapes — `aws ecr describe-images`, `aws ecs update-service`, `aws deploy
get-deployment`, `aws logs tail`, and the rest — with every argument
already filled in. You have run all of them and written none of them. That
is a real gap, and it shows up at exactly the wrong moment: Day 1
(`content/day01.md`) argued that "what is in prod right now?" has one
honest answer, a digest, but answering it *in the account, on a Tuesday,
with someone waiting* means composing the command yourself against
infrastructure whose names you were not given in advance. The target for
today is narrow and testable: **turn an English question about an AWS
account into the command that answers it** — without a web search, without
the console, and without pattern-matching on a command you were once
shown.

## The question of the day

**What is actually there, and how do I know the answer isn't lying to me?**

## Core concepts

### 1. Every invocation is four things

Not "the CLI has a lot of commands." Every single `aws` invocation you will
ever type, without exception, is four things stacked in order:

| | The question | Where it goes wrong |
|---|---|---|
| **WHO** | Which identity resolved, in which region? | credential provider chain, profile file syntax, env-var precedence, expired SSO token |
| **WHAT** | Which API operation, with which parameters? | service model, `list-` vs `describe-` vs `get-`, required-vs-optional shape |
| **WHAT CAME BACK** | What did the API actually return? | pagination, **server-side** filters, empty result vs thrown error |
| **WHAT DID I SEE** | What did I choose to display? | `--query '<expr>'` (**client-side**), `--output`, the pager |

Memorize the four labels in that order. The rest of this day is one
subsection per label, and the lab is graded against them.

**The payoff is diagnostic**, and it is the entire reason for the framing.
Nearly every CLI frustration in the field is a *mislocation* — you are
debugging the wrong one of the four:

- **"The command returned nothing"** is two different bugs. Either the API
  genuinely returned an empty result (**WHAT CAME BACK** — wrong region,
  wrong account, resource really is gone), or the API returned a full
  response and your projection matched nothing in it (**WHAT DID I SEE** —
  a typo in a field name, a case mismatch in a filter expression). The fix
  for one does nothing for the other, and you cannot tell them apart by
  staring harder at the empty screen. You tell them apart by deleting the
  projection and looking at the raw response.
- **"Access denied"** is two different bugs. Either the wrong identity
  resolved (**WHO** — a stale `AWS_PROFILE` in this shell, a profile header
  typo, the personal account instead of the company one), or the right
  identity resolved and genuinely lacks the permission (still **WHO**, but
  a different half of it — and the fix is a policy change, not a shell
  fix). One command separates them, and it is not the one that failed.

A learner who reaches for the four-way split first stops guessing. Someone
who does not has only one move — retry with a slightly different command —
and that move has no ordering, so it can take all afternoon.

### 2. WHO — identity resolution

Two independent questions hide inside **WHO**: which credentials resolved,
and which region resolved. They have separate resolution chains, they fail
differently, and conflating them is why "it worked yesterday" is such a
common and such a useless bug report.

**The credential provider chain, in documented precedence order:**

1. Command-line options — `--profile`, `--region`
2. Environment variables
3. Assume-role / web-identity configuration from config
4. IAM Identity Center (SSO)
5. `~/.aws/credentials`
6. `~/.aws/config`
7. Container credentials
8. EC2 instance metadata

Read that list once, then stop trusting it. Not because it is wrong — it is
the documented order — but because *your* laptop has a specific state, and
the whole skill being taught today is preferring a local fact over a
remembered rule. **Confirm locally with `aws configure list`.**

`aws configure list` prints **Name / Value / Type / Location** for each
resolved setting. The `Value` column is the least interesting one. The
**Type** and **Location** columns are the point, because they show *where
each value came from*:

```
$ aws configure list
      Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key     ****************ABCD  shared-credentials-file
secret_key     ****************WXYZ  shared-credentials-file
    region                us-east-1      config-file    ~/.aws/config
```

Read that as a sentence: *no profile was named, credentials came from the
credentials file, region came from the config file*. Now compare it to what
you believed was happening. Most identity bugs are visible in that
comparison and in nothing else — an `env` variable you exported in this
tab three hours ago shows up as `Type: env`, and there is no arguing with
it.

**Profile headers are a common silent failure.** The two
files use different header syntax, and the CLI does not warn you when you
get it wrong — the profile does not exist as far as the CLI is
concerned:

- `~/.aws/config` requires `[profile NAME]` — with the prefix.
- `~/.aws/credentials` requires `[NAME]` — with **no** prefix.
- `[default]` takes no prefix in either file.

```ini
# ~/.aws/config
[default]
region = us-east-1

[profile company]
region = us-east-1
```

```ini
# ~/.aws/credentials   <- no "profile " prefix here, ever
[default]
aws_access_key_id = <YOUR_ACCESS_KEY_ID>

[personal]
aws_access_key_id = <YOUR_ACCESS_KEY_ID>
```

(The matching `aws_secret_access_key` line lives directly under the same
header in that file. It is not written out here for the obvious reason.)

Write `[profile personal]` into `~/.aws/credentials` and you have created a
profile literally named `profile personal`, which nothing will ever select.
This is responsible for a large share of every "my profile isn't being
picked up" report you will ever read or file.

**Ground truth is one command:** `aws sts get-caller-identity` returns
`UserId`, `Account`, and `Arn`. It is the answer to "who am I" that cannot
be argued with, and it requires no permissions beyond being authenticated —
which means it works even when the identity you resolved is allowed to do
nothing else at all. Run it before any command you would regret running
against the wrong account, and run it first when a command fails in a way
that smells like permissions.

**Region is a separate chain**, and it fails in a nastier way. The shape is
the same — the `--region` command-line option, then the environment
(`AWS_REGION`, `AWS_DEFAULT_REGION`), then the profile's `region` setting
in `~/.aws/config` — but rather than take that ordering on faith, read the
`region` row of `aws configure list` and its `Type`/`Location` columns,
which is the whole reason that command exists.

The reason to treat region as its own chain: **"no region" and "wrong
region" are different bugs, and the second one is worse, because it
succeeds.** No region at all produces a loud, immediate error telling you a
region must be specified. The *wrong* region produces a perfectly valid,
perfectly empty, perfectly confident answer — an empty `list-clusters`
array at exit 0, or an `aws ecs describe-clusters` that returns exit 0 with
an empty `clusters` array and a `failures[]` entry reading `MISSING`, for a
cluster that exists and is healthy 3,000 miles away. Nothing about that
output says "you asked the wrong continent." Only **WHO** can tell you, and
only if you look.

#### SSO — the company-account path

This is how you reach the company account, so it is not optional
background.

`aws configure sso` writes two blocks into `~/.aws/config`: an
`[sso-session NAME]` block and a `[profile NAME]` block. The session block
is the shareable half — several profiles (several accounts, several roles)
can reference one `sso-session`, which is why you log in once and reach
more than one account.

Written out, the pair looks like this — `aws configure sso` produces it
for you interactively, and the `[sso-session]` half is the block the other
profiles point at:

```ini
# ~/.aws/config
[sso-session company]
sso_start_url = https://<YOUR_SSO_PORTAL>.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access

[profile company]
sso_session = company
sso_account_id = 123456789012
sso_role_name = <YOUR_PERMISSION_SET_NAME>
region = us-east-1
output = json
```

Two regions appear there and they are not the same thing: `sso_region` is
where the Identity Center directory itself lives, and the profile's
`region` is where *your commands* go. A second profile for a second
account is another `[profile ...]` block with the same
`sso_session = company` line and a different `sso_account_id` /
`sso_role_name`.

`aws sso login --profile NAME` refreshes the session. The resulting tokens
are cached under `~/.aws/sso/cache/`.

**The fact worth internalizing:** expiry surfaces as a token-loading or
refresh error, **not** as `AccessDenied`. An expired SSO token does not
mean your permissions changed, and if you respond to it by re-reading an
IAM policy you are debugging the wrong thing entirely. Expiry is a **WHO**
problem in the credentials-and-expiry family (Core concept 6); `AccessDenied`
is a **WHO** problem in the authorization family. Same label, different
half, different fix, and the error text tells you which — if you read it
instead of skimming it.

#### Long-lived keys — the personal-account path

This is how you reach your personal account: an IAM user's access key ID
and secret access key sitting in `~/.aws/credentials` under a bare
`[personal]` header, resolving at step 5 of the chain.

It works, it is the simplest thing that works, and it is worth being
honest about what it costs. `STRATEGY.md` already names **"Long-lived IAM
access keys in CI"** as one of this path's traps — the credential outlives
the engineer who created it. Point that same sentence at your own laptop
and nothing about it softens: the key in your home directory has no expiry,
survives a stolen laptop, survives you changing jobs, and is readable by
every process running as you. The mitigations are the ordinary ones —
scope the IAM user narrowly, rotate deliberately, never let the file leave
the machine, and know the key ID well enough to recognize it in
CloudTrail — but the honest framing is that the SSO path is
structurally safer and the personal-account path is a convenience you are
choosing with your eyes open. Knowing *which* of the two resolved, at any
given moment, is the entire subject of this subsection.

### 3. WHAT — the operation

**The AWS CLI is generated from service models.** The commands, the
parameter names, the accepted shapes, and the help text are all produced
from the same machine-readable description of the API that the SDKs are
built from. That is why `aws ecs describe-services help` outranks a blog
post, and it is not a matter of taste: the help text was generated from
the model the CLI you are holding actually implements, and the blog post
describes what some other version did on the day it was written. Build the
reflex now — the local help page is the primary source, not the fallback.

Three levels, all local, all instant:

```bash
aws help                     # every service
aws ecs help                 # every operation in one service
aws ecs describe-services help   # one operation: every parameter, every shape
```

**`--generate-cli-skeleton` is a shape-discovery tool**, not only an
input-file generator. It emits the input shape for an operation — every
field, correctly nested, with placeholder values:

```bash
aws ecs update-service --generate-cli-skeleton
```

The companion is `--cli-input-json file://input.json`, which consumes that
same shape back. Both are available across services. Use the pair for what
they are worth in this INTERROGATE day: the skeleton answers "what does
this operation even accept?" faster than reading paragraphs of help text,
because it shows you the structure rather than describing it.

For interactive discovery there is also `--cli-auto-prompt` (and
`--no-cli-auto-prompt`, and the config key `cli_auto_prompt`), which
controls v2's interactive parameter prompting. It is a good way to walk an
unfamiliar operation once. It is a bad thing to depend on, for the same
reason the console is: it does not leave you with a command you can paste
into a runbook.

**The `list-` / `describe-` / `get-` heuristic:**

| Prefix | What it returns | Typical use |
|---|---|---|
| `list-` | Identifiers and summaries — often only ARNs or names | Find out *what exists* when you don't know the names |
| `describe-` | Full objects, usually several at once | Get the *detail* for names you already have |
| `get-` | A single object or value | Fetch one specific thing you can already name |

It is a naming convention, not a law the service models enforce — but it
holds often enough to be worth reaching for first, and when it does not
hold, `aws <service> help` settles it in two seconds.

**The consequence that matters: the argument to a `describe-` usually
comes out of a `list-`.** That is the basic chain shape, and it is how you
interrogate an account whose contents you were not told in advance:

```bash
# 1. What clusters exist at all?
aws ecs list-clusters --query 'clusterArns' --output text

# 2. Feed one of those back in for the detail.
aws ecs describe-clusters --clusters "<CLUSTER_ARN_FROM_STEP_1>"
```

One caveat on that second command, because it bites early: ECS's batch
describes are a special case that returns exit 0 with a `failures[]` array
instead of raising when an identifier is not found — Core concept 6 explains
why that matters and what to check.

Almost every real question you will answer today or in the lab is two or
three of those links long. Get comfortable running them as separate
commands first and reading each result — composing them into one line is a
convenience you earn later, not a starting position.

### 4. WHAT CAME BACK — the response

Here is the highest-leverage fact in this appendix, and one that is easy
to have backwards after years of using the CLI:

> **`--filters` is the API. `--query 'Field'` is your laptop.**

`--query 'Reservations[].Instances[].InstanceId'` is **client-side**
JMESPath, evaluated after the full response has already been received.
Server-side filtering is an entirely different mechanism: `--filters` (EC2
and friends), `--filter`, or a service's own named parameters (things like
`--cluster`, `--repository-name`, `--status-filter` — parameters the
operation itself defines).

| | Server-side filtering | Client-side projection |
|---|---|---|
| Written as | `--filters`, `--filter`, service-specific named parameters | `--query 'Field'` |
| Where it runs | In the service, before the response is built | On your machine, after the whole response has arrived |
| Reduces API calls? | Yes — fewer results means fewer pages | **No** |
| Reduces bytes over the network? | Yes | **No** |
| Helps with throttling? | Yes | **No** |
| Vocabulary | Whatever that one API defines, and nothing else | Full JMESPath, identical across every service |

Three consequences follow directly, and each one is a bug you can ship:

1. **No reduction in API calls or throttling.** A projection that displays
   three instances out of nine hundred still fetched all nine hundred, in
   however many paginated calls that took. If you are being throttled, a
   client-side projection will not save you; only a server-side filter
   (or fewer calls) will.
2. **No reduction in transfer.** The full response crossed the network
   before a single character of the projection was evaluated. On a large
   account this is the difference between a command that returns in a
   second and one that sits there — and no amount of projection tuning
   changes it.
3. **Silently wrong answers when combined with pagination limits.** This is
   the one that costs you credibility rather than time. See the truncation
   trap below.

**Pagination in v2**, which is the other half of "what came back":

- **CLI v2 auto-paginates by default.** A `list-` that would take four API
  calls to enumerate makes four API calls and hands you one merged result.
  This is v2 behavior and it is why a v1 habit of manually looping on
  `NextToken` reads as dated.
- **`--page-size`** sets the per-request API page size. It changes how many
  items each underlying call asks for; it does not change how many items
  you end up with.
- **`--max-items`** is a **client-side** cap. It stops the output at N
  items and emits a continuation token in the output so you can resume.
- **`--no-paginate`** issues exactly one API call — whatever came back in
  that first page is all you get.

**The truncation trap, stated plainly:** `--max-items` plus a projection
filters *what was already cut off*. The cap is applied first, then your
JMESPath runs against the truncated set.

```bash
# WRONG, and wrong quietly:
aws ecs list-task-definitions --max-items 10 \
  --query "taskDefinitionArns[?contains(@, 'awsdevops-cli')]"
```

If the account has 400 task definitions and the ones you care about are
number 300 and up, that command returns `[]` — an empty array, no error,
no warning, no hint that it only ever looked at ten items. You will read
that as "there are none" and be wrong in front of people. If you must cap
and filter at the same time, cap *after* you have understood the shape of
the full result, and prefer a server-side filter — a `--family-prefix`, a
`--status`, whichever named parameter the operation actually offers — over
capping at all.

### 5. WHAT DID I SEE — the projection

Everything in this subsection happens on your laptop, after the bytes
arrived. Nothing here can change what the API did.

**Quoting first, because on `zsh` nothing else works.**

> In `zsh`, an unquoted bracket expression such as `[?Name=='x']` is a glob
> pattern, and it fails with `zsh: no matches found`. **Quote the entire
> `--query 'EXPR'` argument** — always, every time, including the
> expressions that look too simple to need it.
>
> **Prefer single quotes.** When the JMESPath itself contains a
> single-quoted string literal, put double quotes on the outside instead:
> `--query "services[?status=='ACTIVE'].serviceName"`. Both forms suppress
> globbing, which is the hazard.

Why there are two forms at all: shell single quotes do not nest. Written as
`--query 'services[?status=='ACTIVE'].serviceName'`, that is not one
argument with a literal inside it — the shell reads it as three fragments
glued together, and the brackets end up *unquoted*, which drops you straight
back into the glob failure above. Moving the outer quotes to double is the
ordinary fix, and it is the form you will meet in AWS's own documentation
and in `labs/day00/README.md`.

**One alternative, and one trap inside it.** JMESPath also accepts a JSON
literal in backticks: `` [?Status==`"ACTIVE"`] `` means exactly what
`[?Status=='ACTIVE']` means, and it is what you use if you want to keep the
outer single quotes. Never put that form inside double quotes — a backtick
inside double quotes is command substitution, so your shell will try to run
`"ACTIVE"` as a command before the CLI ever sees it. The same goes for any
`$` in an expression. Bare backtick or `$` inside double quotes: never.

**The JMESPath worth memorizing.** This is a small language and this is
most of it:

| Construct | Example | What it does |
|---|---|---|
| Projection | `--query 'Reservations[].Instances[].InstanceId'` | Walk into every element of every list and collect one field |
| Filter expression | `--query "services[?status=='ACTIVE'].serviceName"` | Keep only elements matching a condition |
| Multiselect list | `--query 'imageDetails[].[imageDigest,imagePushedAt]'` | Emit an ordered *list* per element |
| Multiselect hash | `--query 'services[].{Name:serviceName,Running:runningCount}'` | Emit a *named object* per element |
| `length` | `--query 'length(taskDefinitionArns)'` | Count without eyeballing |
| `sort_by` | `--query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]'` | Sort by a field, then index (`[-1]` = newest) |
| `join` | `--query "join(', ', clusterArns)"` | Collapse a list into one delimited string |
| `contains` | `--query "taskDefinitionArns[?contains(@, 'awsdevops')]"` | Substring match; `@` is the current element |
| `starts_with` | `--query "services[?starts_with(serviceName, 'awsdevops-cli')]"` | Prefix match |
| Pipe expression | `--query 'services[].serviceName \| length(@)'` | Run the left side, then feed the result to the right |
| Flatten | `--query 'Reservations[].Instances[]'` | `[]` flattens nested lists into one list |

Two notes that save real time. The multiselect **hash** is what you want
whenever a human will read the output — it labels the columns, so nobody
has to count fields. And `[-1]` after a `sort_by` is the whole "most
recent" idiom; you almost never need to sort descending.

**Output formats.** `--output` accepts `json`, `text`, `table`, `yaml`, and
`yaml-stream`.

| Format | Good for |
|---|---|
| `json` | The default, and the only sane input to `jq` or another program |
| `text` | Feeding one or two scalars into a shell variable |
| `table` | Reading with your eyes, once, in a terminal |
| `yaml` / `yaml-stream` | Human-readable structure; streaming large results |

**Precisely when `text` is a trap:** `text` is tab-separated with nested
structures flattened, which is why positional `cut`/`awk` against it is
fragile. The moment your projection returns more than one field per row —
or returns a field that is itself a list, or a field that can be absent —
the column your `cut -f3` reads is decided by data you do not control. It
will be right on the row you tested and wrong on the row that matters.

The rule that keeps you out of it: `--output text` is safe when the
projection returns **exactly one scalar**, and suspect otherwise.

```bash
# Fine: one scalar, nothing to miscount.
aws ecr describe-images --repository-name <REPO> \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
  --output text

# Not fine: three fields, one of which is a list that may be empty.
# The cut -f2 that works today breaks on the first image with no tags.
```

If you need several fields in a script, take `json` and parse it as JSON.
Never `grep` a JSON document for a value — you are one nested key with the
same name away from a confidently wrong answer, and a projection that
names the exact path costs you the same keystrokes.

**The pager.** CLI v2 sends output through a pager by default. Disable it
with `--no-cli-pager` (or by setting `cli_pager` to empty). This is
required in anything non-interactive — a script, a CI step, a command whose
output you are capturing — because a pager waiting for a keypress in a
context with no keyboard is a hang, not an error, and it is a genuinely
confusing one to diagnose the first time.

### 6. Reading errors as a decision tree

An AWS CLI error is not a wall. It is a signal that tells you which of the
four things failed, and therefore which three you can stop investigating.
Four families:

| Family | What it looks like | What it rules out | Next command |
|---|---|---|---|
| **Client-side validation** | `Unknown options: --clustre`, `Invalid choice: 'describe-service'`, `Parameter validation failed: Unknown parameter in input` | Everything on the AWS side. The request **never left the machine** — so stop checking permissions, stop checking the region, stop re-logging-in | `aws <service> <operation> help`, or `--generate-cli-skeleton` for the shape |
| **Authorization** | `AccessDenied`, `AccessDeniedException`, `UnauthorizedOperation` | Identity *resolution*. The credentials were valid and an identity was established, or you'd have a different error — so **stop re-checking your profile** | `aws sts get-caller-identity` to record the exact ARN, then `aws iam simulate-principal-policy` against it |
| **Credential and expiry** | `ExpiredToken`, an SSO token-loading/refresh error, `InvalidClientTokenId`, `Unable to locate credentials` | The operation and its parameters. You never got far enough for them to matter | `aws configure list` to see what resolved; `aws sso login --profile <NAME>` if it is an expired SSO session |
| **Not found vs. empty** | Three states, not two: a raised exception (ECR's `RepositoryNotFoundException`); a silent `[]` from any `list-`; or — on ECS's batch describes — **exit 0, an empty main array, and a `failures[]` entry whose `reason` is `MISSING`** | Nothing yet. This is the family that most often means *wrong region* or *wrong account* rather than *missing resource* | Read `failures[]` before believing an ECS describe; re-run as the other verb (the matching `list-`) if you got an exception; `aws configure list` for the region in all three cases |

**Authorization, in detail (this is where people waste the most time).**
`AccessDenied` means the identity resolved *fine*. Re-checking your profile
is the wrong instinct; the useful move is to establish exactly what that
identity can do, rather than reading a policy document hopefully:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/<ROLE_NAME> \
  --action-names ecr:PutImage \
  --resource-arns "arn:aws:ecr:us-east-1:123456789012:repository/<REPO>"
```

It returns an `EvalDecision` per action, one of `allowed`, `implicitDeny`,
or `explicitDeny`. That three-way answer is more useful than a yes/no,
because `implicitDeny` ("nothing grants this") and `explicitDeny`
("something actively forbids this") have completely different fixes —
add a permission, versus find and argue with the SCP or boundary that is
denying it.

For EC2 specifically there is one more probe worth knowing, with a sharp
limit: `--dry-run` is an **authorization probe, not a simulation**.
`DryRunOperation` means the call would have been permitted;
`UnauthorizedOperation` means it would not. It says nothing whatsoever
about whether the change is correct or wise, and most services do not
support it at all.

**Credential and expiry, in detail.** The distinction to hold: an
`ExpiredToken` (or an SSO token-loading/refresh error) means you *had*
valid credentials and they aged out — `aws sso login --profile <NAME>` and
carry on. A wrong or deleted key is a different error, and no amount of
re-logging-in fixes it. And per Core concept 2: SSO expiry does **not**
surface as `AccessDenied`, so if you are seeing `AccessDenied` you are in
the authorization family and should be running the simulator, not
re-authenticating.

**Not found versus empty, in detail — and it is three states, not two.**
"Nothing came back" has three distinct causes, and they do not look alike
once you know what to check:

1. **`list-*` returns an empty array, at exit 0.** Nothing matched, and the
   API is telling you so successfully.
2. **Some `describe-*` operations raise a service exception** when the
   resource you named does not exist. ECR's `RepositoryNotFoundException`
   is the clean example — ask for a repository that is not there and you
   get an error, loudly, on stderr.
3. **ECS's batch describes do neither.** `describe-clusters`,
   `describe-services`, and `describe-tasks` return **exit 0**, with the
   items they found in the main array and a parallel **`failures[]`** array
   carrying `{arn, reason: "MISSING"}` for every identifier they could not
   find. `aws ecs describe-clusters --clusters nope` gives you
   `{"clusters": [], "failures": [...]}` — not an error, not a warning, not
   a non-zero exit.

`ClusterNotFoundException` is real, and it is worth knowing exactly where it
comes from: operations whose `--cluster` *parameter* names a cluster that
does not exist — `describe-services`, `list-services`, `list-tasks`. It is
never what `describe-clusters --clusters` gives you; that call reports the
same absence in `failures[]` instead.

The consequence, spelled out: **"no output" means something different for
each of the three, and on an ECS batch describe an empty main array is not
evidence of absence — exit 0 does not mean "found."** Check `failures[]`
before you conclude anything from an ECS describe. From a `list-`, an empty
array is a real answer about the account. From a `describe-` that raises,
silence should be impossible; if you see it, something upstream swallowed
the exception (a `2>/dev/null` in a script, a pipeline that discarded
stderr) and you are reading silence as data. And in all three cases, the
answer is only as good as the **WHO** that produced it — an empty result
from the wrong region looks exactly like an empty result from the right one.

**When all four families fail you: `--debug`.** It writes an enormous
trace to stderr, and roughly all of it is `botocore` narrating itself.
Capture it and grep for exactly three things:

```bash
aws ecs list-clusters --debug --no-cli-pager 2>/tmp/aws-debug.log
```

1. **Which credential provider actually supplied the credentials** — grep
   case-insensitively for `credential`. This is `aws configure list` with
   receipts, and it settles **WHO** absolutely.
2. **The endpoint the request went to** — grep for `endpoint`. The host
   name carries the region, which settles the other half of **WHO** and
   catches the wrong-region-succeeds-quietly bug from Core concept 2.
3. **The response status and the request ID** — grep for `status` and for
   `requestid`. The AWS request ID is the first thing support will ask you
   for.

Grep for the *concept*, case-insensitively, not for a literal line: the
exact wording of botocore's trace shifts between versions, and a grep
pinned to today's phrasing is a grep that silently stops matching after
your next upgrade.

## Decision rules

| When you see... | Choose... | Because |
|---|---|---|
| A question about an account whose resource names you were not given | A `list-` operation first | It returns identifiers without requiring you to already know one, which is the only way in when you know nothing |
| A name or ARN in hand and a question about its detail | `describe-` (or `get-` when the answer is a single object) | Summaries omit most of the object; the detail only exists in the fuller response |
| A condition the operation itself accepts — `--family-prefix`, `--status`, `--filters` | The server-side parameter | The narrowing happens before the response is built, so fewer calls are made and fewer bytes cross the network |
| A condition no API parameter can express | A client-side `--query 'EXPR'` over the full result | It is the only mechanism left — and knowing that means you also know you paid full API and transfer cost for the answer |
| A projection that returns exactly one scalar, feeding a shell variable | `--output text` | There is one field, so there is nothing for a positional read to miscount |
| A projection returning several fields, or any field that can be absent or a list | `--output json` and a real JSON parse | `text` flattens nesting into tabs, so the column a positional read lands on is decided by the data, not by you |
| `Unknown options`, `Invalid choice`, or `Parameter validation failed` | `aws <service> <operation> help`, or `--generate-cli-skeleton` | The request never left your machine, so nothing on the AWS side can be the cause |
| `AccessDenied` immediately after `aws sts get-caller-identity` succeeded | `aws iam simulate-principal-policy` against that exact ARN | The identity is established and known; the open question is what that principal is permitted to do, which the simulator answers as `allowed` / `implicitDeny` / `explicitDeny` |
| An empty array where you expected results | `aws configure list`, then re-run without the projection | Region, account, and projection all produce identical-looking emptiness, and only the resolved settings distinguish them |
| An exploratory command against a list that might be enormous | `--no-paginate` | It issues exactly one API call, so the command is bounded in time and calls while you are still learning the shape |

## Lab

See `labs/dayA1/`. **Goal:** answer a graded question set about
infrastructure you built yourself, by CLI only — the console is forbidden
for the duration. **Success signal:** every drill answered with a command
you could reconstruct tomorrow, from the four-way split, without looking it
up.

## Break it / Fix it

Five deliberate failures, and the discipline that makes them worth the
twenty minutes: **name the family before you read the fix.** Say out loud
which of the four things failed — **WHO**, **WHAT**, **WHAT CAME BACK**,
**WHAT DID I SEE** — and which family from Core concept 6 the error belongs
to, *then* repair it. A failure you diagnosed is worth ten you merely
recovered from.

**(a) Wrong region, quietly — then no region at all, loudly.** Run a
`list-` you know returns results, with
`AWS_REGION=us-west-2` (or any other region that is **enabled** on your
account but empty of your resources). The enabled part matters: an opt-in
region such as `ap-east-1` or `me-south-1` that your account has not
activated answers with an authentication error instead, which is a
different lesson and would spoil this one. Against an enabled, empty
region nothing errors — you get an empty array and exit status 0, which is
the whole point. This is the "succeeds while lying" bug from
Core concept 2, and `aws configure list` is what exposes it — the `region`
row will show `Type: env`, pointing straight at the shell you are standing
in. Then do it the other way: `unset AWS_REGION AWS_DEFAULT_REGION` and run
the same command with nothing left to supply a region, and it fails
immediately with `You must specify a region`. That contrast is the stage —
one resolution chain, one silent failure and one loud one, and the silent
one is the expensive half.

**(b) A profile header with the wrong prefix.** Write `[profile personal]`
into `~/.aws/credentials` (rather than `[personal]`) and try to use it. The
error names a missing profile, not a permissions problem. Credential family,
**WHO** — and the fix is one word, once you know which file takes the prefix.

**(c) A stale `AWS_PROFILE` in this shell.** Export a profile that is not
the one you mean, then run a command with no `--profile`. It succeeds
against the wrong account, which is the failure mode worth fearing.
`aws sts get-caller-identity` is the only honest witness; `aws configure
list` then shows `Type: env` and names the culprit.

**(d) An expired SSO session.** Let the company-account session lapse (or
come back to it tomorrow) and run any command. Read the error carefully
before touching anything: it is a token-loading/refresh failure, **not**
`AccessDenied`. Anyone who responds to this by re-reading an IAM policy has
mislocated the bug, and this is the stage that inoculates you against it.

**(e) The truncation trap.** Run a filter you know matches, with
`--max-items 2` in front of it, against a list long enough that your matches
are not in the first two. It returns `[]`, cheerfully, with exit status 0.
Nothing in the output hints that only two items were ever examined —
**WHAT CAME BACK** was truncated before **WHAT DID I SEE** ever ran.

Full steps, the exact commands, and the restore instructions for (a)–(d)
are in `labs/dayA1/README.md`. Do not skip the restore: (b) and (c) leave a
shell and a credentials file that will confuse you an hour later.

## Exercises

1. `An error occurred (UnauthorizedOperation) when calling the RunInstances operation`
   — name the family, say what it rules out, and give the next command.

   **Hint:** Does this error prove an identity was established, or does it
   leave that open?

   **Solution sketch:** Authorization family. It rules out identity
   *resolution* — credentials were valid and a principal was established,
   so re-checking your profile is wasted motion. Next:
   `aws sts get-caller-identity` to capture the exact ARN, then
   `aws iam simulate-principal-policy --policy-source-arn <THAT_ARN> --action-names ec2:RunInstances --resource-arns '*'`
   and read the `EvalDecision` — `implicitDeny` means nothing grants it,
   `explicitDeny` means something actively forbids it, and those have
   different fixes.

2. `Parameter validation failed: Unknown parameter in input: "clusterName", must be one of: cluster, services, include`
   — name the family and say precisely what you can stop investigating.

   **Hint:** Where was this error generated — in the service, or before
   anything was sent?

   **Solution sketch:** Client-side validation. The request never left your
   machine, so permissions, region, account, credential expiry, and the
   resource's existence are all irrelevant to this failure and all off the
   table. Next command is `aws ecs describe-services help` (or
   `--generate-cli-skeleton` for the input shape); the real fix is
   `--cluster`, not `--clusterName`.

3. Your shell has `AWS_PROFILE=personal` exported, `~/.aws/config` contains
   `[profile company]`, and you run
   `aws sts get-caller-identity --profile company`. Which identity
   resolves, and what single command proves it?

   **Hint:** Walk the documented precedence order from the top and stop at
   the first thing that matches.

   **Solution sketch:** The command-line option wins — it is step 1 of the
   chain, above environment variables at step 2 — so the `company` profile
   resolves and `AWS_PROFILE` is ignored for this invocation. Prove it with
   `aws configure list`, which shows `profile` with `Type: manual` (the
   command line) rather than `Type: env`; `aws sts get-caller-identity`
   then confirms the resulting `Account` and `Arn`.

4. A teammate pastes `[profile personal]` into `~/.aws/credentials`, then
   runs `aws s3 ls --profile personal` and gets a profile-not-found error.
   Explain exactly what they created.

   **Hint:** Which of the two files takes the `profile ` prefix, and which
   one refuses it?

   **Solution sketch:** `~/.aws/credentials` headers take **no** prefix —
   it is `[personal]` there, and `[profile personal]` in `~/.aws/config`.
   They created a profile whose name is the literal string
   `profile personal`, which nothing will ever select. `[default]` takes no
   prefix in either file. This one typo is behind a large share of all "my
   profile isn't being picked up" reports.

5. `aws sso login --profile company` succeeded this morning; this afternoon
   commands fail. Your colleague says "your IAM policy must have changed."
   Say why that is probably wrong, and what you would run.

   **Hint:** What does SSO expiry actually look like in the output, and
   what does it deliberately *not* look like?

   **Solution sketch:** Expiry surfaces as a token-loading/refresh error,
   **not** as `AccessDenied` — so if the error is a token error, no policy
   changed and the credential-and-expiry family is the right one.
   `aws sso login --profile company` re-establishes the session (cached
   tokens live under `~/.aws/sso/cache/`). Only if the error genuinely
   reads `AccessDenied` is this an authorization problem, and then the move
   is `simulate-principal-policy`, not another login.

6. Write the expression that answers "what tag is on the most recently
   pushed image in this repository?"

   **Hint:** You need a sort by push time, an index from the end, and the
   first tag of whatever you land on.

   **Solution sketch:**
   `aws ecr describe-images --repository-name <REPO> --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text`
   — `sort_by` with an `&field` expression reference, `[-1]` for the newest
   element, then the first tag. `--output text` is safe here because the
   projection returns exactly one scalar; the whole argument is
   single-quoted because `zsh` would otherwise treat the brackets as a
   glob.

7. Write the expression that answers "which services in this cluster are
   not `ACTIVE`, and how many running tasks does each have?", labeled so a
   human can read it.

   **Hint:** A filter expression narrows the list; a multiselect hash names
   the fields. Think about which quote character has to go on the outside
   once the expression contains a single-quoted literal.

   **Solution sketch:**
   `aws ecs describe-services --cluster <CLUSTER> --services <NAMES> --query "services[?status!='ACTIVE'].{Name:serviceName,Status:status,Running:runningCount}"`
   — double quotes on the outside, because single quotes do not nest and
   the string literal `'ACTIVE'` needs them; the double quotes still stop
   `zsh` from globbing the brackets. Keep `--output json` or `table`; a
   multiselect hash is exactly the case where `--output text` invites a
   positional-parsing bug.

8. `aws ecs list-task-definitions --max-items 10 --query "taskDefinitionArns[?contains(@, 'awsdevops-cli')]"`
   returns `[]` in an account that definitely has those task definitions.
   Explain the bug in terms of the four-way split.

   **Hint:** Which runs first — the client-side cap, or the client-side
   projection?

   **Solution sketch:** **WHAT CAME BACK** was truncated to 10 items before
   **WHAT DID I SEE** ever ran, so the filter searched a 10-item sample of
   a much larger list and honestly reported no matches. `--max-items` is a
   client-side cap that emits a continuation token; the projection is
   applied after it. The empty array is not a fact about the account. Drop
   `--max-items`, or better, use a server-side named parameter such as
   `--family-prefix` so the *service* does the narrowing and the response
   you paginate is the one you actually wanted.

## Anti-patterns / Common mistakes

- **Believing `--query 'length(Reservations)'` reduces API load.** It does
  not, and the belief is expensive precisely because it feels like
  optimization. A client-side projection runs after the entire response has
  crossed the network — it cannot reduce API calls, cannot reduce transfer,
  and cannot help you with throttling. When you actually need less data to
  come back, you need a server-side filter (`--filters`, `--filter`, or the
  operation's own named parameters), and if the API does not offer one for
  your condition, then it does not offer one — no projection will
  substitute for it.
- **Parsing `--output text` positionally in a script.** `text` is
  tab-separated with nested structures flattened, so the field your `cut
  -f3` lands on is determined by data you do not control: an absent field,
  an empty list, or a second tag shifts every column after it. It works on
  the row you tested and breaks on the row that matters, usually at the
  worst time. One scalar out, or take JSON and parse it as JSON.
- **`grep`-ing JSON instead of querying it.** `grep imageDigest` finds
  every line containing that string at any depth, including the one inside
  a nested structure you did not mean, and it silently returns nothing when
  the field is nested one level deeper than you assumed. A projection names
  the exact path, costs about the same keystrokes, and fails loudly instead
  of quietly.
- **Reaching for the console the moment output looks unfamiliar.** The
  console will answer today's question and teach you nothing transferable —
  and it will do it under a different identity resolution than your
  terminal, which means it can show you a resource your CLI genuinely
  cannot see and leave you more confused, not less. When output surprises
  you, the next move is `aws sts get-caller-identity` and `aws configure
  list`, not a browser tab.
- **Reading an empty result as proof a resource is gone.** An empty array
  from a `list-` is a claim about one account in one region as seen by one
  identity — it is not a claim about the world. Wrong region, wrong
  account, or a projection that matched nothing all produce output
  indistinguishable from genuine absence. Before you tell anyone a resource
  does not exist, confirm **WHO** you were and re-run without the
  projection.
- **Trusting a remembered precedence order over `aws configure list`.** The
  documented chain is correct and your specific shell is a fact; when they
  disagree, the shell wins. Exported environment variables from three hours
  ago are a common reason a command that "worked yesterday" does not, and
  the `Type` and `Location` columns find them in one line.

## Teardown

**This day creates nothing.** Every command in it reads, and the lab
queries infrastructure that already exists, so there is nothing new to
destroy and no meter this day started.

Two things to check anyway, because the lab may have you re-apply a stack
you tore down earlier in the week:

- **Leave `labs/foundation/` standing.** It is meant to survive the week,
  and Day A2 expects it.
- **If you re-applied `labs/day01/` for this lab, destroy it again** per
  its own `labs/day01/teardown.md` — including the CodeBuild
  auto-created-log-group edge case that file calls out.

Then confirm rather than assume, which is the habit this whole day is
about:

```bash
bash labs/verify-teardown.sh
```

## Self-check

1. A command that returned three clusters last week returns an empty array
   today, exits 0, and prints no warning. Explain why "someone deleted them"
   is only one of at least three explanations, and how you would eliminate
   the other two before you say anything out loud.
2. A colleague sees `AccessDenied` and tells you your profile must be wrong.
   Explain precisely why that advice is backwards — what the error has
   already proved, and what it leaves open — and what a three-way
   `allowed` / `implicitDeny` / `explicitDeny` answer would tell you that a
   yes/no answer would not.
3. A script narrows a long list with a filter expression and caps the output
   at the same time. Explain why it can return a confidently wrong answer
   without ever failing, and why moving the same condition into a parameter
   the API itself accepts changes that.

If any of these is unanswerable without flipping back to a specific section,
that section is the one to re-read — 1 points at Core concepts 2 and 6
(region as its own chain, and not-found versus empty), 2 at Core concept 6
and Exercise 1, and 3 at Core concept 4 and Exercise 8.
