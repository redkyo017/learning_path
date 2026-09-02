# Day 1 lab — produce one immutable, identifiable artifact

**Goal:** produce one immutable, identifiable artifact.

**Success signal:** an image in ECR whose tag is a commit SHA and which
cannot be overwritten.

## Prerequisites

- Day 0 done: budget alarm set, `aws sts get-caller-identity` confirms the
  right account, and you have your own copy of `app/` in a GitHub repo
  (Day 0, step 7).
- `labs/foundation/` applied and its `terraform.tfstate` present — this lab
  reads its ECR outputs via `terraform_remote_state`. If you haven't run
  `terraform apply` in `labs/foundation/` yet, do that first.

## Run steps

1. **Configure this lab.**

   ```bash
   cd labs/day01
   cp terraform.tfvars.example terraform.tfvars
   ```

   Edit `terraform.tfvars`: fill in `github_repo_url` with your own repo
   from Day 0, step 7 (`aws_region` / `name_prefix` already default to the
   values the rest of the path expects). **Never commit
   `terraform.tfvars`.**

2. **Apply.**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   If this is the first time any CodeBuild project in this account has
   used a GitHub source, the console may prompt you to finish a one-time
   GitHub authorization for CodeBuild itself (CodeBuild → Build projects →
   `awsdevops-build` → Edit → Source → Connect to GitHub). This is separate
   from the CodeConnections handshake you did in Day 0, step 4 — that one is
   for CodePipeline (Day 2), not for a standalone CodeBuild project like
   this one.

   `main.tf` loads the buildspec from the local file
   (`buildspec = file("${path.module}/buildspec.yml")`) and bakes its
   contents into the project at apply time — editing `buildspec.yml` in
   your pushed GitHub repo has no effect. To change build behavior, edit
   the local `labs/day01/buildspec.yml` and re-run `terraform apply`.

3. **Trigger a build.**

   ```bash
   aws codebuild start-build --project-name "$(terraform output -raw codebuild_project_name)"
   ```

   Watch it run:

   ```bash
   aws codebuild batch-get-builds --ids <BUILD_ID_FROM_ABOVE> \
     --query 'builds[0].{status:buildStatus,phase:currentPhase}'
   ```

   Or tail the CloudWatch Logs group directly (`terraform output
   log_group_name`) in the console.

4. **Look at what you produced.**

   ```bash
   aws ecr describe-images \
     --repository-name "$(cd ../foundation && terraform output -raw ecr_repository_name)" \
     --query 'imageDetails[*].{tag:imageTags[0],digest:imageDigest,pushedAt:imagePushedAt}'
   ```

   You should see one image, tagged with the first 12 characters of a
   commit SHA — not `latest`, not a branch name — and a `digest` field
   that starts with `sha256:`.

## Break it / Fix it

**Break it — attempt to overwrite the tag.**

Push a second image under the *same* tag the first build produced (you can
force this by re-running `aws codebuild start-build` against the same
commit — the derived tag will be identical, since it comes from the
resolved source version, not a timestamp):

```bash
aws codebuild start-build --project-name "$(terraform output -raw codebuild_project_name)"
```

If the source commit hasn't changed, the second build's `docker push` fails
with an `ImageTagAlreadyExistsException` — the foundation stack's ECR
repository was created with `image_tag_mutability = "IMMUTABLE"`. That
failure is the feature working as intended, not a bug to route around.

**Fix it — now break immutability on purpose, and watch what you lose.**

1. Temporarily set the foundation repository's tag mutability to
   `MUTABLE` (console: ECR → repository → Edit → Image tag mutability, or
   `aws ecr put-image-tag-mutability --repository-name <repo> --image-tag-mutability MUTABLE`
   — do **not** change this in `labs/foundation/main.tf`; this is a
   deliberate, temporary, out-of-band change you'll undo).
2. Make a trivial change to `app/main.go` in your repo (e.g. bump a comment)
   and commit it as a *second* commit.
3. Manually tag and push both commits' images under the tag `w` (a stand-in
   tag both pushes will share) using the AWS CLI + Docker directly — or,
   simpler, `docker tag` the two images this lab already built with two
   different digests to the same tag and push both.
4. Now ask: **which commit is running?** The tag alone can no longer answer
   that — it points at whichever image was pushed to it most recently,
   silently. The only thing that still uniquely identifies either image is
   its digest, which is why Day 2's pipeline and Day 3's deploy stage will
   consume digests, never tags.
5. Put tag mutability back to `IMMUTABLE` before moving on.

Write down, in one sentence, what question a mutable tag can no longer
answer. Compare your answer with `SOLUTION.md`.

## Reference

`SOLUTION.md` in this directory has the expected command output shapes, the
exact immutability error text, and a checklist of what you should now be
able to explain.
