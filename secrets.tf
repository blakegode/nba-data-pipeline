resource "aws_ssm_parameter" "balldontlie_api_key" {
  name        = "/${var.project_name}/balldontlie-api-key"
  description = "API key for the BallDontLie NBA data API"
  type        = "SecureString"
  value       = var.balldontlie_api_key
}
