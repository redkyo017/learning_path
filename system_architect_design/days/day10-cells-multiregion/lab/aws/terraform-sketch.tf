#############################################################################
# Day 10 — AWS cell-based architecture SKETCH (optional cloud rep).
#
# This is a *sketch*, not a turnkey module: it shows the SHAPE of 2 isolated
# cells behind a thin router (an ALB), with the minimum resources so you can
# reproduce the containment experiment and then DESTROY everything.
#
# TODOs you must fill for your sandbox (marked  # TODO):
#   - vpc_id / subnet_ids (use your default VPC's public subnets, or make one)
#   - ami (an Amazon Linux 2023 AMI id in ap-southeast-1)
#   - the echo user_data (below) assumes Go isn't installed; it runs a tiny
#     inline HTTP responder per cell so you can see which cell answered.
#
# Router thinness note: the ALB IS the thin router here — path/host rules map a
# tenant to a target group. Real cells would each have their OWN db/cache; this
# sketch keeps only compute to stay at the $1-3 cost target. TEAR DOWN after.
#############################################################################

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "ap-southeast-1" # TODO: match your sandbox
}

locals {
  project = "day10-cells"
  cells   = ["cell-a", "cell-b"]
}

variable "vpc_id" {} # TODO
variable "subnet_ids" { type = list(string) } # TODO: >= 2 public subnets (multi-AZ)
variable "ami" { default = "" } # TODO: Amazon Linux 2023 AMI id

# ---- The thin router: one ALB shared by both cells -------------------------
resource "aws_security_group" "router" {
  name   = "${local.project}-router"
  vpc_id = var.vpc_id
  ingress { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0,  to_port = 0,  protocol = "-1",  cidr_blocks = ["0.0.0.0/0"] }
  tags = { Project = local.project }
}

resource "aws_lb" "router" {
  name               = "${local.project}-router"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.router.id]
  subnets            = var.subnet_ids
  tags               = { Project = local.project }
}

# ---- Two isolated cells: one target group + one instance each --------------
resource "aws_lb_target_group" "cell" {
  for_each = toset(local.cells)
  name     = "${local.project}-${each.key}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check { path = "/health", healthy_threshold = 2, interval = 10 }
  tags = { Project = local.project, Cell = each.key }
}

resource "aws_instance" "cell" {
  for_each      = toset(local.cells)
  ami           = var.ami # TODO
  instance_type = "t3.micro"
  subnet_id     = var.subnet_ids[0]
  tags          = { Project = local.project, Cell = each.key, Name = "${local.project}-${each.key}" }

  # Minimal per-cell responder so you can see which cell answered.
  user_data = <<-EOT
    #!/bin/bash
    cat > /home/ec2-user/serve.py <<'PY'
    from http.server import BaseHTTPRequestHandler, HTTPServer
    CELL = "${each.key}"
    class H(BaseHTTPRequestHandler):
      def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(f"done by {CELL}\n".encode())
    HTTPServer(("", 8080), H).serve_forever()
    PY
    nohup python3 /home/ec2-user/serve.py &
  EOT
}

resource "aws_lb_target_group_attachment" "cell" {
  for_each         = toset(local.cells)
  target_group_arn = aws_lb_target_group.cell[each.key].arn
  target_id        = aws_instance.cell[each.key].id
  port             = 8080
}

# ---- Router rules: map a "tenant" to a cell -------------------------------
# Simplest thin routing: path prefix as the tenant proxy (/a/* -> cell-a).
# In production this would be a hash(tenant)->cell at the edge; the containment
# behaviour is identical.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.router.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cell["cell-a"].arn
  }
}

resource "aws_lb_listener_rule" "cell_b" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action { type = "forward", target_group_arn = aws_lb_target_group.cell["cell-b"].arn }
  condition { path_pattern { values = ["/b/*"] } }
}

output "router_dns" { value = aws_lb.router.dns_name }
# Test:   curl http://$(terraform output -raw router_dns)/a/   # -> done by cell-a
#         curl http://$(terraform output -raw router_dns)/b/   # -> done by cell-b
# BREAK:  stop cell-a's instance -> its target group goes unhealthy ->
#         /a/ returns 503 while /b/ stays 200. Containment proven. Then destroy.
