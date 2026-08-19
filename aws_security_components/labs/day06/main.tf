# ---------------------------------------------------------------------------
# Day 6 — Edge protection I (WAF)
#
# Layers a REGIONAL WAFv2 Web ACL on top of labs/base's ALB. See
# content/day06-waf-edge.md "Core concepts > Scope" for why REGIONAL (not
# CLOUDFRONT) was chosen for this lab. Reads base's ALB ARN via remote
# state — never edits labs/base.
#
# NOT applied by the author of this module: Terraform is not installed in
# this environment. This file is validated by manual HCL review against
# the aws_wafv2_web_acl / aws_wafv2_web_acl_association /
# aws_wafv2_web_acl_logging_configuration schema (AWS provider >= 5.0),
# not by `terraform validate` or `terraform apply`. See SOLUTION.md for the
# review notes.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../base/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project}-day06"

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "day06"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# CloudWatch Logs destination for the Web ACL. The "aws-waf-logs-" prefix
# on the log group name is not a style choice — AWS enforces it, and
# rejects any other name for a WAF log destination. This specific naming
# convention is also what lets WAF write to the log group without a
# separate CloudWatch Logs resource policy (WAF's one exception to the
# usual cross-service logging permission dance).
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# ---------------------------------------------------------------------------
# The Web ACL itself.
#
# Rule priority 1: AWS Managed Common Rule Set — broad coverage (XSS,
#   generic LFI/RFI, oversized bodies, the EC2MetaDataSSRF_* sub-rules that
#   double as a compensating control against this same app's /fetch SSRF
#   hole). override_action = none means "respect each sub-rule's own
#   action" (mostly Block), EXCEPT GenericRFI_QUERYARGUMENTS, which is
#   overridden to Count — see the false-positive note below.
#
# Rule priority 2: AWS Managed SQL Injection Rule Set — dedicated,
#   narrower SQLi detection, layered on top of (not a replacement for) the
#   Common Rule Set's own SQLi-adjacent coverage.
#
# Rule priority 3: a rate-based rule, no scope_down_statement (counts every
#   request to the ALB, not just one path — contrast with exercise 1's
#   /login-scoped version in content/day06-waf-edge.md).
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "day06" {
  name        = "${local.name_prefix}-webacl"
  description = "Day 6 lab: managed Common+SQLi rule groups + a rate-based rule, in front of labs/base's ALB."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-common-rules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # FALSE-POSITIVE TUNE (see content "Core concepts > Count vs Block",
        # README.md "THE TUNE", and SOLUTION.md): GenericRFI_QUERYARGUMENTS
        # matches scheme:// patterns (http://, https://, ftp://) in
        # query-string values — which is exactly what this app's own
        # /fetch?url=<target> passes on every single legitimate call, not
        # just malicious ones. var.tune_generic_rfi_false_positive defaults
        # to false so your first apply reproduces this false positive
        # (legit /fetch calls 403 too); flip it to true and re-apply to fix
        # it by overriding this ONE sub-rule to Count — not by disabling
        # the whole managed group.
        dynamic "rule_action_override" {
          for_each = var.tune_generic_rfi_false_positive ? [1] : []
          content {
            name = "GenericRFI_QUERYARGUMENTS"
            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-common-rules"
    }
  }

  rule {
    name     = "aws-sqli-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-sqli-rules"
    }
  }

  rule {
    name     = "rate-limit-all"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                  = var.rate_limit
        evaluation_window_sec  = var.rate_evaluation_window_sec
        aggregate_key_type     = "IP"
        # NOTE (see content exercise 3): no forwarded_ip_config here, so
        # this counts by whoever calls the ALB DIRECTLY. Test against
        # alb_dns_name, not the CloudFront domain, or every viewer's
        # requests will be pooled onto CloudFront's shared edge IPs and
        # this rule will never trip on a single client's traffic.
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.name_prefix}-rate-limit"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${local.name_prefix}-webacl"
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Attach the Web ACL to the base ALB (REGIONAL scope attaches via a
# separate association resource — CLOUDFRONT scope would instead set
# web_acl_id directly on the distribution; see content "Scope" section).
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "day06" {
  resource_arn = data.terraform_remote_state.base.outputs.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.day06.arn
}

# ---------------------------------------------------------------------------
# Ship every inspected request's decision to CloudWatch Logs so a false
# positive is a log query, not a guess.
# ---------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "day06" {
  resource_arn            = aws_wafv2_web_acl.day06.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}
