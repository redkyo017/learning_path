# payment-notifier (toy internal service)

A small internal service that polls an orders queue and sends a Slack/email
notification when a payment posts. This `sample-repo/` is a **planted, static
lab fixture** for Day 10 — it is not a real product and is not a git
repository (no `.git/` here on purpose; see `../README.md` for why). Every
secret in these files is fake/example data, but shaped exactly like the real
thing so `gitleaks`/`trufflehog` detect it the same way they'd detect a real
leak.

## Layout

- `.env` — local dev environment variables (AWS creds, DB connection string).
- `config/fake_srts.yml` — app config someone "temporarily" hardcoded and never
  moved.
- `deploy/notes.txt` — a scratch file an engineer left with a shared admin
  password, never deleted.
- `requirements.txt` / `src/app.py` — the actual (tiny) application, with two
  outdated, real-CVE dependency pins planted on purpose.
- `Dockerfile` — builds the app image; this is what `trivy`/`grype` scan.

## Known issue tracker (fictional, for flavor)

- TODO: rotate the AWS key in `.env` before this goes anywhere near prod.
- TODO: move `config/fake_srts.yml` to a real secrets manager.
- TODO: bump PyYAML, we're still on an ancient pin.
