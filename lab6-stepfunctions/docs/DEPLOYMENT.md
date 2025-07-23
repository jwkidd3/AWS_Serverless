# Deployment Guide

This guide provides step-by-step instructions for deploying the Step Functions workflow using Terraform.

## Prerequisites

### Required Tools
- **AWS CLI**: Version 2.0 or later
- **Terraform**: Version 1.0 or later
- **Python**: 3.9 or later (for local testing)

### AWS Requirements
- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- IAM permissions for creating:
  - Lambda functions
  - Step Functions state machines
  - API Gateway resources
  - IAM roles and policies
  - CloudWatch log groups

### Verification Commands
```bash
# Verify AWS CLI
aws --version
aws sts get-caller-identity

# Verify Terraform
terraform --version

# Verify Python
python3 --version
```

## Quick Deploy

### 1. Configure Variables
```bash
nano terraform/terraform.tfvars
```

Required configuration:
```hcl
username = "your-username"  # Must be unique in shared environments
aws_region = "us-east-1"    # Your preferred region
```

### 2. Deploy Infrastructure
```bash
# Initialize Terraform
cd terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply
```

### 3. Test Deployment
```bash
# Return to lab root
cd ..

# Run test script
./scripts/test_workflow.sh
```

## Detailed Deployment Steps

### Step 1: Environment Setup

#### 1.1 AWS Configuration
```bash
# Configure AWS credentials (if not already done)
aws configure

# Verify access
aws sts get-caller-identity
```

### Step 2: Configuration

#### 2.1 Terraform Variables
Edit `terraform/terraform.tfvars`:
```hcl
# Required
username = "user1"

# Optional (with defaults)
aws_region = "us-east-1"
log_level = "INFO"
log_retention_days = 7
api_stage_name = "prod"
```

#### 2.2 Variable Validation
Terraform will validate:
- Username format (lowercase letters and numbers only)
- Valid AWS region
- Supported log levels and retention periods

### Step 3: Infrastructure Deployment

#### 3.1 Initialize Terraform
```bash
cd terraform
terraform init
```

This will:
- Download required providers (AWS, Archive)
- Initialize backend state
- Validate configuration syntax

#### 3.2 Plan Deployment
```bash
terraform plan
```

Review the planned resources:
- 3 Lambda functions
- 1 Step Functions state machine
- 1 API Gateway with deployment
- IAM roles and policies
- 5 CloudWatch log groups

#### 3.3 Apply Configuration
```bash
terraform apply
```

Type `yes` when prompted. Deployment typically takes 2-3 minutes.

#### 3.4 Verify Deployment
```bash
# Check outputs
terraform output

# Verify resources in AWS Console
terraform output state_machine_console_url
```

### Step 4: Testing

#### 4.1 API Gateway Test
```bash
# Get API URL
API_URL=$(terraform output -raw api_gateway_url)

# Test successful execution
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"userId": "test-user", "dataType": "sales_data"}'
```

#### 4.2 Step Functions Console Test
1. Open Step Functions console URL from terraform output
2. Click "Start execution"
3. Use sample input:
```json
{
  "userId": "console-user",
  "dataType": "customer_data"
}
```

#### 4.3 Automated Testing
```bash
# Return to lab root
cd ..

# Run comprehensive tests
./scripts/test_workflow.sh

# Validate deployment
./scripts/validate.sh
```

## Cleanup

### Destroy Infrastructure
```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This will remove all created resources.

## Troubleshooting Deployment

### Common Issues

#### 1. Insufficient Permissions
**Error**: Access denied creating resources
**Solution**: Verify IAM permissions for all required services

#### 2. Resource Name Conflicts
**Error**: Resource already exists
**Solution**: Ensure unique username prefix

#### 3. Archive Creation Failures
**Error**: Failed to create Lambda deployment package
**Solution**: Verify Lambda function code exists in correct directories

### Debugging Commands

```bash
# Check Terraform state
terraform state list

# Show resource details
terraform state show aws_lambda_function.process_data

# Validate configuration
terraform validate

# Check AWS resource status
aws lambda get-function --function-name [username]-process-data
aws stepfunctions describe-state-machine --state-machine-arn [arn]
```
