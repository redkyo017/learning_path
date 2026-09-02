# Day 0 — Pre-flight (~30 minutes)

Do this before Day 1. It is not part of the ~17h scheduled path — it's the
one-time setup that makes the rest of the path safe (budget alarm) and
possible (GitHub connection). Nothing here is billable except the budget
alarm itself, which has no cost.

- [ ] **1. Confirm you're in the right AWS account.**

  ```bash
  aws sts get-caller-identity
  ```

  Check the `Account` and `Arn` in the output match the personal account you
  intend to use for this path — not a work account, not an account you
  share with someone else's infrastructure.

- [ ] **2. Create a $10/month AWS Budget with alerts at 50% / 80% / 100%.**

  This is the single most important step on this page. Do it before
  anything else on this checklist.

  **Console path:** Billing and Cost Management → Budgets → Create budget →
  Use a template → Monthly cost budget → set the amount to `10` USD → add
  an email alert at 50%, 80%, and 100% of budgeted amount → enter your
  email address → Create budget.

  **Equivalent CLI**, if you prefer scripting it (replace the account ID
  placeholder and your own email):

  ```bash
  cat > budget.json <<'EOF'
  {
    "BudgetName": "awsdevops-path-monthly",
    "BudgetLimit": { "Amount": "10", "Unit": "USD" },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }
  EOF

  cat > notifications.json <<'EOF'
  [
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 50,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [
        { "SubscriptionType": "EMAIL", "Address": "<YOUR_EMAIL>" }
      ]
    },
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 80,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [
        { "SubscriptionType": "EMAIL", "Address": "<YOUR_EMAIL>" }
      ]
    },
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 100,
        "ThresholdType": "PERCENTAGE"
      },
      "Subscribers": [
        { "SubscriptionType": "EMAIL", "Address": "<YOUR_EMAIL>" }
      ]
    }
  ]
  EOF

  # 123456789012 below is an obvious placeholder — use your own account ID.
  aws budgets create-budget \
    --account-id 123456789012 \
    --budget file://budget.json \
    --notifications-with-subscribers file://notifications.json
  ```

  This alarm is meant to survive the whole path (and beyond) — there is no
  teardown step for it anywhere in this path.

- [ ] **3. Set and confirm your region.**

  ```bash
  aws configure set region us-east-1   # or your preferred region
  aws configure get region
  ```

  This path defaults every lab's `aws_region` variable to `us-east-1`. Any
  region works, but pick one and use it consistently — mixing regions
  across labs breaks `terraform_remote_state` lookups between them.

- [ ] **4. Create the CodeConnections → GitHub connection.**

  **Console path:** Developer Tools → Settings → Connections → Create
  connection → GitHub → give it a name → Connect to GitHub → authorize the
  AWS Connector for GitHub app in the browser popup → Connect.

  This step is console-only and cannot be fully scripted: the underlying
  handshake is an OAuth authorization between AWS and GitHub that requires
  a logged-in browser session to approve. The CLI can *create* a connection
  resource, but it starts in `PENDING` state and only reaches `AVAILABLE`
  once you complete the browser authorization — there is no CLI-only path
  around that.

  ```bash
  aws codeconnections create-connection \
    --provider-type GitHub \
    --connection-name awsdevops-github
  ```

  Check its status until it flips from `PENDING` to `AVAILABLE`:

  ```bash
  aws codeconnections list-connections \
    --query "Connections[?ConnectionName=='awsdevops-github']"
  ```

  Record the connection ARN — Day 2's Terraform needs it as an input
  variable. It looks like
  `arn:aws:codeconnections:us-east-1:123456789012:connection/<uuid>`.

- [ ] **5. Authorize CodeBuild for GitHub — this is separate from CodeConnections.**

  The CodeConnections connection you just created in step 4 does not cover
  this. It's an easy thing to miss because both live under the same
  "Developer Tools" console umbrella and look like the same GitHub
  handshake — but they serve two different services by default.
  CodeConnections is what CodePipeline uses (Day 2). Day 1's lab creates a
  standalone CodeBuild project with a plain `GITHUB` source type rather
  than a CodeConnections source, and a `GITHUB` source needs its own,
  separate one-time GitHub authorization at the account level — the
  CodeConnections connection from step 4 does not cover it. (CodeBuild can
  also be configured to use CodeConnections for a GitHub source, but this
  lab doesn't use that path, so it doesn't help you here.)

  You have two options:

  - Authorize CodeBuild for GitHub once, in the console: CodeBuild → Build
    projects → (any project) → Edit → Source → Connect to GitHub →
    authorize in the browser popup. Terraform will prompt you to finish
    this the first time you `apply` a CodeBuild project with a GitHub
    source, if you haven't done it already.
  - Or skip the authorization entirely by keeping your copy of the sample
    repo (step 7, below) public — a public GitHub repository needs no
    credential for CodeBuild to clone it.

  To be clear about which is used where: CodeBuild's GitHub authorization
  (this step) is what Day 1 needs; the CodeConnections connection from step
  4 is what Day 2 needs. Doing both now means neither day surprises you.

- [ ] **6. Note: CodeCommit is not an option here.**

  AWS closed CodeCommit to new customers in **July 2024** — if you're
  starting fresh today, you cannot create a CodeCommit repository. If you
  find a tutorial elsewhere that opens with `git push codecommit`, stop
  reading it; it predates that change and won't work for a new account.
  This is exactly why this path uses GitHub via CodeConnections instead.

- [ ] **7. Create your own copy of the sample app repo.**

  **Required layout: `app/` must sit at the ROOT of this new repository.**
  `labs/day01/buildspec.yml` uses `app/` as the Docker build context,
  `labs/day02/main.tf` filters pipeline triggers on `app/**`, and the
  GitHub Actions example builds `app/` — all three assume `app/` is a
  top-level directory. Do **not** fork the whole `learning_path` repo: if
  you do, `app/` ends up nested at `aws_devops_sre/app/` and every one of
  those breaks. Instead, create a new, empty GitHub repository under your
  own account and copy the contents of `aws_devops_sre/app/` from this
  path into its root (so the new repo's `app/` directory sits directly
  under the repo root). Record the repo as
  `<YOUR_GITHUB_USERNAME>/<YOUR_REPO>` — Day 1's CodeBuild project and
  Day 2's pipeline source stage both reference it.

- [ ] **8. Check tool versions.**

  ```bash
  terraform version   # need >= 1.5
  aws --version        # need v2
  docker info          # confirms the Docker daemon is running
  kind version          # Day 4 only, but check now
  go version            # need 1.23+
  ```

- [ ] **9. Set up `labs/foundation/terraform.tfvars`.**

  ```bash
  cd labs/foundation
  cp terraform.tfvars.example terraform.tfvars
  ```

  Open `terraform.tfvars` and fill in `aws_region` and `name_prefix` (the
  examples default to `us-east-1` and `awsdevops`). **Never commit
  `terraform.tfvars`** — it's where your real, personal values live even
  though this path's values are not secret, and it's the file where a
  future edit might accidentally introduce one. Add this line to your
  repo's `.gitignore` if it isn't already covered:

  ```gitignore
  terraform.tfvars
  ```

Once all nine boxes are checked, you're ready for
[`content/day01.md`](../../content/day01.md).
