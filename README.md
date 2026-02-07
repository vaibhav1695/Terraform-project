# Cost C1 — Start/Stop Scheduler + Budgets + S3 Lifecycle (Terraform)

## What you build
- An EC2 instance tagged for scheduling
- Lambda + EventBridge rules to **stop** and **start** instances by tag
- AWS Budgets monthly limit email alert
- S3 log bucket with lifecycle expiration (30d)

## Run
```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## Validate
- Check EventBridge rules and Lambda logs
- Manually invoke Lambda with test payload to stop/start
- Verify budget created (email alerts depend on AWS Budgets delivery)

## Destroy
```bash
terraform destroy
```
