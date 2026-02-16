resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.project_name}-daily-trigger"
  description         = "Triggers the NBA data fetcher Lambda every day"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.daily_trigger.name
  arn  = aws_lambda_function.nba_fetcher.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nba_fetcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}
