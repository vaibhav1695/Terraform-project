output "alb_dns_name" { value = aws_lb.alb.dns_name }
output "alb_logs_bucket" { value = aws_s3_bucket.alb_logs.bucket }
output "ssm_instance_id" { value = aws_instance.app.id }
