output "vpc_id" {
  description = "VPC shared by every lab in this path."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnets. Public on purpose: no NAT gateway anywhere in this path."
  value       = aws_subnet.public[*].id
}

output "ecr_repository_url" {
  description = "Push/pull URL for the sample service image."
  value       = aws_ecr_repository.sample.repository_url
}

output "ecr_repository_arn" {
  description = "Used by Day 1 and Day 2 IAM policies."
  value       = aws_ecr_repository.sample.arn
}

output "ecr_repository_name" {
  description = "Used by CodeBuild buildspec and Day 3 task definitions."
  value       = aws_ecr_repository.sample.name
}
