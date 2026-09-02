# Day 1 lab — solution reference

## Expected `aws ecr describe-images` output shape

```json
[
  {
    "tag": "a1b2c3d4e5f6",
    "digest": "sha256:9f2e4b1c7a3d5f8e0b6c4a2d9e1f3b5c7a9d1e3f5b7c9a1d3e5f7b9c1a3d5e7f",
    "pushedAt": "2026-09-02T14:03:11+00:00"
  }
]
```

- `tag` is 12 hex characters — the first 12 characters of
  `CODEBUILD_RESOLVED_SOURCE_VERSION`, a real commit SHA from your repo.
  It is never `latest` and never a branch name.
- `digest` is the true identity of the pushed layers, independent of any
  tag. Two different pushes can never produce the same digest unless the
  image content is byte-identical.

## The immutability error, verbatim

Re-running a build against the same commit (so the derived tag matches an
already-pushed tag) fails `docker push` with:

```
denied: The image tag 'a1b2c3d4e5f6' already exists in the 'awsdevops-sample'
repository and cannot be overwritten because the repository is immutable.
```

CodeBuild's `post_build` phase then fails on the non-zero exit from
`docker push`, and the overall build status is `FAILED`. This is correct
behavior — the fix is never to retry the push, it's to recognize that
nothing changed and no new push was needed.

## The break-it answer

After manually pushing two different commits' images to the same mutable
tag, "which commit is running?" has no answer from the tag alone — the tag
now points at whichever image was pushed to it most recently, and that
fact is not visible from the tag string itself. You'd have to already know
the push order (from CloudTrail, from your own memory, from a deploy log)
to guess, and a guess is not the same thing as a fact you can `terraform
show` or query.

The only thing that still uniquely and verifiably identifies either image
is its **digest** — `sha256:...` — which is exactly why the tag column in
`aws ecr describe-images` is a convenience label and the digest column is
the actual answer to "what is running."

One-sentence answer for the exercise: **A mutable tag can no longer answer
"which commit is this," because the tag has become a pointer that moves
with the last push instead of a fixed name for one specific set of image
layers.**

## What you should now be able to explain

Mapped to this path's Success Criteria (see
`docs/superpowers/specs/2026-09-02-aws-devops-sre-design.md`):

- **Criterion 2 — "what code is running in production right now?"** You can
  now answer this for the image you just built: the commit SHA in the tag
  (or, once you've done the break-it exercise, only the digest is
  trustworthy once mutability is off). You can also explain *why* a
  `:latest` tag makes the question unanswerable: `:latest` is not a
  snapshot, it is a label that gets reassigned on every push, so asking
  "what does `:latest` point to" only ever answers "as of the last push,"
  never "as of right now, verifiably."
- **Criterion 3 — write a `buildspec.yml` from memory.** You've now read
  and can reproduce the shape of this one: `pre_build` derives the tag from
  `CODEBUILD_RESOLVED_SOURCE_VERSION` and logs in to ECR via stdin;
  `build` runs `docker build` with the two ldflags-driving build args;
  `post_build` pushes and captures the digest into `imageDetail.json`; and
  you can explain why caching is configured on the *project* (`main.tf`),
  not this file.
- **Criterion 12 — estimate monthly CI/CD cost.** You ran one build in this
  lab; `content/day01.md`, Exercise 2, has you compute the cost of running
  this same build 40 times a day for a month, and compare `ARM_CONTAINER`
  against x86 compute.
