variable "monthly_budget_usd" { type = number, default = 20 }
variable "budget_email" { type = string, default = "REPLACE_ME@example.com" }
variable "schedule_tag_key" { type = string, default = "Schedule" }
variable "schedule_tag_value" { type = string, default = "office-hours" }

locals { name = "${var.name_prefix}${var.project}-${var.environment}" }

resource "random_id" "suffix" { byte_length = 3 }

# S3 bucket with lifecycle (example logs bucket)
resource "aws_s3_bucket" "logs" {
  bucket = "${local.name}-logs-${random_id.suffix.hex}"
  force_destroy = true
}
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire30"
    status = "Enabled"
    expiration { days = 30 }
  }
}

# Tiny EC2 to be scheduled
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name" values = ["al2023-ami-*-x86_64"] }
}

resource "aws_vpc" "this" {
  cidr_block = "10.60.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = local.name }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
}
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.60.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[0]
}
data "aws_availability_zones" "available" { state = "available" }
resource "aws_route_table" "public" { vpc_id = aws_vpc.this.id }
resource "aws_route" "default" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_security_group" "ec2" {
  name   = "${local.name}-sg"
  vpc_id = aws_vpc.this.id
  egress { from_port=0 to_port=0 protocol="-1" cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_instance" "sched" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  tags = {
    Name = "${local.name}-sched"
    "${var.schedule_tag_key}" = var.schedule_tag_value
  }
}

# ---- Lambda scheduler (stop/start by tag) ----
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["lambda.amazonaws.com"] }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role      = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_ec2" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "lambda_ec2" {
  name   = "${local.name}-lambda-ec2"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_ec2.json
}

# Lambda source (inline zip)
locals {
  lambda_code = <<-PY
import boto3, os

ec2 = boto3.client("ec2")

TAG_KEY = os.environ.get("TAG_KEY", "Schedule")
TAG_VALUE = os.environ.get("TAG_VALUE", "office-hours")

def handler(event, context):
    action = event.get("action", "stop")  # "start" or "stop"
    resp = ec2.describe_instances(
        Filters=[{"Name": f"tag:{TAG_KEY}", "Values":[TAG_VALUE]}]
    )
    ids = []
    for r in resp["Reservations"]:
        for i in r["Instances"]:
            ids.append(i["InstanceId"])
    if not ids:
        return {"ok": True, "message":"No instances matched", "ids":[]}

    if action == "start":
        ec2.start_instances(InstanceIds=ids)
    else:
        ec2.stop_instances(InstanceIds=ids)
    return {"ok": True, "action": action, "ids": ids}
PY
}

resource "local_file" "lambda_py" {
  filename = "${path.module}/lambda/scheduler.py"
  content  = local.lambda_code
}
resource "null_resource" "zip" {
  triggers = { code_hash = sha1(local.lambda_code) }
  provisioner "local-exec" {
    command = "cd ${path.module}/lambda && zip -r ../scheduler.zip ."
  }
  depends_on = [local_file.lambda_py]
}

resource "aws_lambda_function" "scheduler" {
  function_name = "${local.name}-scheduler"
  role          = aws_iam_role.lambda.arn
  handler       = "scheduler.handler"
  runtime       = "python3.12"
  filename      = "${path.module}/scheduler.zip"
  source_code_hash = filebase64sha256("${path.module}/scheduler.zip")

  environment {
    variables = {
      TAG_KEY   = var.schedule_tag_key
      TAG_VALUE = var.schedule_tag_value
    }
  }

  depends_on = [null_resource.zip]
}

# EventBridge rules (cron in UTC)
# Example: stop at 15:00 UTC, start at 03:00 UTC Mon-Fri
resource "aws_cloudwatch_event_rule" "stop" {
  name                = "${local.name}-stop"
  schedule_expression = "cron(0 15 ? * MON-FRI *)"
}
resource "aws_cloudwatch_event_rule" "start" {
  name                = "${local.name}-start"
  schedule_expression = "cron(0 3 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "stop" {
  rule = aws_cloudwatch_event_rule.stop.name
  arn  = aws_lambda_function.scheduler.arn
  input = jsonencode({ action = "stop" })
}
resource "aws_cloudwatch_event_target" "start" {
  rule = aws_cloudwatch_event_rule.start.name
  arn  = aws_lambda_function.scheduler.arn
  input = jsonencode({ action = "start" })
}

resource "aws_lambda_permission" "allow_events_stop" {
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop.arn
}
resource "aws_lambda_permission" "allow_events_start" {
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start.arn
}

# ---- Budgets ----
resource "aws_budgets_budget" "monthly" {
  name              = "${local.name}-monthly"
  budget_type       = "COST"
  limit_amount      = tostring(var.monthly_budget_usd)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold          = 80
    threshold_type     = "PERCENTAGE"
    notification_type  = "ACTUAL"

    subscriber_email_addresses = [var.budget_email]
  }
}
