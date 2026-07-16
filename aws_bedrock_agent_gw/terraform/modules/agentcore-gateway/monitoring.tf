# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "gateway_ops" {
  dashboard_name = "${var.name_prefix}-gateway-ops"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Agent Invocations (5 min)"
          metrics = [["AWS/Bedrock", "AgentInvocations", "AgentId", aws_bedrockagent_agent.this.agent_id]]
          period  = 300
          stat    = "Sum"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Input Token Count"
          metrics = [["AWS/Bedrock", "AgentInputTokenCount", "AgentId", aws_bedrockagent_agent.this.agent_id]]
          period  = 300
          stat    = "Sum"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "P99 Latency (ms)"
          metrics = [["AWS/Bedrock", "AgentInvocationLatency", "AgentId", aws_bedrockagent_agent.this.agent_id]]
          period  = 300
          stat    = "p99"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      }
    ]
  })
}

# ── CloudWatch Alarms (only when alarm_sns_arn is provided) ───────────────────

resource "aws_cloudwatch_metric_alarm" "invocation_errors" {
  count = var.alarm_sns_arn != "" ? 1 : 0

  alarm_name          = "${var.name_prefix}-invocation-errors"
  alarm_description   = "AgentCore Gateway invocation errors — investigate immediately"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "AgentInvocations"
  namespace           = "AWS/Bedrock"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_sns_arn]

  dimensions = {
    AgentId = aws_bedrockagent_agent.this.agent_id
  }
}

resource "aws_cloudwatch_metric_alarm" "latency_p99" {
  count = var.alarm_sns_arn != "" ? 1 : 0

  alarm_name          = "${var.name_prefix}-latency-p99"
  alarm_description   = "AgentCore Gateway P99 latency exceeded 10 seconds"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "AgentInvocationLatency"
  namespace           = "AWS/Bedrock"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 10000
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_sns_arn]

  dimensions = {
    AgentId = aws_bedrockagent_agent.this.agent_id
  }
}

# ── Billing Alarm (only when monthly_cost_threshold_usd > 0) ─────────────────
# Billing metrics are only available in us-east-1 regardless of resource region.

resource "aws_cloudwatch_metric_alarm" "monthly_cost" {
  count = var.monthly_cost_threshold_usd > 0 ? 1 : 0

  alarm_name          = "${var.name_prefix}-bedrock-monthly-budget"
  alarm_description   = "Bedrock monthly charges exceeded ${var.monthly_cost_threshold_usd} USD"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400
  statistic           = "Maximum"
  threshold           = var.monthly_cost_threshold_usd
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  dimensions = {
    ServiceName = "AmazonBedrock"
  }
}
