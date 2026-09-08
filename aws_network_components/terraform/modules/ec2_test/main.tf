# Always-current Amazon Linux 2023 AMI - no hardcoded AMI IDs to rot.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "ssm" {
  name = "${var.name}-ec2-test-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name}-ec2-test-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_security_group" "test" {
  name        = "${var.name}-ec2-test-sg"
  description = "Lab test instances - all traffic from the lab CIDR, all egress"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-ec2-test-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "from_lab" {
  security_group_id = aws_security_group.test.id
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.test.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "this" {
  count                  = length(var.subnet_ids)
  ami                    = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_ids[count.index]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  vpc_security_group_ids = concat([aws_security_group.test.id], var.extra_sg_ids)

  # An echo server on 8080 so every connectivity test in this course has
  # something real to connect to, plus dig/nc for the DNS and TCP labs.
  user_data = <<-USERDATA
    #!/bin/bash
    dnf install -y nmap-ncat bind-utils
    systemd-run --unit=lab-echo --collect \
      /usr/bin/ncat --listen --keep-open --sh-exec /bin/cat 8080
  USERDATA

  tags = { Name = "${var.name}-test-${count.index + 1}" }
}
