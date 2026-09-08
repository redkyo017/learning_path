# Day 7 teardown

Every other day in this path can be left running indefinitely at no
cost — `stop` the containers or leave them up, it doesn't matter. Day 7 is
the only day where skipping teardown, or delaying it, has a real financial
consequence: a `db.t4g.micro` Multi-AZ RDS instance and an Atlas M10
cluster both bill by the hour whether or not you're using them, and
neither shuts itself off. Do this the same day you run the lab, not at
the end of the week.

## 1. Destroy the Terraform-managed AWS resources

```bash
cd labs/day07/terraform
terraform destroy
```

Confirm the plan actually lists `aws_db_instance.dbm_lab_pg`,
`aws_db_parameter_group.dbm_lab_pg16`, `aws_db_subnet_group.dbm_lab`, and
`aws_security_group.dbm_lab_pg` for destruction before you type `yes` —
if the plan is empty, you're either in the wrong directory or state has
already been destroyed once. `skip_final_snapshot = true` in `rds.tf`
means this step leaves no final snapshot behind to bill for afterward
(see that file's cost comment) — there is no extra "also delete the
snapshot" step to remember.

`terraform.tfstate` holds `db_password` in plaintext (Terraform needs it
there to detect drift) — `labs/day07/terraform/.gitignore` keeps it out
of a commit, but destroying the infrastructure doesn't delete the file
itself. Once `terraform destroy` finishes and you have no further use for
this state, delete it (`rm -f terraform.tfstate terraform.tfstate.backup`)
rather than leaving a plaintext copy of a real password sitting on disk
indefinitely.

## 2. Terminate the Atlas cluster

In the Atlas UI: the `dbm-lab` cluster's `...` menu → **Terminate**.
Confirm the cluster name in the dialog matches `dbm-lab` before
confirming — Atlas does not undo this, and it shouldn't need to, since
nothing in this lab wrote data anywhere that survives the cluster itself.

## 3. Delete the Atlas project, if you created one for this

If you created a dedicated project for this lab (rather than reusing an
existing one), delete the project too, once the cluster inside it is
gone — an empty Atlas project costs nothing on its own, but deleting it
removes the database user and IP access-list entry you added in
`atlas-setup.md` along with it, rather than leaving those around as stale
configuration in a project you don't otherwise use.

## 4. Run the teardown verifier

```bash
bash labs/verify-teardown.sh
```

This needs the AWS CLI installed and configured with valid credentials on
whatever machine runs it — it exits `2`, not `0`, if it can't actually
check (see that script's own header comment); a `2` here means "go
configure the CLI and run this again," not "you're clean." The Atlas
cluster check inside it is skipped, with a clear message, if the Atlas CLI
isn't installed — confirm that half manually in the Atlas UI (project
page, no clusters listed) if you don't have the CLI.

**Require a clean run — exit `0` — before you consider Day 7 closed.**
`labs/day07/verify.sh` already calls this same script and propagates its
exit status as its own final step, so passing Day 7's lab and confirming
teardown are, by construction, the same event: you cannot get a `0` from
`verify.sh` while an RDS instance or Atlas cluster from this lab is still
running.
