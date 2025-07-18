# Developing Serverless Solutions on AWS - Day 1 - Lab 2
## Infrastructure as Code Implementation

**Lab Duration:** 75 minutes

---

## Lab Overview

In this lab, you will learn to deploy serverless applications using Infrastructure as Code (IaC) approaches. You'll work with both AWS SAM (Serverless Application Model) and Terraform to create repeatable, version-controlled deployments of serverless resources.

## Lab Objectives

By the end of this lab, you will be able to:
- Create and deploy serverless applications using AWS SAM templates
- Implement serverless infrastructure using Terraform configurations
- Compare declarative vs. imperative infrastructure approaches
- Understand the benefits of Infrastructure as Code for serverless applications
- Use SAM CLI for local testing and deployment
- Apply username prefixing in IaC templates

## Prerequisites

- Completion of Lab 1
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Basic understanding of YAML and HCL syntax

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from Lab 1. If needed, create a new environment following the steps from Lab 1.

### Username Prefixing in IaC
**IMPORTANT:** All resources defined in your IaC templates must include your username prefix to avoid conflicts.

**Example:** If your username is `user3`, resources should be named:
- Lambda function: `user3-iac-hello-function`
- API Gateway: `user3-iac-hello-api`
- S3 bucket: `user3-iac-deployment-bucket`

---

## Task 1: Deploy with AWS SAM

### Step 1.1: Install and Configure SAM CLI

1. In your Cloud9 terminal, verify SAM CLI installation:
```bash
sam --version
```

2. If SAM CLI is not installed, install it:
```bash
pip install aws-sam-cli
```

3. Create a new directory for your SAM project:
```bash
mkdir [your-username]-sam-project
cd [your-username]-sam-project
```

### Step 1.2: Create SAM Template

1. Create a `template.yaml` file with the following content:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Simple serverless application using SAM

Parameters:
  Username:
    Type: String
    Default: user1
    Description: Username prefix for resources

Globals:
  Function:
    Timeout: 30
    Runtime: python3.9

Resources:
  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Username}-sam-hello-function'
      CodeUri: src/
      Handler: app.lambda_handler
      Events:
        HelloWorld:
          Type: Api
          Properties:
            RestApiId: !Ref HelloWorldApi
            Path: /hello
            Method: get

  HelloWorldApi:
    Type: AWS::Serverless::Api
    Properties:
      Name: !Sub '${Username}-sam-hello-api'
      StageName: prod
      Cors:
        AllowMethods: "'GET,POST,OPTIONS'"
        AllowHeaders: "'content-type'"
        AllowOrigin: "'*'"

  DeploymentBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${Username}-sam-deployment-${AWS::AccountId}'
      VersioningConfiguration:
        Status: Enabled

Outputs:
  HelloWorldApi:
    Description: "API Gateway endpoint URL"
    Value: !Sub "https://${HelloWorldApi}.execute-api.${AWS::Region}.amazonaws.com/prod/hello/"
  
  HelloWorldFunction:
    Description: "Hello World Lambda Function ARN"
    Value: !GetAtt HelloWorldFunction.Arn
```

### Step 1.3: Create Lambda Function Code

1. Create the source code directory and function:
```bash
mkdir src
```

2. Create `src/app.py`:

```python
import json
import datetime
import os

def lambda_handler(event, context):
    """
    SAM-deployed Lambda function
    """
    
    # Get function details from environment
    function_name = context.function_name
    function_version = context.function_version
    
    # Extract request information
    http_method = event.get('httpMethod', 'Unknown')
    path = event.get('path', 'Unknown')
    query_params = event.get('queryStringParameters') or {}
    
    # Get name from query parameters or use default
    name = query_params.get('name', 'World')
    
    # Create response
    response_data = {
        'message': f'Hello {name} from SAM!',
        'timestamp': datetime.datetime.now().isoformat(),
        'function_name': function_name,
        'function_version': function_version,
        'method': http_method,
        'path': path,
        'deployment_method': 'AWS SAM',
        'environment': os.environ.get('AWS_REGION', 'unknown')
    }
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(response_data, indent=2)
    }
```

### Step 1.4: Deploy with SAM

1. Build the SAM application:
```bash
sam build
```

2. Deploy the application (replace `user1` with your assigned username):
```bash
sam deploy --guided --parameter-overrides Username=[your-username]
```

3. When prompted, configure the deployment:
   - **Stack Name:** `[your-username]-sam-stack`
   - **AWS Region:** `us-east-1`
   - **Confirm changes before deploy:** `Y`
   - **Allow SAM CLI IAM role creation:** `Y`
   - **Save parameters to samconfig.toml:** `Y`

### Step 1.5: Test SAM Deployment

1. Get the API Gateway URL from the stack outputs:
```bash
aws cloudformation describe-stacks \
  --stack-name [your-username]-sam-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`HelloWorldApi`].OutputValue' \
  --output text
```

2. Test the API:
```bash
curl "[your-api-url]"
curl "[your-api-url]?name=SAM"
```

---

## Task 2: Deploy with Terraform

### Step 2.1: Install Terraform

1. Create a new directory for Terraform:
```bash
cd ~/environment
mkdir [your-username]-terraform-project
cd [your-username]-terraform-project
```

2. Download and install Terraform:
```bash
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

3. Verify installation:
```bash
terraform version
```

### Step 2.2: Create Terraform Configuration

1. Create `main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "username" {
  description = "Username prefix for resources"
  type        = string
  default     = "user1"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# S3 bucket for Lambda deployment package
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.username}-terraform-lambda-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_versioning" "lambda_bucket_versioning" {
  bucket = aws_s3_bucket.lambda_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_function.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.username}-terraform-lambda-role"

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
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "hello_world" {
  function_name = "${var.username}-terraform-hello-function"
  
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_zip.key
  
  runtime = "python3.9"
  handler = "lambda_function.lambda_handler"
  
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  role = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      DEPLOYMENT_METHOD = "Terraform"
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "hello_api" {
  name        = "${var.username}-terraform-hello-api"
  description = "Hello World API deployed with Terraform"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "hello_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "hello_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.hello_resource.id
  http_method = aws_api_gateway_method.hello_method.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.hello_world.invoke_arn
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.hello_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "hello_deployment" {
  depends_on = [
    aws_api_gateway_method.hello_method,
    aws_api_gateway_integration.hello_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  stage_name  = "prod"
}
```

2. Create `outputs.tf`:

```hcl
output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "${aws_api_gateway_deployment.hello_deployment.invoke_url}/hello"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.hello_world.function_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.lambda_bucket.id
}
```

### Step 2.3: Create Terraform Lambda Function

1. Create `lambda_function.py`:

```python
import json
import datetime
import os

def lambda_handler(event, context):
    """
    Terraform-deployed Lambda function
    """
    
    # Get function details
    function_name = context.function_name
    function_version = context.function_version
    
    # Extract request information
    http_method = event.get('httpMethod', 'Unknown')
    path = event.get('path', 'Unknown')
    query_params = event.get('queryStringParameters') or {}
    
    # Get name from query parameters or use default
    name = query_params.get('name', 'World')
    
    # Create response
    response_data = {
        'message': f'Hello {name} from Terraform!',
        'timestamp': datetime.datetime.now().isoformat(),
        'function_name': function_name,
        'function_version': function_version,
        'method': http_method,
        'path': path,
        'deployment_method': os.environ.get('DEPLOYMENT_METHOD', 'Terraform'),
        'environment': os.environ.get('AWS_REGION', 'unknown')
    }
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(response_data, indent=2)
    }
```

### Step 2.4: Deploy with Terraform

1. Initialize Terraform:
```bash
terraform init
```

2. Create a `terraform.tfvars` file:
```bash
echo 'username = "[your-username]"' > terraform.tfvars
```

3. Plan the deployment:
```bash
terraform plan
```

4. Apply the configuration:
```bash
terraform apply
```

5. Type `yes` when prompted to confirm the deployment.

### Step 2.5: Test Terraform Deployment

1. Get the API Gateway URL from Terraform outputs:
```bash
terraform output api_gateway_url
```

2. Test the API:
```bash
curl "$(terraform output -raw api_gateway_url)"
curl "$(terraform output -raw api_gateway_url)?name=Terraform"
```

---

## Task 3: Compare Deployments

### Step 3.1: Resource Comparison

1. List Lambda functions created by both methods:
```bash
aws lambda list-functions --query 'Functions[?contains(FunctionName, `[your-username]`)].{Name:FunctionName, Runtime:Runtime, LastModified:LastModified}'
```

2. List API Gateways:
```bash
aws apigateway get-rest-apis --query 'items[?contains(name, `[your-username]`)].{Name:name, Id:id, CreatedDate:createdDate}'
```

3. List S3 buckets:
```bash
aws s3 ls | grep [your-username]
```

### Step 3.2: Performance Comparison

1. Test both APIs multiple times and compare response times:
```bash
# SAM API
time curl -s "[sam-api-url]" > /dev/null

# Terraform API  
time curl -s "[terraform-api-url]" > /dev/null
```

2. Compare the responses to see deployment method differences.

---

## Task 4: Local Development and Testing

### Step 4.1: SAM Local Testing

1. Navigate back to your SAM project:
```bash
cd ~/environment/[your-username]-sam-project
```

2. Start the local API:
```bash
sam local start-api --port 3000
```

3. In a new terminal, test the local API:
```bash
curl http://localhost:3000/hello
curl http://localhost:3000/hello?name=Local
```

4. Stop the local server with `Ctrl+C`.

### Step 4.2: SAM Local Function Testing

1. Test the function locally:
```bash
sam local invoke HelloWorldFunction --event events/event.json
```

2. Create a test event file:
```bash
mkdir events
cat > events/event.json << 'EOF'
{
  "httpMethod": "GET",
  "path": "/hello",
  "queryStringParameters": {
    "name": "LocalTest"
  }
}
EOF
```

3. Run the test:
```bash
sam local invoke HelloWorldFunction --event events/event.json
```

---

## Task 5: Update and Redeploy

### Step 5.1: Update SAM Application

1. Modify `src/app.py` to add a new feature:

```python
# Add this function at the top of the file after imports
def get_system_info():
    """Get system information"""
    import platform
    return {
        'python_version': platform.python_version(),
        'system': platform.system(),
        'architecture': platform.architecture()[0]
    }

# Modify the response_data in lambda_handler to include:
response_data = {
    'message': f'Hello {name} from SAM!',
    'timestamp': datetime.datetime.now().isoformat(),
    'function_name': function_name,
    'function_version': function_version,
    'method': http_method,
    'path': path,
    'deployment_method': 'AWS SAM',
    'environment': os.environ.get('AWS_REGION', 'unknown'),
    'system_info': get_system_info()  # Add this line
}
```

2. Redeploy the SAM application:
```bash
sam build && sam deploy
```

### Step 5.2: Update Terraform Application

1. Modify `lambda_function.py` to add version information:

```python
# Add this to the response_data in lambda_handler:
response_data = {
    'message': f'Hello {name} from Terraform!',
    'timestamp': datetime.datetime.now().isoformat(),
    'function_name': function_name,
    'function_version': function_version,
    'method': http_method,
    'path': path,
    'deployment_method': os.environ.get('DEPLOYMENT_METHOD', 'Terraform'),
    'environment': os.environ.get('AWS_REGION', 'unknown'),
    'version': '2.0'  # Add this line
}
```

2. Redeploy with Terraform:
```bash
terraform apply
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created and deployed a serverless application using AWS SAM
- [ ] Created and deployed a serverless application using Terraform
- [ ] Both applications use proper username prefixing
- [ ] Both APIs respond correctly to HTTP requests
- [ ] Successfully tested SAM local development environment
- [ ] Compared deployment approaches and resource creation
- [ ] Updated and redeployed both applications
- [ ] Understood the differences between SAM and Terraform

### Expected Results

You should have:
1. Two working API endpoints (SAM and Terraform deployed)
2. Lambda functions deployed by different IaC tools
3. S3 buckets created by both deployment methods
4. Understanding of declarative infrastructure principles
5. Experience with local development using SAM CLI

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** SAM build fails
- **Solution:** Ensure Python and SAM CLI are properly installed
- Check YAML syntax in template.yaml
- Verify source code directory structure

**Issue:** Terraform apply fails
- **Solution:** Check AWS credentials and permissions
- Verify Terraform syntax with `terraform validate`
- Ensure all required files exist

**Issue:** Local testing doesn't work
- **Solution:** Check port availability
- Ensure Docker is running (for SAM local)
- Verify event file format

**Issue:** Resource naming conflicts
- **Solution:** Ensure username prefix is correctly applied
- Check for existing resources with similar names
- Verify randomization in Terraform configurations

---

## Clean Up

### Clean Up SAM Resources

```bash
cd ~/environment/[your-username]-sam-project
sam delete --stack-name [your-username]-sam-stack
```

### Clean Up Terraform Resources

```bash
cd ~/environment/[your-username]-terraform-project
terraform destroy
```

**Note:** You may choose to keep some resources for future labs.

---

## Key Takeaways

From this lab, you should understand:
1. **Infrastructure as Code Benefits:** Version control, repeatability, and consistency
2. **SAM Framework:** AWS-native serverless application development and deployment
3. **Terraform:** Cloud-agnostic infrastructure provisioning
4. **Local Development:** How to test serverless applications locally
5. **Deployment Comparison:** Trade-offs between different IaC approaches
6. **Resource Management:** How different tools manage AWS resources

---

## Next Steps

In the next lab, you will explore event-driven architectures using Amazon EventBridge to build decoupled serverless systems.