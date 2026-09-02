# --- Network edge: security groups, ALB, target groups, listener --------
#
# CodeDeploy blue/green needs TWO target groups behind ONE listener: it
# stands up a replacement ("green") task set, registers it with the green
# target group, shifts listener traffic to it according to the deployment
# config (Canary10Percent5Minutes here — see codedeploy.tf), and on success
# makes green the new blue. Terraform creates both target groups and the
# listener once; after the first deployment, CodeDeploy owns which target
# group the listener actually forwards to.

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "ALB: inbound HTTP from the internet, outbound anywhere."
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

resource "aws_security_group" "tasks" {
  name        = "${var.name_prefix}-tasks"
  description = "Fargate tasks: inbound 8080 from the ALB security group only, outbound anywhere."
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id

  ingress {
    description     = "App port 8080, from the ALB's security group only — not from 0.0.0.0/0"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound (ECR image pulls, CloudWatch Logs — no NAT gateway needed, see ecs.tf)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-tasks"
  }
}

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.terraform_remote_state.foundation.outputs.public_subnet_ids

  # No deletion protection, no access-log bucket: this is a lab-lifetime
  # ALB torn down at the end of the session (teardown.md), not a
  # production edge that needs to survive a fat-fingered destroy.

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

# Two target groups. At rest, "blue" holds the currently-live task set and
# "green" is empty. During a deployment, CodeDeploy stands up a new task
# set in "green", shifts a percentage of listener traffic to it, and — on
# success — blue and green swap roles for the next deployment. Both target
# groups exist at all times; which one is "live" is a runtime fact, not a
# Terraform fact.
resource "aws_lb_target_group" "blue" {
  name        = "${var.name_prefix}-tg-blue"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id
  target_type = "ip" # required target type for awsvpc-networked Fargate tasks

  health_check {
    path                = "/readyz"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # /readyz, not /healthz — this is the health check that decides whether a
  # task set gets traffic during a deployment, so it must ask the traffic
  # question, not the process question:
  #   /healthz = liveness = "is the process alive?"  -> always 200 in this app
  #   /readyz  = readiness = "should this instance receive traffic?" -> 503
  #              when POISON=true
  # Pointed at /healthz, this health check would happily certify a poisoned
  # task as healthy, because /healthz doesn't know POISON exists. That is
  # exactly the failure Break it / Fix it stage (a) in README.md is built
  # to demonstrate.

  tags = {
    Name = "${var.name_prefix}-tg-blue"
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${var.name_prefix}-tg-green"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.foundation.outputs.vpc_id
  target_type = "ip"

  health_check {
    path                = "/readyz"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.name_prefix}-tg-green"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  lifecycle {
    # CodeDeploy rewrites this listener's default_action outside Terraform
    # every time it shifts traffic between blue and green during a
    # deployment (and again at deployment end). Without ignore_changes
    # here, the next `terraform apply` would see the listener pointed at
    # whichever target group CodeDeploy left it on and "fix" it back to
    # blue — fighting a deployment that is in progress, or silently
    # undoing one that just completed.
    ignore_changes = [default_action]
  }

  tags = {
    Name = "${var.name_prefix}-http"
  }
}
