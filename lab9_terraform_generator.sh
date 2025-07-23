#!/bin/bash

# Lab 9 - Performance and Scaling Optimization - Complete Generator Script
# This script creates ALL Terraform files, Lambda code, scripts, and lab documentation

echo "🚀 Generating Complete Lab 9 - Performance and Scaling Optimization with Terraform..."
echo "==================================================================================="

# Create main directory structure
LAB_DIR="lab9-performance-terraform"
mkdir -p "$LAB_DIR"/{docs,scripts,lambda_functions/{performance_function,load_tester,sqs_scaler},terraform,examples,test_data}

cd "$LAB_DIR"

echo "📁 Created directory structure in: $LAB_DIR"

# ===== LAB MARKDOWN DOCUMENT =====

cat > "Developing_Serverless_Solutions_AWS_Day3_Lab9.md" << 'EOF'
# Developing Serverless Solutions on AWS - Day 3 - Lab 9
## Performance and Scaling Optimization (Terraform Version)

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will implement performance optimization and scaling strategies for serverless applications using **Terraform** for infrastructure provisioning instead of AWS CLI commands. You'll configure Lambda concurrency management, optimize API Gateway performance, implement caching strategies, and design applications to handle high-scale production workloads efficiently.

This lab demonstrates the advantages of Infrastructure as Code (IaC) over imperative CLI approaches for managing complex, performance-optimized serverless applications.

## Lab Objectives

By the end of this lab, you will be able to:
- Use Terraform to provision high-performance serverless infrastructure
- Configure Lambda concurrency settings for optimal performance using IaC
- Implement API Gateway caching and throttling strategies with declarative configuration
- Design auto-scaling patterns for serverless applications
- Optimize cold start performance and memory allocation through code
- Implement connection pooling and resource optimization
- Configure event source scaling for high-throughput scenarios
- Monitor and analyze performance metrics for scaling decisions
- Compare Infrastructure as Code benefits vs. imperative CLI approaches
- Apply username prefixing to scaling resources consistently

## Prerequisites

- Completion of Labs 1-8
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- AWS CLI configured
- Terraform >= 1.0 installed
- Python 3.9+
- Understanding of Lambda performance characteristics

---

## Task 1: Configure Your Username and Environment

### Step 1.1: Critical Configuration

**⚠️ CRITICAL: You MUST configure your assigned username to avoid resource conflicts!**

1. Navigate to the terraform directory:
```bash
cd terraform
```

2. Edit `terraform.tfvars` with your assigned username:
```hcl
# CRITICAL: Replace with YOUR assigned username
username = "user1"  # Change to your assigned username (user1, user2, user3, etc.)

# Performance optimization settings
lambda_memory_size = 1024
lambda_timeout = 300
provisioned_concurrency = 10
reserved_concurrency = 50

# API Gateway settings
api_throttle_rate_limit = 1000
api_throttle_burst_limit = 2000
api_caching_enabled = true
api_cache_ttl = 300

# SQS settings
sqs_visibility_timeout = 300
sqs_batch_size = 10
sqs_max_batching_window = 5

# Optional: Enable detailed monitoring
enable_detailed_monitoring = true
alarm_email = ""  # Add your email for alarm notifications
```

**⚠️ WARNING:** Using the default username will cause conflicts with other students!

---

## Task 2: Deploy Infrastructure with Terraform

### Step 2.1: Initialize and Deploy

1. **Initialize Terraform:**
```bash
terraform init
```

2. **Validate configuration:**
```bash
terraform validate
```

3. **Plan the deployment:**
```bash
terraform plan
```

4. **Apply the infrastructure:**
```bash
terraform apply
```

5. **Verify deployment:**
```bash
terraform output
```

---

## Task 3: Performance Testing

### Step 3.1: Run Performance Tests

1. **Execute the automated test suite:**
```bash
cd ..  # Return to lab root directory
./scripts/run_performance_tests.sh
```

2. **Run load tests:**
```bash
./scripts/run_load_tests.sh
```

3. **Generate SQS load:**
```bash
./scripts/generate_sqs_load.sh 1000 10
```

---

## Clean Up

```bash
cd terraform
terraform destroy
```

---

## Key Takeaways

This lab demonstrates the power of Infrastructure as Code for managing complex, high-performance serverless applications. The Terraform approach provides better maintainability, reproducibility, and team collaboration compared to imperative CLI scripts.
EOF

echo "📄 Created lab markdown document"

# ===== MAIN README.md =====

cat > README.md << 'EOF'
# Lab 9 - Performance and Scaling Optimization (Terraform Version)

**Lab Duration:** 90 minutes

## Quick Start

### 1. Configure Username

Edit `terraform/terraform.tfvars`:
```hcl
username = "user1"  # CHANGE TO YOUR ASSIGNED USERNAME
```

### 2. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### 3. Run Performance Tests

```bash
./scripts/run_performance_tests.sh
./scripts/run_load_tests.sh
```

### 4. Clean Up

```bash
cd terraform
terraform destroy
```

## Infrastructure Components

- **3 Lambda Functions**: Performance, Load Tester, SQS Scaler
- **1 API Gateway**: Optimized with caching and throttling
- **2 SQS Queues**: High-throughput processing
- **2 DynamoDB Tables**: Performance data storage
- **CloudWatch Dashboard**: Real-time monitoring

## Performance Optimizations

- **Provisioned Concurrency**: Eliminates cold starts
- **Reserved Concurrency**: Prevents throttling
- **API Gateway Caching**: Reduces backend load
- **Connection Pooling**: Reuses AWS service connections
- **Batch Processing**: Optimizes SQS throughput

## Documentation

- [Lab Instructions](Developing_Serverless_Solutions_AWS_Day3_Lab9.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
EOF

echo "📄 Created main README.md"

# ===== TERRAFORM CONFIGURATION FILES =====

# terraform/variables.tf
cat > terraform/variables.tf << 'EOF'
variable "username" {
  description = "Username prefix for all resources"
  type        = string
  validation {
    condition     = length(var.username) > 0 && length(var.username) <= 20
    error_message = "Username must be between 1 and 20 characters."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "lambda_memory_size" {
  description = "Memory allocation for Lambda functions (MB)"
  type        = number
  default     = 1024
}

variable "lambda_timeout" {
  description = "Lambda function timeout (seconds)"
  type        = number
  default     = 300
}

variable "provisioned_concurrency" {
  description = "Provisioned concurrency for performance function"
  type        = number
  default     = 10
}

variable "reserved_concurrency" {
  description = "Reserved concurrency for performance function"
  type        = number
  default     = 50
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 1000
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 2000
}

variable "api_caching_enabled" {
  description = "Enable API Gateway caching"
  type        = bool
  default     = true
}

variable "api_cache_ttl" {
  description = "API Gateway cache TTL (seconds)"
  type        = number
  default     = 300
}

variable "sqs_visibility_timeout" {
  description = "SQS message visibility timeout (seconds)"
  type        = number
  default     = 300
}

variable "sqs_batch_size" {
  description = "SQS Lambda trigger batch size"
  type        = number
  default     = 10
}

variable "sqs_max_batching_window" {
  description = "SQS Lambda trigger max batching window (seconds)"
  type        = number
  default     = 5
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period (days)"
  type        = number
  default     = 7
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "lab"
    Project     = "serverless-performance"
    Lab         = "lab9"
  }
}
EOF

# terraform/terraform.tfvars
cat > terraform/terraform.tfvars << 'EOF'
# Lab 9 - Performance and Scaling Configuration
# CRITICAL: Replace 'user1' with YOUR assigned username

username = "user1"  # CHANGE THIS TO YOUR ASSIGNED USERNAME

# AWS Configuration
aws_region = "us-east-1"

# Lambda Performance Configuration
lambda_memory_size       = 1024
lambda_timeout          = 300
provisioned_concurrency = 10
reserved_concurrency    = 50

# API Gateway Performance Configuration
api_throttle_rate_limit  = 1000
api_throttle_burst_limit = 2000
api_caching_enabled     = true
api_cache_ttl          = 300

# SQS High-Throughput Configuration
sqs_visibility_timeout     = 300
sqs_batch_size            = 10
sqs_max_batching_window   = 5

# Monitoring Configuration
enable_detailed_monitoring = true
log_retention_days        = 7
alarm_email = ""

# Additional tags
common_tags = {
  Environment = "lab"
  Project     = "serverless-performance"
  Lab         = "lab9"
  Owner       = "user1"  # Change to your username
}
EOF

# terraform/main.tf
cat > terraform/main.tf << 'EOF'
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
    tags = merge(var.common_tags, {
      Username = var.username
      Lab      = "lab9-performance-scaling"
    })
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  prefix = var.username
  
  performance_function_name = "${local.prefix}-performance-function"
  load_tester_function_name = "${local.prefix}-load-tester"
  sqs_scaler_function_name  = "${local.prefix}-sqs-scaler"
  
  api_gateway_name = "${local.prefix}-optimized-api"
  sqs_queue_name   = "${local.prefix}-high-throughput-queue"
  
  common_environment = {
    USERNAME                = var.username
    AWS_REGION             = var.aws_region
    PERFORMANCE_TABLE      = aws_dynamodb_table.performance_data.name
    SQS_QUEUE_URL          = aws_sqs_queue.high_throughput_queue.url
    ENABLE_DETAILED_MONITORING = tostring(var.enable_detailed_monitoring)
  }
}
EOF

# terraform/iam.tf
cat > terraform/iam.tf << 'EOF'
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.username}-lambda-performance-role"

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

  tags = merge(var.common_tags, {
    Name = "${var.username}-lambda-performance-role"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_insights" {
  count      = var.enable_detailed_monitoring ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role_policy" "lambda_performance_policy" {
  name = "${var.username}-lambda-performance-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.performance_data.arn,
          "${aws_dynamodb_table.performance_data.arn}/index/*",
          aws_dynamodb_table.load_test_results.arn,
          "${aws_dynamodb_table.load_test_results.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_sqs_queue.high_throughput_queue.arn,
          aws_sqs_queue.high_throughput_dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-*"
      }
    ]
  })
}

resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "${var.username}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.username}-api-gateway-cloudwatch-role"
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
}
EOF

# terraform/dynamodb.tf
cat > terraform/dynamodb.tf << 'EOF'
resource "aws_dynamodb_table" "performance_data" {
  name           = "${var.username}-performance-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  global_secondary_index {
    name               = "timestamp-index"
    hash_key           = "timestamp"
    projection_type    = "ALL"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-performance-data"
    Purpose = "performance-metrics-storage"
  })
}

resource "aws_dynamodb_table" "load_test_results" {
  name           = "${var.username}-load-test-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "test_id"
  
  attribute {
    name = "test_id"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  global_secondary_index {
    name               = "timestamp-index"
    hash_key           = "timestamp"
    projection_type    = "ALL"
  }
  
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-load-test-results"
    Purpose = "load-test-data-storage"
  })
}
EOF

# terraform/sqs.tf
cat > terraform/sqs.tf << 'EOF'
resource "aws_sqs_queue" "high_throughput_dlq" {
  name = "${var.username}-high-throughput-dlq"
  message_retention_seconds = 1209600
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-high-throughput-dlq"
    Purpose = "dead-letter-queue"
  })
}

resource "aws_sqs_queue" "high_throughput_queue" {
  name                       = local.sqs_queue_name
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = 1209600
  max_message_size          = 262144
  delay_seconds             = 0
  receive_wait_time_seconds = 20
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.high_throughput_dlq.arn
    maxReceiveCount     = 3
  })
  
  tags = merge(var.common_tags, {
    Name = local.sqs_queue_name
    Purpose = "high-throughput-processing"
  })
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.high_throughput_queue.arn
  function_name    = aws_lambda_function.sqs_scaler.arn
  
  batch_size                         = var.sqs_batch_size
  maximum_batching_window_in_seconds = var.sqs_max_batching_window
  
  function_response_types = ["ReportBatchItemFailures"]
  
  depends_on = [aws_lambda_function.sqs_scaler]
}
EOF

# terraform/lambda.tf
cat > terraform/lambda.tf << 'EOF'
data "archive_file" "performance_function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/performance_function"
  output_path = "${path.module}/../lambda_functions/performance_function.zip"
}

data "archive_file" "load_tester_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/load_tester"
  output_path = "${path.module}/../lambda_functions/load_tester.zip"
}

data "archive_file" "sqs_scaler_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_functions/sqs_scaler"
  output_path = "${path.module}/../lambda_functions/sqs_scaler.zip"
}

resource "aws_lambda_function" "performance_function" {
  function_name = local.performance_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  
  filename         = data.archive_file.performance_function_zip.output_path
  source_code_hash = data.archive_file.performance_function_zip.output_base64sha256
  
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
  
  reserved_concurrent_executions = var.reserved_concurrency
  
  environment {
    variables = merge(local.common_environment, {
      FUNCTION_TYPE = "performance"
    })
  }
  
  tracing_config {
    mode = "Active"
  }
  
  layers = var.enable_detailed_monitoring ? [
    "arn:aws:lambda:${data.aws_region.current.name}:580247275435:layer:LambdaInsightsExtension:38"
  ] : []
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.performance_function_logs
  ]
  
  tags = merge(var.common_tags, {
    Name = local.performance_function_name
    Purpose = "high-performance-testing"
  })
}

resource "aws_lambda_provisioned_concurrency_config" "performance_function_concurrency" {
  count                     = var.provisioned_concurrency > 0 ? 1 : 0
  function_name             = aws_lambda_function.performance_function.function_name
  provisioned_concurrent_executions = var.provisioned_concurrency
  qualifier                 = "$LATEST"
  
  depends_on = [aws_lambda_function.performance_function]
}

resource "aws_lambda_function" "load_tester" {
  function_name = local.load_tester_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  
  filename         = data.archive_file.load_tester_zip.output_path
  source_code_hash = data.archive_file.load_tester_zip.output_base64sha256
  
  memory_size = 512
  timeout     = 900
  
  environment {
    variables = merge(local.common_environment, {
      FUNCTION_TYPE = "load_tester"
      TARGET_FUNCTION_NAME = aws_lambda_function.performance_function.function_name
      LOAD_TEST_RESULTS_TABLE = aws_dynamodb_table.load_test_results.name
    })
  }
  
  tracing_config {
    mode = "Active"
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.load_tester_logs
  ]
  
  tags = merge(var.common_tags, {
    Name = local.load_tester_function_name
    Purpose = "load-testing"
  })
}

resource "aws_lambda_function" "sqs_scaler" {
  function_name = local.sqs_scaler_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  
  filename         = data.archive_file.sqs_scaler_zip.output_path
  source_code_hash = data.archive_file.sqs_scaler_zip.output_base64sha256
  
  memory_size = 256
  timeout     = 60
  
  environment {
    variables = merge(local.common_environment, {
      FUNCTION_TYPE = "sqs_scaler"
    })
  }
  
  tracing_config {
    mode = "Active"
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.sqs_scaler_logs
  ]
  
  tags = merge(var.common_tags, {
    Name = local.sqs_scaler_function_name
    Purpose = "sqs-message-processing"
  })
}

resource "aws_cloudwatch_log_group" "performance_function_logs" {
  name              = "/aws/lambda/${local.performance_function_name}"
  retention_in_days = var.log_retention_days
  
  tags = merge(var.common_tags, {
    Name = "${local.performance_function_name}-logs"
  })
}

resource "aws_cloudwatch_log_group" "load_tester_logs" {
  name              = "/aws/lambda/${local.load_tester_function_name}"
  retention_in_days = var.log_retention_days
  
  tags = merge(var.common_tags, {
    Name = "${local.load_tester_function_name}-logs"
  })
}

resource "aws_cloudwatch_log_group" "sqs_scaler_logs" {
  name              = "/aws/lambda/${local.sqs_scaler_function_name}"
  retention_in_days = var.log_retention_days
  
  tags = merge(var.common_tags, {
    Name = "${local.sqs_scaler_function_name}-logs"
  })
}
EOF

# terraform/api_gateway.tf
cat > terraform/api_gateway.tf << 'EOF'
resource "aws_api_gateway_rest_api" "optimized_api" {
  name        = local.api_gateway_name
  description = "High-performance API for Lab 9 testing"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  binary_media_types = ["application/octet-stream", "image/*"]
  
  tags = merge(var.common_tags, {
    Name = local.api_gateway_name
    Purpose = "performance-testing-api"
  })
}

resource "aws_api_gateway_account" "api_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

resource "aws_api_gateway_resource" "performance_resource" {
  rest_api_id = aws_api_gateway_rest_api.optimized_api.id
  parent_id   = aws_api_gateway_rest_api.optimized_api.root_resource_id
  path_part   = "performance"
}

resource "aws_api_gateway_method" "performance_post" {
  rest_api_id   = aws_api_gateway_rest_api.optimized_api.id
  resource_id   = aws_api_gateway_resource.performance_resource.id
  http_method   = "POST"
  authorization = "NONE"
  
  api_key_required = true
}

resource "aws_api_gateway_integration" "performance_integration" {
  rest_api_id = aws_api_gateway_rest_api.optimized_api.id
  resource_id = aws_api_gateway_resource.performance_resource.id
  http_method = aws_api_gateway_method.performance_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.performance_function.invoke_arn
  
  connection_type = "INTERNET"
  timeout_milliseconds = 29000
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.performance_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.optimized_api.execution_arn}/*/*"
}

resource "aws_api_gateway_method_response" "performance_response_200" {
  rest_api_id = aws_api_gateway_rest_api.optimized_api.id
  resource_id = aws_api_gateway_resource.performance_resource.id
  http_method = aws_api_gateway_method.performance_post.http_method
  status_code = "200"
  
  response_headers = {
    "Access-Control-Allow-Origin" = true
    "Cache-Control" = true
  }
}

resource "aws_api_gateway_integration_response" "performance_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.optimized_api.id
  resource_id = aws_api_gateway_resource.performance_resource.id
  http_method = aws_api_gateway_method.performance_post.http_method
  status_code = aws_api_gateway_method_response.performance_response_200.status_code
  
  response_headers = {
    "Access-Control-Allow-Origin" = "'*'"
    "Cache-Control" = "integration.response.header.Cache-Control"
  }
  
  depends_on = [aws_api_gateway_integration.performance_integration]
}

resource "aws_api_gateway_deployment" "performance_deployment" {
  rest_api_id = aws_api_gateway_rest_api.optimized_api.id
  stage_name  = "prod"
  
  depends_on = [
    aws_api_gateway_integration.performance_integration,
    aws_api_gateway_integration_response.performance_integration_response
  ]
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "performance_stage" {
  deployment_id = aws_api_gateway_deployment.performance_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.optimized_api.id
  stage_name    = "prod"
  
  method_settings {
    method_path = "*/*"
    
    logging_level   = "INFO"
    data_trace_enabled = var.enable_detailed_monitoring
    metrics_enabled    = true
    
    caching_enabled      = var.api_caching_enabled
    cache_ttl_in_seconds = var.api_cache_ttl
    cache_key_parameters = []
    
    throttling_rate_limit  = var.api_throttle_rate_limit
    throttling_burst_limit = var.api_throttle_burst_limit
  }
  
  tags = merge(var.common_tags, {
    Name = "${local.api_gateway_name}-prod-stage"
  })
  
  depends_on = [aws_api_gateway_account.api_account]
}

resource "aws_api_gateway_usage_plan" "performance_usage_plan" {
  name = "${var.username}-performance-usage-plan"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.optimized_api.id
    stage  = aws_api_gateway_stage.performance_stage.stage_name
  }
  
  quota_settings {
    limit  = 10000
    period = "DAY"
  }
  
  throttle_settings {
    rate_limit  = var.api_throttle_rate_limit
    burst_limit = var.api_throttle_burst_limit
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-performance-usage-plan"
  })
}

resource "aws_api_gateway_api_key" "performance_api_key" {
  name        = "${var.username}-performance-key"
  description = "API key for performance testing"
  enabled     = true
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-performance-key"
  })
}

resource "aws_api_gateway_usage_plan_key" "performance_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.performance_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.performance_usage_plan.id
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.optimized_api.id}/prod"
  retention_in_days = var.log_retention_days
  
  tags = merge(var.common_tags, {
    Name = "${local.api_gateway_name}-execution-logs"
  })
}
EOF

# terraform/cloudwatch.tf
cat > terraform/cloudwatch.tf << 'EOF'
resource "aws_sns_topic" "performance_alerts" {
  count = var.alarm_email != "" ? 1 : 0
  name  = "${var.username}-performance-alerts"
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-performance-alerts"
  })
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.performance_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.username}-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "Errors"
  namespace          = "AWS/Lambda"
  period             = "300"
  statistic          = "Sum"
  threshold          = "5"
  alarm_description  = "Lambda function error rate too high"
  
  dimensions = {
    FunctionName = aws_lambda_function.performance_function.function_name
  }
  
  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.performance_alerts[0].arn] : []
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-lambda-error-rate"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.username}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "Duration"
  namespace          = "AWS/Lambda"
  period             = "300"
  statistic          = "Average"
  threshold          = "10000"
  alarm_description  = "Lambda function duration too high"
  
  dimensions = {
    FunctionName = aws_lambda_function.performance_function.function_name
  }
  
  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.performance_alerts[0].arn] : []
  
  tags = merge(var.common_tags, {
    Name = "${var.username}-lambda-duration"
  })
}

resource "aws_cloudwatch_dashboard" "performance_dashboard" {
  dashboard_name = "${var.username}-performance-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.performance_function.function_name],
            [".", "Invocations", ".", "."],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Performance Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", aws_lambda_function.performance_function.function_name]
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "Lambda Concurrent Executions"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.optimized_api.name],
            [".", "Latency", ".", "."],
            [".", "4XXError", ".", "."],
            [".", "5XXError", ".", "."]
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "API Gateway Metrics"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["HighPerformance", "ExecutionTime", "FunctionName", aws_lambda_function.performance_function.function_name],
            [".", "SuccessfulInvocations", ".", "."]
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "Custom Performance Metrics"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.high_throughput_queue.name],
            [".", "NumberOfMessagesReceived", ".", "."],
            [".", "NumberOfMessagesDeleted", ".", "."],
            [".", "ApproximateNumberOfVisibleMessages", ".", "."]
          ]
          view   = "timeSeries"
          region = var.aws_region
          title  = "SQS Queue Metrics"
          period = 300
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.username}-performance-dashboard"
  })
}
EOF

# terraform/outputs.tf
cat > terraform/outputs.tf << 'EOF'
output "api_gateway_url" {
  description = "URL of the API Gateway performance endpoint"
  value       = "https://${aws_api_gateway_rest_api.optimized_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.optimized_api.id
}

output "api_key" {
  description = "API key for performance testing"
  value       = aws_api_gateway_api_key.performance_api_key.value
  sensitive   = true
}

output "performance_function_name" {
  description = "Name of the performance Lambda function"
  value       = aws_lambda_function.performance_function.function_name
}

output "load_tester_function_name" {
  description = "Name of the load tester Lambda function"
  value       = aws_lambda_function.load_tester.function_name
}

output "sqs_scaler_function_name" {
  description = "Name of the SQS scaler Lambda function"
  value       = aws_lambda_function.sqs_scaler.function_name
}

output "sqs_queue_url" {
  description = "URL of the high-throughput SQS queue"
  value       = aws_sqs_queue.high_throughput_queue.url
}

output "performance_table_name" {
  description = "Name of the performance data DynamoDB table"
  value       = aws_dynamodb_table.performance_data.name
}

output "load_test_table_name" {
  description = "Name of the load test results DynamoDB table"
  value       = aws_dynamodb_table.load_test_results.name
}

output "dashboard_url" {
  description = "URL to the CloudWatch performance dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.performance_dashboard.dashboard_name}"
}

output "error_alarm_name" {
  description = "Name of the error rate alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_error_rate.alarm_name
}

output "duration_alarm_name" {
  description = "Name of the duration alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_duration.alarm_name
}

output "lab_completion_summary" {
  description = "Summary of deployed resources for Lab 9"
  value = {
    username = var.username
    region = var.aws_region
    lambda_functions = 3
    api_gateway_endpoints = 1
    sqs_queues = 2
    dynamodb_tables = 2
    cloudwatch_alarms = 2
    dashboard_widgets = 5
  }
}
EOF

echo "🔧 Creating Lambda function code..."

# lambda_functions/performance_function/lambda_function.py
cat > lambda_functions/performance_function/lambda_function.py << 'EOF'
import json
import time
import os
import uuid
import concurrent.futures
from datetime import datetime
import boto3

# Initialize AWS clients with connection pooling
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
cloudwatch = boto3.client('cloudwatch', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Performance optimization: Reuse connections
performance_table = dynamodb.Table(os.environ.get('PERFORMANCE_TABLE', 'performance-data'))

def lambda_handler(event, context):
    """
    High-performance Lambda function with optimizations:
    - Connection pooling and reuse
    - Concurrent processing
    - Custom metrics
    - Memory optimization
    """
    
    start_time = time.time()
    request_id = str(uuid.uuid4())
    
    try:
        # Parse request
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        operation = body.get('operation', 'default')
        
        # Emit custom metrics
        emit_custom_metrics(operation, start_time)
        
        # Route to appropriate operation
        if operation == 'default':
            result = default_operation(body)
        elif operation == 'concurrent_processing':
            result = concurrent_processing_operation(body)
        elif operation == 'database_batch':
            result = database_batch_operation(body)
        elif operation == 'cpu_intensive':
            result = cpu_intensive_operation(body)
        elif operation == 'memory_test':
            result = memory_test_operation(body)
        elif operation == 'connection_pool_test':
            result = connection_pool_test(body)
        else:
            result = default_operation(body)
        
        execution_time = (time.time() - start_time) * 1000  # milliseconds
        
        # Store performance data
        store_performance_data(request_id, operation, execution_time)
        
        # Emit final metrics
        cloudwatch.put_metric_data(
            Namespace='HighPerformance',
            MetricData=[
                {
                    'MetricName': 'ExecutionTime',
                    'Value': execution_time,
                    'Unit': 'Milliseconds',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': context.function_name},
                        {'Name': 'Operation', 'Value': operation}
                    ]
                },
                {
                    'MetricName': 'SuccessfulInvocations',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': context.function_name}
                    ]
                }
            ]
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'max-age=300'  # API Gateway caching
            },
            'body': json.dumps({
                'requestId': request_id,
                'operation': operation,
                'result': result,
                'performance': {
                    'executionTime': execution_time,
                    'functionMemory': context.memory_limit_in_mb,
                    'remainingTime': context.get_remaining_time_in_millis()
                },
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        execution_time = (time.time() - start_time) * 1000
        
        # Emit error metrics
        cloudwatch.put_metric_data(
            Namespace='HighPerformance',
            MetricData=[
                {
                    'MetricName': 'Errors',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': context.function_name}
                    ]
                }
            ]
        )
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': str(e),
                'requestId': request_id,
                'executionTime': execution_time
            })
        }

def emit_custom_metrics(operation, start_time):
    """Emit custom CloudWatch metrics for performance tracking"""
    try:
        cloudwatch.put_metric_data(
            Namespace='HighPerformance',
            MetricData=[
                {
                    'MetricName': 'FunctionInvocations',
                    'Value': 1,
                    'Unit': 'Count',
                    'Dimensions': [
                        {'Name': 'Operation', 'Value': operation}
                    ]
                }
            ]
        )
    except Exception as e:
        print(f"Error emitting metrics: {e}")

def default_operation(data):
    """Optimized default operation with minimal overhead"""
    return {
        'message': 'High-performance default operation completed',
        'processed_at': datetime.utcnow().isoformat(),
        'optimization': 'connection_pooling_enabled'
    }

def concurrent_processing_operation(data):
    """Demonstrate concurrent processing for improved performance"""
    concurrency = data.get('concurrency', 5)
    tasks = data.get('tasks', 10)
    
    def process_task(task_id):
        # Simulate processing work
        time.sleep(0.1)  # 100ms work
        return f"Task {task_id} completed"
    
    start_time = time.time()
    
    # Use ThreadPoolExecutor for concurrent processing
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(process_task, i) for i in range(tasks)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    
    execution_time = (time.time() - start_time) * 1000
    
    return {
        'concurrent_tasks': tasks,
        'concurrency_level': concurrency,
        'results': results,
        'total_execution_time': execution_time,
        'average_task_time': execution_time / tasks
    }

def database_batch_operation(data):
    """Demonstrate optimized batch database operations"""
    data_size = data.get('dataSize', 'medium')
    
    # Determine batch size based on data size
    batch_sizes = {
        'small': 5,
        'medium': 15,
        'large': 25
    }
    batch_size = batch_sizes.get(data_size, 15)
    
    start_time = time.time()
    
    # Batch write to DynamoDB
    with performance_table.batch_writer() as batch:
        for i in range(batch_size):
            batch.put_item(
                Item={
                    'id': str(uuid.uuid4()),
                    'timestamp': datetime.utcnow().isoformat(),
                    'data_size': data_size,
                    'batch_index': i,
                    'performance_test': True
                }
            )
    
    execution_time = (time.time() - start_time) * 1000
    
    return {
        'batch_size': batch_size,
        'data_size': data_size,
        'execution_time': execution_time,
        'throughput': batch_size / (execution_time / 1000)  # items per second
    }

def cpu_intensive_operation(data):
    """CPU-intensive operation for performance testing"""
    iterations = data.get('iterations', 10000)
    
    start_time = time.time()
    
    # CPU-intensive calculation
    result = 0
    for i in range(iterations):
        result += i ** 2
    
    execution_time = (time.time() - start_time) * 1000
    
    return {
        'iterations': iterations,
        'result': result,
        'execution_time': execution_time,
        'operations_per_second': iterations / (execution_time / 1000)
    }

def memory_test_operation(data):
    """Memory allocation test for optimization analysis"""
    size_mb = data.get('sizeMB', 10)
    
    start_time = time.time()
    
    # Allocate memory
    large_list = [i for i in range(size_mb * 100000)]  # Approximate MB allocation
    
    execution_time = (time.time() - start_time) * 1000
    
    # Clear memory
    del large_list
    
    return {
        'allocated_mb': size_mb,
        'execution_time': execution_time
    }

def connection_pool_test(data):
    """Test connection pooling efficiency"""
    operations = data.get('operations', 10)
    
    start_time = time.time()
    results = []
    
    # Multiple DynamoDB operations using the same connection
    for i in range(operations):
        try:
            # Quick scan operation
            response = performance_table.scan(
                Limit=1,
                ProjectionExpression='id'
            )
            results.append(f"Operation {i}: {len(response.get('Items', []))} items")
        except Exception as e:
            results.append(f"Operation {i}: Error - {str(e)}")
    
    execution_time = (time.time() - start_time) * 1000
    
    return {
        'operations': operations,
        'results': results,
        'total_time': execution_time,
        'average_time_per_operation': execution_time / operations,
        'connection_reuse': True
    }

def store_performance_data(request_id, operation, execution_time):
    """Store performance metrics in DynamoDB"""
    try:
        performance_table.put_item(
            Item={
                'id': request_id,
                'timestamp': datetime.utcnow().isoformat(),
                'operation': operation,
                'execution_time': execution_time,
                'ttl': int(time.time()) + 86400  # 24 hour TTL
            }
        )
    except Exception as e:
        print(f"Error storing performance data: {e}")
EOF

# lambda_functions/load_tester/lambda_function.py
cat > lambda_functions/load_tester/lambda_function.py << 'EOF'
import json
import time
import os
import uuid
import concurrent.futures
from datetime import datetime
import boto3

# Initialize AWS clients
lambda_client = boto3.client('lambda', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
cloudwatch = boto3.client('cloudwatch', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# DynamoDB table for storing load test results
results_table = dynamodb.Table(os.environ.get('LOAD_TEST_RESULTS_TABLE', 'load-test-results'))

def lambda_handler(event, context):
    """
    Load tester function that generates concurrent requests
    to test the performance of target Lambda functions
    """
    
    start_time = time.time()
    test_id = str(uuid.uuid4())
    
    try:
        # Parse request
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        # Load test configuration
        concurrent_requests = body.get('concurrentRequests', 10)
        total_requests = body.get('totalRequests', 50)
        target_function = body.get('targetFunction', os.environ.get('TARGET_FUNCTION_NAME'))
        test_payload = body.get('testPayload', {'operation': 'default'})
        
        print(f"Starting load test {test_id}: {concurrent_requests} concurrent, {total_requests} total")
        
        # Execute load test
        results = execute_load_test(
            target_function, 
            concurrent_requests, 
            total_requests, 
            test_payload
        )
        
        total_time = (time.time() - start_time) * 1000  # milliseconds
        
        # Calculate performance metrics
        metrics = calculate_performance_metrics(results, total_time)
        
        # Store results in DynamoDB
        store_load_test_results(test_id, {
            'concurrent_requests': concurrent_requests,
            'total_requests': total_requests,
            'target_function': target_function,
            'metrics': metrics,
            'total_time': total_time
        })
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'test_id': test_id,
                'load_test_results': {
                    'configuration': {
                        'concurrent_requests': concurrent_requests,
                        'total_requests': total_requests,
                        'target_function': target_function
                    },
                    'metrics': metrics,
                    'total_execution_time': total_time,
                    'timestamp': datetime.utcnow().isoformat()
                }
            })
        }
        
    except Exception as e:
        execution_time = (time.time() - start_time) * 1000
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': str(e),
                'test_id': test_id,
                'execution_time': execution_time
            })
        }

def execute_load_test(target_function, concurrent_requests, total_requests, test_payload):
    """Execute concurrent load test against target function"""
    
    results = []
    requests_per_batch = max(1, total_requests // concurrent_requests)
    
    def invoke_function(batch_id):
        batch_results = []
        
        for i in range(requests_per_batch):
            request_start = time.time()
            
            try:
                response = lambda_client.invoke(
                    FunctionName=target_function,
                    InvocationType='RequestResponse',
                    Payload=json.dumps(test_payload)
                )
                
                request_time = (time.time() - request_start) * 1000
                
                # Parse response
                response_payload = json.loads(response['Payload'].read())
                status_code = response.get('StatusCode', 200)
                
                batch_results.append({
                    'batch_id': batch_id,
                    'request_id': i,
                    'status_code': status_code,
                    'response_time': request_time,
                    'success': status_code == 200,
                    'response_size': len(json.dumps(response_payload)) if response_payload else 0
                })
                
            except Exception as e:
                request_time = (time.time() - request_start) * 1000
                batch_results.append({
                    'batch_id': batch_id,
                    'request_id': i,
                    'status_code': 500,
                    'response_time': request_time,
                    'success': False,
                    'error': str(e),
                    'response_size': 0
                })
        
        return batch_results
    
    # Execute concurrent batches
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
        futures = [executor.submit(invoke_function, batch_id) for batch_id in range(concurrent_requests)]
        
        for future in concurrent.futures.as_completed(futures):
            batch_results = future.result()
            results.extend(batch_results)
    
    return results

def calculate_performance_metrics(results, total_time):
    """Calculate comprehensive performance metrics"""
    
    if not results:
        return {}
    
    response_times = [r['response_time'] for r in results]
    successful_requests = [r for r in results if r['success']]
    failed_requests = [r for r in results if not r['success']]
    
    response_times.sort()
    
    metrics = {
        'total_requests': len(results),
        'successful_requests': len(successful_requests),
        'failed_requests': len(failed_requests),
        'success_rate': (len(successful_requests) / len(results)) * 100,
        'failure_rate': (len(failed_requests) / len(results)) * 100,
        
        # Response time metrics
        'avg_response_time': sum(response_times) / len(response_times),
        'min_response_time': min(response_times),
        'max_response_time': max(response_times),
        'median_response_time': response_times[len(response_times) // 2],
        
        # Percentiles
        'p95_response_time': response_times[int(len(response_times) * 0.95)] if len(response_times) > 0 else 0,
        'p99_response_time': response_times[int(len(response_times) * 0.99)] if len(response_times) > 0 else 0,
        
        # Throughput metrics
        'requests_per_second': len(results) / (total_time / 1000),
        'successful_requests_per_second': len(successful_requests) / (total_time / 1000),
    }
    
    return metrics

def store_load_test_results(test_id, data):
    """Store load test results in DynamoDB"""
    try:
        results_table.put_item(
            Item={
                'test_id': test_id,
                'timestamp': datetime.utcnow().isoformat(),
                'configuration': data['configuration'],
                'metrics': data['metrics'],
                'total_time': data['total_time'],
                'ttl': int(time.time()) + 604800  # 7 days TTL
            }
        )
    except Exception as e:
        print(f"Error storing load test results: {e}")
EOF

# lambda_functions/sqs_scaler/lambda_function.py
cat > lambda_functions/sqs_scaler/lambda_function.py << 'EOF'
import json
import time
import os
import uuid
from datetime import datetime
import boto3

# Initialize AWS clients
cloudwatch = boto3.client('cloudwatch', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Performance table for storing processing results
performance_table = dynamodb.Table(os.environ.get('PERFORMANCE_TABLE', 'performance-data'))

def lambda_handler(event, context):
    """
    SQS message processor optimized for high throughput
    Processes messages in batches for maximum efficiency
    """
    
    start_time = time.time()
    batch_id = str(uuid.uuid4())
    
    try:
        # Parse SQS event
        records = event.get('Records', [])
        processed_messages = []
        failed_messages = []
        
        print(f"Processing batch {batch_id} with {len(records)} messages")
        
        # Process each message in the batch
        for record in records:
            message_result = process_message(record)
            
            if message_result['success']:
                processed_messages.append(message_result)
            else:
                failed_messages.append({
                    'itemIdentifier': record['messageId']
                })
        
        batch_time = (time.time() - start_time) * 1000
        
        # Store batch processing results
        store_batch_results(batch_id, {
            'total_messages': len(records),
            'successful_messages': len(processed_messages),
            'failed_messages': len(failed_messages),
            'batch_time': batch_time,
            'messages_per_second': len(records) / (batch_time / 1000)
        })
        
        # Return failed message IDs for SQS to retry
        response = {
            'batchItemFailures': failed_messages
        }
        
        print(f"Batch {batch_id} completed: {len(processed_messages)} successful, {len(failed_messages)} failed")
        
        return response
        
    except Exception as e:
        print(f"Error processing batch {batch_id}: {e}")
        
        # Return all messages as failed for retry
        return {
            'batchItemFailures': [
                {'itemIdentifier': record['messageId']} 
                for record in event.get('Records', [])
            ]
        }

def process_message(record):
    """Process individual SQS message"""
    
    message_start = time.time()
    message_id = record['messageId']
    
    try:
        # Parse message body
        body = json.loads(record['body'])
        
        # Simulate message processing based on message type
        processing_type = body.get('processing_type', 'standard')
        data_size = body.get('data_size', 'medium')
        
        # Different processing patterns for performance testing
        if processing_type == 'cpu_intensive':
            result = process_cpu_intensive(body)
        elif processing_type == 'io_intensive':
            result = process_io_intensive(body)
        elif processing_type == 'memory_intensive':
            result = process_memory_intensive(body)
        else:
            result = process_standard(body)
        
        processing_time = (time.time() - message_start) * 1000
        
        return {
            'message_id': message_id,
            'success': True,
            'processing_time': processing_time,
            'processing_type': processing_type,
            'data_size': data_size,
            'result': result
        }
        
    except Exception as e:
        processing_time = (time.time() - message_start) * 1000
        
        return {
            'message_id': message_id,
            'success': False,
            'processing_time': processing_time,
            'error': str(e)
        }

def process_standard(data):
    """Standard message processing"""
    # Simulate standard processing work
    time.sleep(0.05)  # 50ms processing time
    
    return {
        'type': 'standard',
        'processed_at': datetime.utcnow().isoformat(),
        'data_points': data.get('data_points', 100)
    }

def process_cpu_intensive(data):
    """CPU-intensive message processing"""
    iterations = data.get('iterations', 1000)
    
    # CPU-intensive calculation
    result = 0
    for i in range(iterations):
        result += i ** 2
    
    return {
        'type': 'cpu_intensive',
        'iterations': iterations,
        'result': result,
        'processed_at': datetime.utcnow().isoformat()
    }

def process_io_intensive(data):
    """I/O-intensive message processing (simulated with DynamoDB write)"""
    try:
        # Simulate I/O operation with DynamoDB write
        performance_table.put_item(
            Item={
                'id': str(uuid.uuid4()),
                'timestamp': datetime.utcnow().isoformat(),
                'message_type': 'io_intensive',
                'data': data,
                'ttl': int(time.time()) + 3600  # 1 hour TTL
            }
        )
        
        return {
            'type': 'io_intensive',
            'database_write': True,
            'processed_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {
            'type': 'io_intensive',
            'database_write': False,
            'error': str(e),
            'processed_at': datetime.utcnow().isoformat()
        }

def process_memory_intensive(data):
    """Memory-intensive message processing"""
    size_mb = data.get('memory_size', 1)
    
    # Allocate memory
    large_list = [i for i in range(size_mb * 100000)]
    
    # Process the data
    total = sum(large_list)
    
    # Clean up
    del large_list
    
    return {
        'type': 'memory_intensive',
        'memory_allocated_mb': size_mb,
        'total': total,
        'processed_at': datetime.utcnow().isoformat()
    }

def store_batch_results(batch_id, metrics):
    """Store batch processing results"""
    try:
        performance_table.put_item(
            Item={
                'id': f"batch-{batch_id}",
                'timestamp': datetime.utcnow().isoformat(),
                'type': 'sqs_batch_processing',
                'metrics': metrics,
                'ttl': int(time.time()) + 86400  # 24 hour TTL
            }
        )
    except Exception as e:
        print(f"Error storing batch results: {e}")
EOF

echo "🛠️ Creating deployment and testing scripts..."

# scripts/deploy.sh
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash

# Lab 9 - Performance and Scaling - Terraform Deployment Script

set -e

echo "🚀 Lab 9 - Performance and Scaling Deployment"
echo "=============================================="

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform >= 1.0"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run 'aws configure'"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Navigate to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

# Check for terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found"
    echo "📝 Please create terraform.tfvars with your username:"
    echo "   username = \"user1\"  # Replace with your assigned username"
    exit 1
fi

# Check username configuration
USERNAME=$(grep "^username" terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
if [ "$USERNAME" = "user1" ] || [ -z "$USERNAME" ]; then
    echo "⚠️  WARNING: Username appears to be default or missing!"
    echo "📝 Please edit terraform.tfvars with YOUR assigned username"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Confirm deployment
echo ""
echo "🎯 Ready to deploy Lab 9 infrastructure!"
echo "This will create:"
echo "  • 3 high-performance Lambda functions"
echo "  • 1 optimized API Gateway with caching"
echo "  • 2 SQS queues for high-throughput processing"
echo "  • 2 DynamoDB tables for performance data"
echo "  • CloudWatch dashboard and alarms"
echo "  • Performance optimization configurations"
echo ""
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Deployment cancelled"
    exit 0
fi

# Apply deployment
echo "🚀 Deploying infrastructure..."
terraform apply tfplan

# Get outputs
echo ""
echo "📊 Deployment completed!"
echo ""
echo "🔗 Resource URLs:"
terraform output api_gateway_url
echo ""
echo "📋 Function Names:"
terraform output performance_function_name
terraform output load_tester_function_name
terraform output sqs_scaler_function_name
echo ""
echo "📈 Monitoring:"
terraform output dashboard_url
echo ""
echo "🔑 API Key (save this for testing):"
terraform output -raw api_key
echo ""
echo ""
echo "✅ Lab 9 deployment successful!"
echo "🧪 Run '../scripts/run_performance_tests.sh' to start testing"
EOF

chmod +x scripts/deploy.sh

# scripts/run_performance_tests.sh
cat > scripts/run_performance_tests.sh << 'EOF'
#!/bin/bash

# Lab 9 - Performance Testing Script

set -e

echo "🧪 Lab 9 - Performance Testing Suite"
echo "===================================="

# Get Terraform outputs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

echo "🔍 Getting deployment information..."
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
API_KEY=$(terraform output -raw api_key 2>/dev/null || echo "")

if [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
    echo "❌ Could not get API URL or API Key from Terraform outputs"
    echo "📝 Make sure you've deployed the infrastructure first: ./scripts/deploy.sh"
    exit 1
fi

echo "✅ API URL: $API_URL"
echo "✅ API Key configured"
echo ""

# Test 1: Default Operation
echo "🔬 Test 1: Default Operation Performance"
echo "----------------------------------------"
curl -s -X POST "$API_URL/performance" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"operation": "default"}' | jq '.performance'

echo ""

# Test 2: Concurrent Processing
echo "🔬 Test 2: Concurrent Processing (10 threads)"
echo "----------------------------------------------"
curl -s -X POST "$API_URL/performance" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"operation": "concurrent_processing", "concurrency": 10, "tasks": 20}' | jq '.result'

echo ""

# Test 3: Database Batch Operations
echo "🔬 Test 3: Database Batch Operations (Large Dataset)"
echo "----------------------------------------------------"
curl -s -X POST "$API_URL/performance" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"operation": "database_batch", "dataSize": "large"}' | jq '.result'

echo ""

# Test 4: CPU-Intensive Operations
echo "🔬 Test 4: CPU-Intensive Operations (10,000 iterations)"
echo "-------------------------------------------------------"
curl -s -X POST "$API_URL/performance" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"operation": "cpu_intensive", "iterations": 10000}' | jq '.result'

echo ""

# Test 5: Memory Test
echo "🔬 Test 5: Memory Allocation Test (20MB)"
echo "----------------------------------------"
curl -s -X POST "$API_URL/performance" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"operation": "memory_test", "sizeMB": 20}' | jq '.result'

echo ""

# Test 6: Connection Pool Test
echo "🔬 Test 6: Connection Pool Efficiency (15 operations)"
echo "-----------------------------------------------------"
curl -s -X POST "$API_URL/performance" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"operation": "connection_pool_test", "operations": 15}' | jq '.result'

echo ""
echo "✅ Performance tests completed!"
echo "📊 Check the CloudWatch dashboard for detailed metrics:"
terraform output dashboard_url
echo ""
echo "🔄 To run load tests: ../scripts/run_load_tests.sh"
EOF

chmod +x scripts/run_performance_tests.sh

# scripts/run_load_tests.sh
cat > scripts/run_load_tests.sh << 'EOF'
#!/bin/bash

# Lab 9 - Load Testing Script

set -e

echo "⚡ Lab 9 - Load Testing Suite"
echo "============================="

# Get Terraform outputs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

echo "🔍 Getting deployment information..."
LOAD_TESTER_FUNCTION=$(terraform output -raw load_tester_function_name 2>/dev/null || echo "")
PERFORMANCE_FUNCTION=$(terraform output -raw performance_function_name 2>/dev/null || echo "")

if [ -z "$LOAD_TESTER_FUNCTION" ] || [ -z "$PERFORMANCE_FUNCTION" ]; then
    echo "❌ Could not get function names from Terraform outputs"
    exit 1
fi

echo "✅ Load Tester: $LOAD_TESTER_FUNCTION"
echo "✅ Target Function: $PERFORMANCE_FUNCTION"
echo ""

# Load Test 1: Light Load
echo "🔬 Load Test 1: Light Load (5 concurrent, 25 total)"
echo "---------------------------------------------------"
aws lambda invoke \
  --function-name "$LOAD_TESTER_FUNCTION" \
  --payload '{
    "concurrentRequests": 5,
    "totalRequests": 25,
    "targetFunction": "'$PERFORMANCE_FUNCTION'",
    "testPayload": {"operation": "default"}
  }' \
  load-test-light.json

cat load-test-light.json | jq '.load_test_results.metrics'
echo ""

# Load Test 2: Medium Load
echo "🔬 Load Test 2: Medium Load (10 concurrent, 50 total)"
echo "-----------------------------------------------------"
aws lambda invoke \
  --function-name "$LOAD_TESTER_FUNCTION" \
  --payload '{
    "concurrentRequests": 10,
    "totalRequests": 50,
    "targetFunction": "'$PERFORMANCE_FUNCTION'",
    "testPayload": {"operation": "concurrent_processing", "concurrency": 5}
  }' \
  load-test-medium.json

cat load-test-medium.json | jq '.load_test_results.metrics'
echo ""

# Load Test 3: Heavy Load
echo "🔬 Load Test 3: Heavy Load (20 concurrent, 100 total)"
echo "-----------------------------------------------------"
aws lambda invoke \
  --function-name "$LOAD_TESTER_FUNCTION" \
  --payload '{
    "concurrentRequests": 20,
    "totalRequests": 100,
    "targetFunction": "'$PERFORMANCE_FUNCTION'",
    "testPayload": {"operation": "cpu_intensive", "iterations": 5000}
  }' \
  load-test-heavy.json

cat load-test-heavy.json | jq '.load_test_results.metrics'
echo ""

echo "✅ Load tests completed!"
echo "📊 Check the CloudWatch dashboard for detailed metrics:"
terraform output dashboard_url
echo ""
echo "📈 Load test results saved to:"
echo "  - load-test-light.json"
echo "  - load-test-medium.json"
echo "  - load-test-heavy.json"
EOF

chmod +x scripts/run_load_tests.sh

# scripts/generate_sqs_load.sh
cat > scripts/generate_sqs_load.sh << 'EOF'
#!/bin/bash

# Lab 9 - SQS Load Generation Script

set -e

echo "📬 Lab 9 - SQS Load Generation"
echo "=============================="

# Default values
MESSAGE_COUNT=${1:-100}
BATCH_SIZE=${2:-10}

# Get SQS queue URL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null || echo "")

if [ -z "$SQS_QUEUE_URL" ]; then
    echo "❌ Could not get SQS queue URL from Terraform outputs"
    exit 1
fi

echo "✅ SQS Queue: $SQS_QUEUE_URL"
echo "📊 Sending $MESSAGE_COUNT messages in batches of $BATCH_SIZE"
echo ""

# Function to send a batch of messages
send_batch() {
    local batch_id=$1
    local start_idx=$2
    local end_idx=$3
    
    echo "📤 Sending batch $batch_id (messages $start_idx-$end_idx)..."
    
    # Generate messages for this batch
    entries=""
    for i in $(seq $start_idx $end_idx); do
        # Generate different message types for variety
        case $((i % 4)) in
            0) processing_type="standard" ;;
            1) processing_type="cpu_intensive" ;;
            2) processing_type="io_intensive" ;;
            3) processing_type="memory_intensive" ;;
        esac
        
        case $((i % 3)) in
            0) data_size="small" ;;
            1) data_size="medium" ;;
            2) data_size="large" ;;
        esac
        
        message_body=$(cat <<EOF
{
  "message_id": "$i",
  "batch_id": "$batch_id",
  "processing_type": "$processing_type",
  "data_size": "$data_size",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "iterations": $((1000 + (i % 5000))),
  "memory_size": $((1 + (i % 10))),
  "data_points": $((100 + (i % 900)))
}
EOF
)
        
        if [ -n "$entries" ]; then
            entries="$entries,"
        fi
        
        entries="$entries{\"Id\":\"msg-$i\",\"MessageBody\":\"$(echo "$message_body" | tr -d '\n' | sed 's/"/\\"/g')\"}"
    done
    
    # Send the batch
    aws sqs send-message-batch \
        --queue-url "$SQS_QUEUE_URL" \
        --entries "[$entries]" \
        --output table > /dev/null
    
    echo "✅ Batch $batch_id sent successfully"
}

# Calculate number of batches
total_batches=$(( (MESSAGE_COUNT + BATCH_SIZE - 1) / BATCH_SIZE ))

echo "🚀 Starting SQS load generation..."
echo "📦 Total batches: $total_batches"
echo ""

# Send messages in batches
for batch in $(seq 1 $total_batches); do
    start_idx=$(( (batch - 1) * BATCH_SIZE + 1 ))
    end_idx=$(( batch * BATCH_SIZE ))
    
    # Don't exceed the total message count
    if [ $end_idx -gt $MESSAGE_COUNT ]; then
        end_idx=$MESSAGE_COUNT
    fi
    
    send_batch $batch $start_idx $end_idx
    
    # Small delay to avoid overwhelming the queue
    sleep 0.1
done

echo ""
echo "✅ SQS load generation completed!"
echo "📊 Sent $MESSAGE_COUNT messages to the queue"
echo "📈 Monitor processing in the CloudWatch dashboard:"
terraform output dashboard_url
EOF

chmod +x scripts/generate_sqs_load.sh

echo "📄 Creating documentation..."

# docs/DEPLOYMENT.md
cat > docs/DEPLOYMENT.md << 'EOF'
# Lab 9 - Deployment Guide

## Prerequisites

Before deploying Lab 9, ensure you have:

1. **AWS CLI configured** with appropriate credentials
2. **Terraform >= 1.0** installed  
3. **jq** installed for JSON processing (optional but recommended)
4. **Assigned username** (user1, user2, user3, etc.)

## Quick Start

### 1. Configure Username

Edit `terraform/terraform.tfvars`:
```hcl
# CRITICAL: Replace with YOUR assigned username
username = "user2"  # Change to your assigned username
```

### 2. Deploy Infrastructure

```bash
./scripts/deploy.sh
```

### 3. Test Functions

```bash
./scripts/run_performance_tests.sh
./scripts/run_load_tests.sh
./scripts/generate_sqs_load.sh 1000 10
```

### 4. Clean Up

```bash
cd terraform
terraform destroy
```

## Infrastructure Components

- **3 Lambda Functions**: Performance testing, Load testing, SQS processing
- **1 API Gateway**: Optimized with caching and throttling
- **2 SQS Queues**: High-throughput processing with DLQ
- **2 DynamoDB Tables**: Performance data storage with TTL
- **CloudWatch Resources**: Dashboard, alarms, and custom metrics

## Performance Optimizations

- **Provisioned Concurrency**: Eliminates cold starts
- **Reserved Concurrency**: Prevents throttling
- **API Gateway Caching**: Reduces backend load
- **Connection Pooling**: Reuses AWS service connections
- **Batch Processing**: Optimizes SQS throughput

## Troubleshooting

1. **Username conflicts**: Ensure unique username in terraform.tfvars
2. **Permission errors**: Verify AWS credentials and permissions
3. **Resource limits**: Check AWS account limits
4. **Terraform state issues**: Use `terraform refresh` to sync state
EOF

# docs/PERFORMANCE_GUIDE.md
cat > docs/PERFORMANCE_GUIDE.md << 'EOF'
# Lab 9 - Performance Optimization Guide

## Performance Optimizations Implemented

### 1. Lambda Function Optimizations

#### Memory and CPU Optimization
- **Memory Size**: 1024 MB (configurable)
- **CPU Allocation**: Proportional to memory (~1.8 vCPUs)
- **Timeout**: 300 seconds for complex operations

#### Concurrency Management
- **Provisioned Concurrency**: 10 instances (eliminates cold starts)
- **Reserved Concurrency**: 50 instances (prevents throttling)
- **Benefits**: Consistent performance and predictable scaling

#### Connection Pooling
- **Database Connections**: Reused across invocations
- **AWS Service Clients**: Initialized outside handler
- **Result**: Reduced latency and improved throughput

### 2. API Gateway Optimizations

#### Caching Configuration
- **TTL**: 300 seconds (5 minutes)
- **Cache Keys**: Automatic based on request parameters
- **Benefits**: Reduced backend load and faster response times

#### Throttling Protection
- **Rate Limit**: 1000 requests/second
- **Burst Limit**: 2000 requests
- **Usage Plans**: API key-based access control

### 3. SQS High-Throughput Processing

#### Batch Configuration
- **Batch Size**: 10 messages (maximum for standard queues)
- **Batching Window**: 5 seconds
- **Long Polling**: 20 seconds (reduces empty receives)
- **Benefits**: Higher throughput and reduced costs

#### Dead Letter Queue
- **Max Receive Count**: 3 attempts
- **Retention**: 14 days
- **Benefits**: Handles failed messages without blocking processing

## Performance Testing Strategies

### 1. Individual Function Testing
```bash
./scripts/run_performance_tests.sh
```

### 2. Load Testing
```bash
./scripts/run_load_tests.sh
```

### 3. SQS Throughput Testing
```bash
./scripts/generate_sqs_load.sh 1000 10
```

## Performance Metrics to Monitor

### Lambda Metrics
- **Duration**: Average, P95, P99 response times
- **Concurrent Executions**: Current concurrent invocations
- **Throttles**: Number of throttled requests
- **Errors**: Error rate and error types

### API Gateway Metrics
- **Latency**: End-to-end request latency
- **Count**: Total number of requests
- **4XX/5XX Errors**: Client and server error rates
- **Cache Hit/Miss**: Caching effectiveness

### SQS Metrics
- **Messages Sent/Received**: Queue throughput
- **Visible Messages**: Queue depth
- **Dead Letter Queue**: Failed message count

## Best Practices Summary

1. **Monitor Everything**: Use comprehensive monitoring and alerting
2. **Test Regularly**: Implement continuous performance testing
3. **Optimize Gradually**: Make incremental improvements
4. **Consider Cost**: Balance performance with cost requirements
5. **Document Changes**: Track performance optimization changes
6. **Automate Deployment**: Use Infrastructure as Code for consistency
EOF

echo "✅ Lab 9 generation completed successfully!"
echo ""
echo "📁 Generated complete lab structure:"
echo "   ├── Developing_Serverless_Solutions_AWS_Day3_Lab9.md (lab instructions)"
echo "   ├── README.md (main guide)"
echo "   ├── terraform/ (complete Terraform configuration)"
echo "   │   ├── All .tf files for infrastructure"
echo "   │   └── terraform.tfvars (configuration template)"
echo "   ├── lambda_functions/ (3 optimized Python functions)"
echo "   │   ├── performance_function/"
echo "   │   ├── load_tester/"
echo "   │   └── sqs_scaler/"
echo "   ├── scripts/ (deployment and testing automation)"
echo "   │   ├── deploy.sh"
echo "   │   ├── run_performance_tests.sh"
echo "   │   ├── run_load_tests.sh"
echo "   │   └── generate_sqs_load.sh"
echo "   └── docs/ (comprehensive documentation)"
echo "       ├── DEPLOYMENT.md"
echo "       └── PERFORMANCE_GUIDE.md"
echo ""
echo "🚀 To deploy and test:"
echo "1. Edit terraform/terraform.tfvars with your username"
echo "2. ./scripts/deploy.sh"
echo "3. ./scripts/run_performance_tests.sh"
echo "4. ./scripts/run_load_tests.sh"
echo ""
echo "✨ Key improvements over AWS CLI version:"
echo "   • Complete Infrastructure as Code approach"
echo "   • Automated deployment and testing workflows"
echo "   • Comprehensive performance monitoring"
echo "   • Easy cleanup with 'terraform destroy'"
echo "   • Version control friendly configuration"
echo "   • Consistent cross-environment deployments"
echo "   • Educational IaC best practices demonstration"

# Return to the parent directory
cd ..

echo ""
echo "🎉 Lab 9 Terraform Generator Script completed successfully!"
echo ""
echo "📍 Generated lab directory: $LAB_DIR"
echo ""
echo "🔧 Next steps:"
echo "1. cd $LAB_DIR"
echo "2. Edit terraform/terraform.tfvars with your assigned username"
echo "3. ./scripts/deploy.sh"
echo "4. Follow the lab instructions in Developing_Serverless_Solutions_AWS_Day3_Lab9.md"
echo ""
echo "💡 This script created a complete Lab 9 conversion from AWS CLI to Terraform!"
echo "   The lab demonstrates Infrastructure as Code best practices while"
echo "   maintaining all the original performance optimization learning objectives."