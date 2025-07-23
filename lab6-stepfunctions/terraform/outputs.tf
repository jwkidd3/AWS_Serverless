output "api_gateway_url" {
  description = "URL of the API Gateway endpoint"
  value       = "${aws_api_gateway_deployment.workflow_deployment.invoke_url}/process"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.workflow_api.id
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.simple_workflow.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.simple_workflow.name
}

output "state_machine_console_url" {
  description = "AWS Console URL for Step Functions state machine"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/states/home?region=${data.aws_region.current.name}#/statemachines/view/${aws_sfn_state_machine.simple_workflow.arn}"
}

output "lambda_functions" {
  description = "Names and ARNs of created Lambda functions"
  value = {
    process_data = {
      name = aws_lambda_function.process_data.function_name
      arn  = aws_lambda_function.process_data.arn
    }
    send_notification = {
      name = aws_lambda_function.send_notification.function_name
      arn  = aws_lambda_function.send_notification.arn
    }
    trigger_workflow = {
      name = aws_lambda_function.trigger_workflow.function_name
      arn  = aws_lambda_function.trigger_workflow.arn
    }
  }
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value = {
    process_data      = aws_cloudwatch_log_group.process_data_logs.name
    send_notification = aws_cloudwatch_log_group.send_notification_logs.name
    trigger_workflow  = aws_cloudwatch_log_group.trigger_workflow_logs.name
    step_functions    = aws_cloudwatch_log_group.step_functions_logs.name
    api_gateway       = aws_cloudwatch_log_group.api_gateway_logs.name
  }
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    username    = var.username
    region      = var.aws_region
    account_id  = data.aws_caller_identity.current.account_id
    deployed_at = timestamp()
  }
}
