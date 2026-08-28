# AWS System Integration Patterns

5-day pattern-first learning path. Focus: enterprise integration patterns
(API gateway, ingress, egress, service-to-service, external) implemented on AWS.
Use cases: banking, payment, microservices.

## Prerequisites
- AWS account (personal)
- AWS CLI configured
- Terraform >= 1.5 installed
- Familiarity with IAM, EC2, S3, RDS basics

## How to use this path
Each day = one content file (read first) + one lab (then build).
Follow the pattern loop: name it → draw the boundary → map to AWS → wire it → break it → fix it.

## Day Index
| Day | Pattern family | Enterprise scenario |
|---|---|---|
| 1 | API Gateway patterns | Mobile banking BFF |
| 2 | Ingress patterns | Core banking API canary deploy |
| 3 | Egress + VPC boundary | PCI PrivateLink scope reduction |
| 4 | Service-to-service | Microservice mesh (order→payment→fulfillment) |
| 5 | External integration + synthesis | Payment provider webhook + cross-account PCI |

## Cost note
Each lab includes a teardown checklist. Run teardown after every session.
Estimated cost per lab if left running overnight: $2–$10 depending on day.
