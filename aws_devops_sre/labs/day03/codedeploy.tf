# --- Deployment control: CodeDeploy app/group, rollback alarm -----------

resource "aws_codedeploy_app" "this" {
  name             = "${var.name_prefix}-app"
  compute_platform = "ECS"
}

# The rollback trigger. This alarm is what catches a task that STARTS
# healthy (passes the ALB health check on /readyz) but then SERVES errors —
# exactly what CodeDeploy's own health-check gate cannot see, because that
# gate (like the ECS deployment circuit breaker it's often confused with —
# see content/day03.md Core concept 5) only watches task startup and
# health checks, never response content. See Break it / Fix it stage (b)
# in README.md.
#
# period=60 / evaluation_periods=1 / threshold=5 means: 5 or more 5XX
# responses from ANY target behind this ALB inside a single 60-second
# window trips the alarm. This is a deliberately generous threshold for a
# lab with real (if light) traffic. Exercise 2 in content/day03.md walks
# through why this exact math falls apart at 2 requests/minute, and what
# the honest trade-off looks like at that volume.
resource "aws_cloudwatch_metric_alarm" "rollback" {
  alarm_name          = "${var.name_prefix}-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5

  # notBreaching, not "missing": with no traffic in a given 60s window,
  # CloudWatch has no datapoint for that period. "missing" would leave the
  # alarm's state exactly where it last was — on a low-traffic service that
  # can mean an alarm that never transitions to ALARM at all, because it
  # never sees enough consecutive breaching datapoints. "notBreaching"
  # treats a quiet period as healthy, which is the honest reading of
  # silence for a 5XX *count* metric. See Exercise 2, content/day03.md.
  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
  }

  alarm_description = "5+ ALB target 5XXs in 60s. Wired as a CodeDeploy BLUE_GREEN rollback trigger."

  tags = {
    Name = "${var.name_prefix}-5xx"
  }
}

resource "aws_iam_role" "codedeploy" {
  name = "${var.name_prefix}-codedeploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name_prefix}-codedeploy"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_group_name  = "${var.name_prefix}-group"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.this.name
    service_name = aws_ecs_service.this.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.rollback.alarm_name]
  }
}
