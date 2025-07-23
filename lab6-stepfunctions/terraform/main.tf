# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ServerlessLab6"
      Environment = "lab"
      Owner       = var.username
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda function code archives
data "archive_file" "process_data_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/process_data"
  output_path = "${path.module}/process_data.zip"
}

data "archive_file" "send_notification_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/send_notification"
  output_path = "${path.module}/send_notification.zip"
}

data "archive_file" "trigger_workflow_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/trigger_workflow"
  output_path = "${path.module}/trigger_workflow.zip"
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.username}-stepfunctions-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.username}-stepfunctions-lambda-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# IAM role for Step Functions
resource "aws_iam_role" "stepfunctions_role" {
  name = "${var.username}-stepfunctions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.username}-stepfunctions-role"
  }
}

resource "aws_iam_role_policy" "stepfunctions_policy" {
  name = "${var.username}-stepfunctions-policy"
  role = aws_iam_role.stepfunctions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.process_data.arn,
          aws_lambda_function.send_notification.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Additional policy for trigger function to start Step Functions
resource "aws_iam_role_policy" "lambda_stepfunctions_policy" {
  name = "${var.username}-lambda-stepfunctions-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.simple_workflow.arn
        ]
      }
    ]
  })
}

# Lambda Functions
resource "aws_lambda_function" "process_data" {
  filename         = data.archive_file.process_data_zip.output_path
  function_name    = "${var.username}-process-data"
  role            = aws_iam_role.lambda_role.arn
  handler         = "process_data.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  memory_size     = 256
  source_code_hash = data.archive_file.process_data_zip.output_base64sha256

  environment {
    variables = {
      USERNAME = var.username
      LOG_LEVEL = var.log_level
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.process_data_logs,
  ]
}

resource "aws_lambda_function" "send_notification" {
  filename         = data.archive_file.send_notification_zip.output_path
  function_name    = "${var.username}-send-notification"
  role            = aws_iam_role.lambda_role.arn
  handler         = "send_notification.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128
  source_code_hash = data.archive_file.send_notification_zip.output_base64sha256

  environment {
    variables = {
      USERNAME = var.username
      LOG_LEVEL = var.log_level
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.send_notification_logs,
  ]
}

resource "aws_lambda_function" "trigger_workflow" {
  filename         = data.archive_file.trigger_workflow_zip.output_path
  function_name    = "${var.username}-trigger-workflow"
  role            = aws_iam_role.lambda_role.arn
  handler         = "trigger_workflow.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128
  source_code_hash = data.archive_file.trigger_workflow_zip.output_base64sha256

  environment {
    variables = {
      USERNAME = var.username
      STATE_MACHINE_ARN = aws_sfn_state_machine.simple_workflow.arn
      LOG_LEVEL = var.log_level
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.trigger_workflow_logs,
  ]
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "simple_workflow" {
  name     = "${var.username}-simple-workflow"
  role_arn = aws_iam_role.stepfunctions_role.arn

  definition = jsonencode({
    Comment = "Simple data processing workflow with error handling"
    StartAt = "ProcessData"
    States = {
      ProcessData = {
        Type     = "Task"
        Resource = aws_lambda_function.process_data.arn
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "ProcessingFailed"
            ResultPath  = "$.error"
          }
        ]
        Next = "CheckStatus"
      }
      CheckStatus = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.status"
            StringEquals  = "SUCCESS"
            Next         = "SendNotification"
          }
        ]
        Default = "ProcessingFailed"
      }
      SendNotification = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed"]
            IntervalSeconds = 1
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "NotificationFailed"
            ResultPath  = "$.notificationError"
          }
        ]
        Next = "WorkflowCompleted"
      }
      WorkflowCompleted = {
        Type = "Pass"
        Result = {
          workflowStatus = "COMPLETED"
          message       = "Data processing workflow completed successfully"
          timestamp     = "$.sentAt"
        }
        End = true
      }
      ProcessingFailed = {
        Type = "Pass"
        Result = {
          workflowStatus = "PROCESSING_FAILED"
          message       = "Data processing failed"
        }
        End = true
      }
      NotificationFailed = {
        Type = "Pass"
        Result = {
          workflowStatus = "NOTIFICATION_FAILED"
          message       = "Data processed but notification failed"
        }
        End = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }
}

# API Gateway for triggering workflows
resource "aws_api_gateway_rest_api" "workflow_api" {
  name        = "${var.username}-workflow-api"
  description = "API to trigger Step Functions workflow"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "process_resource" {
  rest_api_id = aws_api_gateway_rest_api.workflow_api.id
  parent_id   = aws_api_gateway_rest_api.workflow_api.root_resource_id
  path_part   = "process"
}

resource "aws_api_gateway_method" "process_method" {
  rest_api_id   = aws_api_gateway_rest_api.workflow_api.id
  resource_id   = aws_api_gateway_resource.process_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "process_integration" {
  rest_api_id = aws_api_gateway_rest_api.workflow_api.id
  resource_id = aws_api_gateway_resource.process_resource.id
  http_method = aws_api_gateway_method.process_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.trigger_workflow.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_workflow.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.workflow_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "workflow_deployment" {
  depends_on = [
    aws_api_gateway_integration.process_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.workflow_api.id
  stage_name  = var.api_stage_name

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "process_data_logs" {
  name              = "/aws/lambda/${var.username}-process-data"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.username}-process-data-logs"
  }
}

resource "aws_cloudwatch_log_group" "send_notification_logs" {
  name              = "/aws/lambda/${var.username}-send-notification"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.username}-send-notification-logs"
  }
}

resource "aws_cloudwatch_log_group" "trigger_workflow_logs" {
  name              = "/aws/lambda/${var.username}-trigger-workflow"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.username}-trigger-workflow-logs"
  }
}

resource "aws_cloudwatch_log_group" "step_functions_logs" {
  name              = "/aws/lambda/${var.username}-simple-workflow"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.username}-stepfunctions-logs"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.workflow_api.id}/${var.api_stage_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.username}-api-gateway-logs"
  }
}
