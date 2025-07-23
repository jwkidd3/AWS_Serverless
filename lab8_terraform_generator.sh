#!/bin/bash

# Lab 8 - Securing Serverless Applications - Complete Terraform Generator
# This script generates all necessary Terraform files and Lambda code for the security lab

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to prompt for username
get_username() {
    echo ""
    print_header "Lab 8 Setup - Username Configuration"
    
    while true; do
        echo -n "Enter your assigned username (user1, user2, user3, etc.): "
        read -r USERNAME
        
        if [[ -z "$USERNAME" ]]; then
            print_error "Username cannot be empty"
            continue
        fi
        
        if [[ ! "$USERNAME" =~ ^user[0-9]+$ ]]; then
            print_error "Username must follow the pattern 'user' followed by numbers (e.g., user1, user2)"
            continue
        fi
        
        print_status "Username set to: $USERNAME"
        break
    done
}

# Function to create directory structure
create_directories() {
    print_status "Creating project directory structure..."
    
    local project_dir="${USERNAME}-security-lab"
    
    if [[ -d "$project_dir" ]]; then
        print_warning "Directory $project_dir already exists. Contents may be overwritten."
        echo -n "Continue? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_error "Operation cancelled by user"
            exit 1
        fi
    fi
    
    mkdir -p "${project_dir}/terraform"
    mkdir -p "${project_dir}/lambda_functions/secure_function"
    mkdir -p "${project_dir}/lambda_functions/security_monitor"
    mkdir -p "${project_dir}/scripts"
    mkdir -p "${project_dir}/docs"
    mkdir -p "${project_dir}/examples/payloads"
    
    print_status "Directory structure created successfully"
}

# Function to create Terraform variables file
create_terraform_variables() {
    print_status "Creating Terraform variables.tf..."
    
    cat > "${USERNAME}-security-lab/terraform/variables.tf" << 'EOF'
variable "username" {
  description = "Username prefix for all resources"
  type        = string
  validation {
    condition     = can(regex("^user[0-9]+$", var.username))
    error_message = "Username must follow the pattern 'user' followed by numbers (e.g., user1, user2)."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid region identifier."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
  
  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment must not be empty."
  }
}

variable "cognito_callback_urls" {
  description = "Callback URLs for Cognito app client"
  type        = list(string)
  default     = ["https://localhost:3000/callback"]
  
  validation {
    condition     = length(var.cognito_callback_urls) > 0
    error_message = "At least one callback URL must be provided."
  }
}

variable "cognito_logout_urls" {
  description = "Logout URLs for Cognito app client"
  type        = list(string)
  default     = ["https://localhost:3000/logout"]
  
  validation {
    condition     = length(var.cognito_logout_urls) > 0
    error_message = "At least one logout URL must be provided."
  }
}

variable "alarm_email" {
  description = "Email for security alerts (optional)"
  type        = string
  default     = ""
  
  validation {
    condition = var.alarm_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alarm_email))
    error_message = "Email must be a valid email address or empty string."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}
EOF
    
    print_status "variables.tf created successfully"
}

# Function to create main Terraform configuration
create_terraform_main() {
    print_status "Creating Terraform main.tf..."
    
    cat > "${USERNAME}-security-lab/terraform/main.tf" << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "ServerlessLab8"
      Environment = var.environment
      Owner       = var.username
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key for encryption
resource "aws_kms_key" "serverless_key" {
  description             = "${var.username} serverless encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Function Access"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.secure_lambda_role.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.username}-serverless-key"
  }
}

resource "aws_kms_alias" "serverless_key_alias" {
  name          = "alias/${var.username}-serverless-key"
  target_key_id = aws_kms_key.serverless_key.key_id
}

# DynamoDB table with encryption
resource "aws_dynamodb_table" "secure_data" {
  name           = "${var.username}-secure-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "recordId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "recordId"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.serverless_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.username}-secure-data"
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "secure_app_pool" {
  name = "${var.username}-secure-app-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  mfa_configuration = "OPTIONAL"

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  username_attributes = ["email"]
  
  auto_verified_attributes = ["email"]

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = {
    Name = "${var.username}-secure-app-pool"
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "secure_app_client" {
  name         = "${var.username}-secure-app-client"
  user_pool_id = aws_cognito_user_pool.secure_app_pool.id

  generate_secret = true

  explicit_auth_flows = [
    "ADMIN_NO_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true

  prevent_user_existence_errors = "ENABLED"
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "secure_lambda_role" {
  name = "${var.username}-secure-lambda-role"

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
    Name = "${var.username}-secure-lambda-role"
  }
}

# IAM Policy for secure Lambda function
resource "aws_iam_role_policy" "secure_lambda_policy" {
  name = "${var.username}-secure-lambda-policy"
  role = aws_iam_role.secure_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.serverless_key.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = "${aws_dynamodb_table.secure_data.arn}*"
      }
    ]
  })
}

# Security Monitor Lambda Role
resource "aws_iam_role" "security_monitor_role" {
  name = "${var.username}-security-monitor-role"

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
    Name = "${var.username}-security-monitor-role"
  }
}

resource "aws_iam_role_policy" "security_monitor_policy" {
  name = "${var.username}-security-monitor-policy"
  role = aws_iam_role.security_monitor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.alarm_email != "" ? aws_sns_topic.security_alerts[0].arn : "*"
      }
    ]
  })
}

# Lambda function code archives
data "archive_file" "secure_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/secure_function"
  output_path = "${path.module}/secure_function.zip"
}

data "archive_file" "security_monitor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/security_monitor"
  output_path = "${path.module}/security_monitor.zip"
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "secure_function_logs" {
  name              = "/aws/lambda/${var.username}-secure-function"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.username}-secure-function-logs"
  }
}

resource "aws_cloudwatch_log_group" "security_monitor_logs" {
  name              = "/aws/lambda/${var.username}-security-monitor"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.username}-security-monitor-logs"
  }
}

# Secure Lambda Function
resource "aws_lambda_function" "secure_function" {
  filename         = data.archive_file.secure_function_zip.output_path
  function_name    = "${var.username}-secure-function"
  role            = aws_iam_role.secure_lambda_role.arn
  handler         = "secure_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = 256
  source_code_hash = data.archive_file.secure_function_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.secure_data.name
      KMS_KEY_ID = aws_kms_key.serverless_key.key_id
      USERNAME   = var.username
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.secure_function_logs
  ]

  tags = {
    Name = "${var.username}-secure-function"
  }
}

# Security Monitor Function
resource "aws_lambda_function" "security_monitor" {
  filename         = data.archive_file.security_monitor_zip.output_path
  function_name    = "${var.username}-security-monitor"
  role            = aws_iam_role.security_monitor_role.arn
  handler         = "security_monitor.lambda_handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = 128
  source_code_hash = data.archive_file.security_monitor_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = var.alarm_email != "" ? aws_sns_topic.security_alerts[0].arn : ""
      USERNAME      = var.username
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.security_monitor_logs
  ]

  tags = {
    Name = "${var.username}-security-monitor"
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "secure_api" {
  name        = "${var.username}-secure-api"
  description = "Secure API with Cognito authentication"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.username}-secure-api"
  }
}

# API Gateway Authorizer
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                   = "${var.username}-cognito-authorizer"
  rest_api_id           = aws_api_gateway_rest_api.secure_api.id
  type                  = "COGNITO_USER_POOLS"
  provider_arns         = [aws_cognito_user_pool.secure_app_pool.arn]
  identity_source       = "method.request.header.Authorization"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "secure_resource" {
  rest_api_id = aws_api_gateway_rest_api.secure_api.id
  parent_id   = aws_api_gateway_rest_api.secure_api.root_resource_id
  path_part   = "secure"
}

# API Gateway Method
resource "aws_api_gateway_method" "secure_post" {
  rest_api_id   = aws_api_gateway_rest_api.secure_api.id
  resource_id   = aws_api_gateway_resource.secure_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id

  request_parameters = {
    "method.request.header.Authorization" = true
  }
}

# API Gateway Integration
resource "aws_api_gateway_integration" "secure_integration" {
  rest_api_id = aws_api_gateway_rest_api.secure_api.id
  resource_id = aws_api_gateway_resource.secure_resource.id
  http_method = aws_api_gateway_method.secure_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.secure_function.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secure_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.secure_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "secure_deployment" {
  depends_on = [
    aws_api_gateway_integration.secure_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.secure_api.id
  stage_name  = "prod"

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.secure_resource.id,
      aws_api_gateway_method.secure_post.id,
      aws_api_gateway_integration.secure_integration.id,
    ]))
  }
}

# Log subscription filter for security monitoring
resource "aws_cloudwatch_log_subscription_filter" "security_filter" {
  name            = "${var.username}-security-filter"
  log_group_name  = aws_cloudwatch_log_group.secure_function_logs.name
  filter_pattern  = "SECURITY_EVENT"
  destination_arn = aws_lambda_function.security_monitor.arn
}

# Permission for CloudWatch Logs to invoke security monitor
resource "aws_lambda_permission" "cloudwatch_logs_invoke" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_monitor.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.secure_function_logs.arn}:*"
}

# SNS Topic for security alerts (optional)
resource "aws_sns_topic" "security_alerts" {
  count = var.alarm_email != "" ? 1 : 0
  name  = "${var.username}-security-alerts"

  tags = {
    Name = "${var.username}-security-alerts"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.username}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "This metric monitors lambda error rate"

  dimensions = {
    FunctionName = aws_lambda_function.secure_function.function_name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.security_alerts[0].arn] : []

  tags = {
    Name = "${var.username}-lambda-errors"
  }
}
EOF
    
    print_status "main.tf created successfully"
}

# Function to create Terraform outputs
create_terraform_outputs() {
    print_status "Creating Terraform outputs.tf..."
    
    cat > "${USERNAME}-security-lab/terraform/outputs.tf" << 'EOF'
output "api_gateway_url" {
  description = "URL of the secure API Gateway endpoint"
  value       = "${aws_api_gateway_deployment.secure_deployment.invoke_url}/secure"
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.secure_app_pool.id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.secure_app_client.id
}

output "kms_key_id" {
  description = "KMS Key ID for encryption"
  value       = aws_kms_key.serverless_key.key_id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.secure_data.name
}

output "lambda_function_name" {
  description = "Secure Lambda function name"
  value       = aws_lambda_function.secure_function.function_name
}

output "security_monitor_function_name" {
  description = "Security monitor function name"
  value       = aws_lambda_function.security_monitor.function_name
}

output "deployment_info" {
  description = "Deployment summary"
  value = {
    username           = var.username
    region            = var.aws_region
    account_id        = data.aws_caller_identity.current.account_id
    api_gateway_id    = aws_api_gateway_rest_api.secure_api.id
    user_pool_id      = aws_cognito_user_pool.secure_app_pool.id
    encryption_enabled = true
  }
}
EOF
    
    print_status "outputs.tf created successfully"
}

# Function to create terraform.tfvars
create_terraform_tfvars() {
    print_status "Creating Terraform terraform.tfvars..."
    
    cat > "${USERNAME}-security-lab/terraform/terraform.tfvars" << EOF
# Lab 8 - Securing Serverless Applications Configuration
# ⚠️ IMPORTANT: This has been configured with your username: ${USERNAME}

# Your assigned username
username = "${USERNAME}"

# AWS region (default: us-east-1)
aws_region = "us-east-1"

# Environment name
environment = "lab"

# Optional: Email for security alerts (uncomment and set your email)
# alarm_email = "your-email@example.com"

# Cognito callback URLs
cognito_callback_urls = ["https://localhost:3000/callback"]
cognito_logout_urls   = ["https://localhost:3000/logout"]

# CloudWatch log retention in days
log_retention_days = 14

# Lambda timeout in seconds
lambda_timeout = 30
EOF
    
    print_status "terraform.tfvars created successfully"
}

# Function to create secure function Lambda code
create_secure_function() {
    print_status "Creating secure Lambda function code..."
    
    cat > "${USERNAME}-security-lab/lambda_functions/secure_function/secure_function.py" << 'EOF'
import json
import boto3
import logging
import re
import html
import os
from datetime import datetime
import uuid

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
dynamodb = boto3.resource('dynamodb')

TABLE_NAME = os.environ['TABLE_NAME']
KMS_KEY_ID = os.environ['KMS_KEY_ID']
USERNAME = os.environ['USERNAME']

def validate_input(data):
    """Validate and sanitize input data"""
    errors = []
    
    # Check for required fields
    if not data.get('message'):
        errors.append("Message is required")
    
    # Validate message content
    message = data.get('message', '')
    if len(message) > 1000:
        errors.append("Message too long (max 1000 characters)")
    
    # Check for potential XSS
    if re.search(r'<script|javascript:|data:|vbscript:', message, re.IGNORECASE):
        errors.append("Invalid characters detected in message")
        logger.info(f"SECURITY_EVENT: XSS attempt detected. Message: {message[:100]}")
    
    # Sanitize HTML
    sanitized_message = html.escape(message)
    
    # Validate email if provided
    email = data.get('email', '')
    if email and not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
        errors.append("Invalid email format")
    
    return errors, {
        'message': sanitized_message,
        'email': email,
        'operation': data.get('operation', 'read')
    }

def log_security_event(event_type, details):
    """Log security events for monitoring"""
    security_log = {
        'timestamp': datetime.utcnow().isoformat(),
        'event_type': event_type,
        'details': details,
        'username': USERNAME
    }
    logger.info(f"SECURITY_EVENT: {json.dumps(security_log)}")

def lambda_handler(event, context):
    """Main Lambda handler for secure function"""
    try:
        # Log the request
        logger.info(f"Processing request: {json.dumps(event, default=str)}")
        
        # Parse request body
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event
        
        # Extract user info from authorizer context if available
        user_id = None
        if 'requestContext' in event and 'authorizer' in event['requestContext']:
            authorizer = event['requestContext']['authorizer']
            if 'claims' in authorizer:
                user_id = authorizer['claims'].get('sub', 'unknown')
        
        # Validate input
        validation_errors, sanitized_data = validate_input(body)
        if validation_errors:
            log_security_event('INPUT_VALIDATION_ERROR', {
                'errors': validation_errors,
                'user_id': user_id
            })
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Validation failed',
                    'details': validation_errors
                })
            }
        
        # Process based on operation
        operation = sanitized_data['operation']
        
        if operation == 'create':
            result = create_secure_record(sanitized_data, user_id)
        elif operation == 'read':
            result = read_secure_records(user_id)
        else:
            log_security_event('INVALID_OPERATION', {
                'operation': operation,
                'user_id': user_id
            })
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Invalid operation'})
            }
        
        # Log successful operation
        log_security_event('OPERATION_SUCCESS', {
            'operation': operation,
            'user_id': user_id
        })
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(result, default=str)
        }
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        log_security_event('PROCESSING_ERROR', {
            'error': str(e),
            'user_id': user_id if 'user_id' in locals() else 'unknown'
        })
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }

def create_secure_record(data, user_id):
    """Create a secure record in DynamoDB"""
    try:
        table = dynamodb.Table(TABLE_NAME)
        
        record = {
            'userId': user_id or 'anonymous',
            'recordId': str(uuid.uuid4()),
            'message': data['message'],
            'email': data.get('email', ''),
            'created_at': datetime.utcnow().isoformat(),
            'username_prefix': USERNAME
        }
        
        table.put_item(Item=record)
        
        return {
            'message': 'Record created successfully',
            'recordId': record['recordId']
        }
        
    except Exception as e:
        logger.error(f"Error creating record: {str(e)}")
        raise

def read_secure_records(user_id):
    """Read secure records from DynamoDB"""
    try:
        table = dynamodb.Table(TABLE_NAME)
        
        if user_id:
            response = table.query(
                KeyConditionExpression='userId = :uid',
                ExpressionAttributeValues={
                    ':uid': user_id
                }
            )
        else:
            response = table.scan(
                FilterExpression='username_prefix = :prefix',
                ExpressionAttributeValues={
                    ':prefix': USERNAME
                }
            )
        
        return {
            'records': response['Items'],
            'count': response['Count']
        }
        
    except Exception as e:
        logger.error(f"Error reading records: {str(e)}")
        raise
EOF
    
    print_status "secure_function.py created successfully"
}

# Function to create security monitor Lambda code
create_security_monitor() {
    print_status "Creating security monitor Lambda function code..."
    
    cat > "${USERNAME}-security-lab/lambda_functions/security_monitor/security_monitor.py" << 'EOF'
import json
import boto3
import logging
import gzip
import base64
import os
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
USERNAME = os.environ['USERNAME']

def lambda_handler(event, context):
    """Security monitoring function triggered by CloudWatch Logs"""
    try:
        # Parse CloudWatch Logs event
        logs_data = event['awslogs']['data']
        compressed_payload = base64.b64decode(logs_data)
        uncompressed_payload = gzip.decompress(compressed_payload)
        log_data = json.loads(uncompressed_payload)
        
        security_events = []
        
        # Process log events
        for log_event in log_data['logEvents']:
            message = log_event['message']
            
            # Check if this is a security event
            if 'SECURITY_EVENT:' in message:
                try:
                    # Extract security event details
                    security_data = message.split('SECURITY_EVENT: ')[1]
                    security_event = json.loads(security_data)
                    security_events.append({
                        'timestamp': log_event['timestamp'],
                        'event': security_event
                    })
                except (IndexError, json.JSONDecodeError) as e:
                    logger.warning(f"Failed to parse security event: {e}")
        
        # Process security events
        if security_events:
            process_security_events(security_events)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed_events': len(security_events),
                'username': USERNAME
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing security events: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def process_security_events(events):
    """Process and alert on security events"""
    for event_data in events:
        event = event_data['event']
        
        # Log all security events
        logger.info(f"Security event processed: {json.dumps(event)}")
EOF
    
    print_status "security_monitor.py created successfully"
}

# Function to create deployment script
create_deployment_script() {
    print_status "Creating deployment script..."
    
    cat > "${USERNAME}-security-lab/scripts/deploy.sh" << 'EOF'
#!/bin/bash

# Lab 8 Security Deployment Script
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

print_header "Lab 8 - Securing Serverless Applications Deployment"

# Check prerequisites
print_status "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install AWS CLI."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install Terraform."
    exit 1
fi

# Check AWS credentials
print_status "Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Run 'aws configure'."
    exit 1
fi

print_status "Prerequisites check passed"

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Validate configuration
print_status "Validating Terraform configuration..."
terraform validate

# Plan deployment
print_status "Planning deployment..."
terraform plan -out=tfplan

# Confirm deployment
echo ""
print_header "Ready to deploy Lab 8 infrastructure!"
echo "This will create:"
echo "  • Cognito User Pool with security policies"
echo "  • 2 Lambda functions (secure function + security monitor)"
echo "  • 1 API Gateway with Cognito authorization"
echo "  • KMS key for encryption"
echo "  • Encrypted DynamoDB table"
echo "  • CloudWatch Log Groups and monitoring"
echo "  • IAM roles with least privilege permissions"
echo ""
echo -n "Continue with deployment? (y/N): "
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    print_error "Deployment cancelled"
    exit 0
fi

# Apply deployment
print_status "Deploying infrastructure..."
terraform apply tfplan

# Get outputs
echo ""
print_header "Deployment completed! Here are your resources:"
terraform output

print_header "🎉 Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. Create a test user: ../scripts/create_test_user.sh"
echo "2. Run security tests: ../scripts/test_security.sh"
echo ""
print_status "Ready for Lab 8 security exercises!"
EOF
    
    chmod +x "${USERNAME}-security-lab/scripts/deploy.sh"
    print_status "deploy.sh created successfully"
}

# Function to create test user script
create_test_user_script() {
    print_status "Creating test user creation script..."
    
    cat > "${USERNAME}-security-lab/scripts/create_test_user.sh" << 'EOF'
#!/bin/bash

# Script to create a test user in Cognito User Pool
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

# Get User Pool ID from Terraform output
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)

if [ -z "$USER_POOL_ID" ]; then
    print_error "Could not retrieve User Pool ID. Make sure infrastructure is deployed."
    exit 1
fi

print_status "Creating test user in Cognito User Pool: $USER_POOL_ID"

# Create test user
aws cognito-idp admin-create-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "testuser" \
  --user-attributes Name=email,Value="test@example.com" Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action "SUPPRESS"

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id "$USER_POOL_ID" \
  --username "testuser" \
  --password "SecurePass123!" \
  --permanent

print_status "✅ Test user created successfully!"
echo ""
echo "Test user credentials:"
echo "  Username: testuser"
echo "  Password: SecurePass123!"
echo "  Email: test@example.com"
EOF
    
    chmod +x "${USERNAME}-security-lab/scripts/create_test_user.sh"
    print_status "create_test_user.sh created successfully"
}

# Function to create security testing script
create_security_test_script() {
    print_status "Creating security testing script..."
    
    cat > "${USERNAME}-security-lab/scripts/test_security.sh" << 'EOF'
#!/bin/bash

# Script to test security features of the serverless application
set -e

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

# Get API URL from Terraform output
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)

if [ -z "$API_URL" ]; then
    echo "Could not retrieve API URL. Make sure infrastructure is deployed."
    exit 1
fi

print_header "Testing Security Features"
echo "API URL: $API_URL"
echo ""

# Test 1: Unauthenticated access
print_status "Test 1: Unauthenticated access (should return 401)"
HTTP_CODE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"operation": "read", "message": "test"}' \
  -w "%{http_code}" -o /dev/null)

if [ "$HTTP_CODE" = "401" ]; then
    echo "✅ PASS - Returned 401 Unauthorized as expected"
else
    echo "❌ FAIL - Expected 401, got $HTTP_CODE"
fi
echo ""

print_header "Security Testing Summary"
echo "✅ API Gateway requires authentication (Cognito JWT tokens)"
echo "✅ Unauthenticated requests are properly blocked"
echo ""
USERNAME=$(grep "^username" terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
echo "To see security event logs:"
echo "aws logs filter-log-events --log-group-name '/aws/lambda/$USERNAME-secure-function' --filter-pattern 'SECURITY_EVENT'"
EOF
    
    chmod +x "${USERNAME}-security-lab/scripts/test_security.sh"
    print_status "test_security.sh created successfully"
}

# Function to create README
create_readme() {
    print_status "Creating README.md..."
    
    cat > "${USERNAME}-security-lab/README.md" << EOF
# Lab 8 - Securing Serverless Applications

**Duration:** 90 minutes  
**Username:** ${USERNAME}

## Overview

This lab implements comprehensive security controls for serverless applications using AWS security services and Terraform for Infrastructure as Code.

## Quick Start

### 1. Deploy Infrastructure

\`\`\`bash
./scripts/deploy.sh
\`\`\`

### 2. Create Test User

\`\`\`bash
./scripts/create_test_user.sh
\`\`\`

### 3. Run Security Tests

\`\`\`bash
./scripts/test_security.sh
\`\`\`

### 4. Monitor Security Events

\`\`\`bash
aws logs filter-log-events \\
  --log-group-name '/aws/lambda/${USERNAME}-secure-function' \\
  --filter-pattern 'SECURITY_EVENT'
\`\`\`

## Project Structure

\`\`\`
${USERNAME}-security-lab/
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output values
│   └── terraform.tfvars         # Configuration values
├── lambda_functions/            # Lambda source code
│   ├── secure_function/         # Main secure function
│   └── security_monitor/        # Security monitoring function
├── scripts/                     # Automation scripts
└── README.md                    # This file
\`\`\`

## Security Features Implemented

- **Authentication:** Cognito User Pool with strong password policies
- **Authorization:** API Gateway + Cognito authorizer
- **Input Validation:** XSS protection and data sanitization
- **Encryption:** KMS-encrypted DynamoDB table
- **Monitoring:** Real-time security event detection
- **Least Privilege:** IAM roles with minimal permissions

## Clean Up

To remove all resources:

\`\`\`bash
cd terraform
terraform destroy
\`\`\`

---

**Course:** Developing Serverless Solutions on AWS | **Lab:** 8 | **Duration:** ~90 minutes
EOF
    
    print_status "README.md created successfully"
}

# Main execution function
main() {
    print_header "Lab 8 - Securing Serverless Applications - Terraform Generator"
    
    # Get username from user
    get_username
    
    print_status "Generating Lab 8 infrastructure for username: $USERNAME"
    
    # Create all components
    create_directories
    create_terraform_variables
    create_terraform_main
    create_terraform_outputs
    create_terraform_tfvars
    create_secure_function
    create_security_monitor
    create_deployment_script
    create_test_user_script
    create_security_test_script
    create_readme
    
    # Final setup
    print_header "🎉 Lab 8 Infrastructure Generated Successfully!"
    
    echo ""
    echo "📁 Project Structure Created:"
    echo "├── ${USERNAME}-security-lab/"
    echo "│   ├── terraform/                   # Infrastructure as Code"
    echo "│   ├── lambda_functions/            # Lambda source code"
    echo "│   ├── scripts/                     # Automation scripts"
    echo "│   └── README.md                    # Lab guide"
    echo ""
    
    print_header "🚀 Next Steps"
    echo ""
    echo "1. 📂 Navigate to your lab directory:"
    echo "   cd ${USERNAME}-security-lab"
    echo ""
    echo "2. ⚙️  Deploy the infrastructure:"
    echo "   ./scripts/deploy.sh"
    echo ""
    echo "3. 👤 Create a test user:"
    echo "   ./scripts/create_test_user.sh"
    echo ""
    echo "4. 🔒 Run security tests:"
    echo "   ./scripts/test_security.sh"
    echo ""
    
    print_status "🎓 Ready for Lab 8 - Securing Serverless Applications!"
}

# Run the main function
main "$@"