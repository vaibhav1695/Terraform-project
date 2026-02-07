output "cloudtrail_bucket" { value = aws_s3_bucket.cloudtrail.bucket }
output "config_bucket"     { value = aws_s3_bucket.config.bucket }
output "trail_name"        { value = aws_cloudtrail.this.name }
