# Security S2 — Guardrails: CloudTrail + AWS Config + Security Hub (Terraform)

## What you build
- Multi-region CloudTrail → S3 (+ CloudWatch Logs option)
- AWS Config recorder + delivery channel to S3
- A few AWS Config managed rules (S3 public access, restricted SSH)
- AWS Security Hub enabled (baseline findings)

## Run
```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## Validate
- CloudTrail: new events appear in S3 bucket
- Config: recorder is ON and rules evaluate resources
- Security Hub: enabled and produces findings

## Destroy
```bash
terraform destroy
```

## Notes
Some controls (like SCPs) require AWS Organizations; this project focuses on guardrails you can do in a single account.
