# GitHub Actions -> AWS trust, via OIDC federation. No long-lived AWS access
# keys anywhere in this file, and none should ever exist in a GitHub secret
# for this workflow — that is the entire point of everything below.
#
# The trust chain: GitHub issues a short-lived OIDC token to the Actions
# job -> AWS STS validates that token's signature against the IAM OIDC
# identity provider registered here -> if the trust policy's conditions
# match the token's claims, STS's AssumeRoleWithWebIdentity call returns
# temporary credentials (default 1h). The credential is minted per job run
# and expires on its own; there is nothing sitting in a secrets store for
# an attacker (or a departing contractor's laptop) to still have.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # thumbprint_list deliberately omitted. AWS validates OIDC providers like
  # GitHub's (and Auth0, GitLab, Google, and any IdP backed by an
  # Amazon-trusted root CA) against its own library of trusted certificate
  # authorities, not against a thumbprint you supply — and since AWS
  # provider v5.81 this argument is Optional here, so there is nothing to
  # paste in. If you ever do need to pin one by hand for a non-well-known
  # IdP, fetch it yourself and verify it against the provider's own
  # documentation rather than copying a value out of a tutorial (this one
  # included) — a stale, copy-pasted thumbprint is worse than none, because
  # it looks authoritative while proving nothing.
}

# --- The role GitHub Actions assumes --------------------------------------

resource "aws_iam_role" "gha_oidc" {
  name = "${var.name_prefix}-gha-oidc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          # StringEquals on BOTH claims — this is the correctly scoped
          # version. aud proves the token was minted for AWS STS
          # specifically. sub proves it came from exactly one repo and
          # exactly one branch, in the ref:refs/heads/<branch> form.
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# # DO NOT USE — this is the Break-it exercise.
# #
# # Two dangerous variants of the trust policy above. Both are commented out
# # on purpose. The lab's Break-it step has you swap the block above for one
# # of these, `terraform apply`, reason about (without performing) what a
# # fork's pull request could now reach, then restore the correct block.
# #
# # Variant A: StringLike + a repo-wide wildcard. This matches every branch,
# # every pull_request-triggered workflow run, and every tag in the repo —
# # including refs an outside contributor can create just by opening a PR.
# #
# # resource "aws_iam_role" "gha_oidc_wildcard_sub" {
# #   name = "${var.name_prefix}-gha-oidc"
# #
# #   assume_role_policy = jsonencode({
# #     Version = "2012-10-17"
# #     Statement = [
# #       {
# #         Effect    = "Allow"
# #         Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
# #         Action    = "sts:AssumeRoleWithWebIdentity"
# #         Condition = {
# #           StringLike = {
# #             "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
# #             "token.actions.githubusercontent.com:sub" = "repo:${var.github_owner}/${var.github_repo}:*"
# #           }
# #         }
# #       }
# #     ]
# #   })
# # }
#
# # Variant B: missing the :sub condition entirely (not :aud — see below for
# # why :aud alone isn't the dangerous one to drop). With no :sub condition
# # at all, the trust policy only checks that the token's audience is
# # sts.amazonaws.com — which every GitHub Actions job in every repo on
# # every GitHub account can obtain simply by requesting an OIDC token
# # scoped to that audience. This role's IAM OIDC provider
# # (aws_iam_openid_connect_provider.github_actions) trusts the *issuer*
# # token.actions.githubusercontent.com — GitHub's shared token issuer for
# # every repo on GitHub, not just yours — so a trust policy that checks
# # :aud and nothing else would let a workflow run in a repo you have never
# # heard of assume this role, provided the attacker can discover (or guess)
# # the role's ARN.
# #
# # (Dropping :aud instead and keeping :sub, by contrast, is not the same
# # kind of hole in this lab: the OIDC provider's client_id_list above is
# # already pinned to ["sts.amazonaws.com"], so AWS itself rejects a token
# # presenting any other audience before the trust policy's Condition block
# # is ever evaluated. Omitting :aud from the trust policy is still worth
# # doing as defense-in-depth — belt-and-braces against a future edit that
# # adds a second entry to client_id_list — but by itself it does not open
# # the door to another audience the way it might look like it should.)
# #
# # resource "aws_iam_role" "gha_oidc_missing_sub" {
# #   name = "${var.name_prefix}-gha-oidc"
# #
# #   assume_role_policy = jsonencode({
# #     Version = "2012-10-17"
# #     Statement = [
# #       {
# #         Effect    = "Allow"
# #         Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
# #         Action    = "sts:AssumeRoleWithWebIdentity"
# #         Condition = {
# #           StringEquals = {
# #             "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
# #           }
# #         }
# #       }
# #     ]
# #   })
# # }
# ---------------------------------------------------------------------------

# --- Minimal permissions: ECR push to the foundation repo, nothing else --

resource "aws_iam_role_policy" "gha_oidc_ecr_push" {
  name = "${var.name_prefix}-gha-oidc-ecr-push"
  role = aws_iam_role.gha_oidc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ecr:GetAuthorizationToken has no resource-level permissions in
        # IAM — it must be granted against "*". This is an AWS API
        # limitation, not a scoping mistake; every other action below is
        # scoped tightly to the one repo this role should ever touch.
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "EcrPushToFoundationRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = [data.terraform_remote_state.foundation.outputs.ecr_repository_arn]
      },
    ]
  })
}
