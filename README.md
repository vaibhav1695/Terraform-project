# Security S1 — Secure VPC + Private App + ALB + WAF + Centralized Logs (Terraform)

## What you build
- VPC (2 AZ) with public + private subnets
- 1 NAT Gateway (private egress)
- Private EC2 instance running nginx
- Public ALB → forwards to private instance
- AWS WAFv2 attached to ALB (managed rules + rate limit)
- ALB access logs → S3 (lifecycle)
- VPC Flow Logs → CloudWatch Logs
- No SSH: access instance via **SSM Session Manager**

> Cost drivers: NAT Gateway, ALB, WAF, CW logs. Destroy after practice.

## Run
```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```
Outputs include the ALB URL.

## Validate
- Open ALB DNS in browser: should show nginx page
- In WAF console, verify WebACL attached; try hitting `/` rapidly to see rate-based rule count
- In CloudWatch Logs, verify VPC flow logs group exists

## Destroy
```bash
terraform destroy
```

## Remote state (optional)
Uncomment and fill backend in `backend.tf` if you want S3+DDB locking.
