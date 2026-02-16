output "s3_bucket_name" {
  description = "Name of the S3 data lake bucket"
  value       = aws_s3_bucket.nba_data.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 data lake bucket"
  value       = aws_s3_bucket.nba_data.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.nba_fetcher.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.nba_fetcher.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge scheduled rule"
  value       = aws_cloudwatch_event_rule.daily_trigger.arn
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter for the API key"
  value       = aws_ssm_parameter.balldontlie_api_key.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS alert topic"
  value       = aws_sns_topic.lambda_alerts.arn
}
