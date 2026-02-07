# OPTIONAL: Remote state backend (recommended for real practice)
# terraform {
#   backend "s3" {
#     bucket         = "REPLACE_ME_state_bucket"
#     key            = "REPLACE_ME/project/env/dev/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
