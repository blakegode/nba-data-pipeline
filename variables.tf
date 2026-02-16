variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "nba-data-pipeline"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "s3_bucket_name" {
  description = "Base name for the S3 data lake bucket (account ID will be appended)"
  type        = string
  default     = "nba-data-lake"
}

variable "balldontlie_api_key" {
  description = "API key for the BallDontLie API"
  type        = string
  sensitive   = true
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 128
}

variable "schedule_expression" {
  description = "EventBridge cron expression for the daily trigger"
  type        = string
  default     = "cron(0 8 * * ? *)"
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}
