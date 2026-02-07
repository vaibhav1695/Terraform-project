output "scheduled_instance_id" { value = aws_instance.sched.id }
output "logs_bucket"           { value = aws_s3_bucket.logs.bucket }
output "budget_name"           { value = aws_budgets_budget.monthly.name }
output "lambda_name"           { value = aws_lambda_function.scheduler.function_name }
