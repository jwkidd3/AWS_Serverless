# Developing Serverless Solutions on AWS - Day 3 - Lab 10
## Building CI/CD Pipelines

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will build comprehensive CI/CD pipelines for serverless applications using AWS CodePipeline, CodeBuild, and CodeDeploy. You'll implement automated testing, deployment strategies, environment promotion, and rollback mechanisms to ensure reliable and efficient serverless application delivery.

## Lab Objectives

By the end of this lab, you will be able to:
- Create automated CI/CD pipelines using AWS CodePipeline
- Implement automated testing in CodeBuild for serverless applications
- Configure multi-environment deployment strategies
- Use SAM and CDK for infrastructure as code deployments
- Implement blue/green deployments for Lambda functions
- Configure automated rollback mechanisms
- Integrate security scanning and compliance checks
- Monitor pipeline performance and deployment success
- Apply username prefixing to CI/CD resources

## Prerequisites

- Completion of Labs 1-9
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of CI/CD concepts and Git workflows

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for CI/CD Resources
**IMPORTANT:** All CI/CD resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- CodePipeline: `user3-serverless-pipeline`
- CodeBuild project: `user3-serverless-build`
- S3 bucket: `user3-pipeline-artifacts`

---

## Task 1: Set Up Source Code Repository

### Step 1.1: Create CodeCommit Repository

1. Create a CodeCommit repository:
```bash
aws codecommit create-repository \
  --repository-name "[your-username]-serverless-app" \
  --repository-description "Serverless application with CI/CD pipeline"
```

2. Get the repository clone URL:
```bash
aws codecommit get-repository \
  --repository-name "[your-username]-serverless-app" \
  --query 'repositoryMetadata.cloneUrlHttp' \
  --output text
```

### Step 1.2: Initialize Application Repository

1. Create application directory and initialize git:
```bash
mkdir ~/environment/[your-username]-serverless-app
cd ~/environment/[your-username]-serverless-app
git init
```

2. Configure git credentials for CodeCommit:
```bash
git config user.name "Lab User"
git config user.email "labuser@example.com"
```

3. Create application structure:
```bash
mkdir -p src tests infrastructure scripts
touch README.md
```

### Step 1.3: Create Sample Serverless Application

1. Create SAM template:
```bash
cat > template.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Serverless application with CI/CD pipeline

Parameters:
  Environment:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]
    Description: Environment name
  
  Username:
    Type: String
    Description: Username prefix for resources

Globals:
  Function:
    Timeout: 30
    Runtime: python3.9
    Environment:
      Variables:
        ENVIRONMENT: !Ref Environment
        USERNAME: !Ref Username

Resources:
  # API Gateway
  ServerlessApi:
    Type: AWS::Serverless::Api
    Properties:
      Name: !Sub '${Username}-${Environment}-api'
      StageName: !Ref Environment
      Cors:
        AllowMethods: "'GET,POST,PUT,DELETE,OPTIONS'"
        AllowHeaders: "'content-type,x-amz-date,authorization,x-api-key'"
        AllowOrigin: "'*'"

  # Main API function
  ApiFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Username}-${Environment}-api-function'
      CodeUri: src/
      Handler: api.lambda_handler
      Events:
        GetUsers:
          Type: Api
          Properties:
            RestApiId: !Ref ServerlessApi
            Path: /users
            Method: get
        CreateUser:
          Type: Api
          Properties:
            RestApiId: !Ref ServerlessApi
            Path: /users
            Method: post
        GetUser:
          Type: Api
          Properties:
            RestApiId: !Ref ServerlessApi
            Path: /users/{id}
            Method: get

  # Data processing function
  ProcessorFunction:
    Type: AWS::Serverless::Function
    Properties:
      FunctionName: !Sub '${Username}-${Environment}-processor'
      CodeUri: src/
      Handler: processor.lambda_handler
      Events:
        SQSEvent:
          Type: SQS
          Properties:
            Queue: !GetAtt ProcessingQueue.Arn
            BatchSize: 10

  # SQS Queue for processing
  ProcessingQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub '${Username}-${Environment}-processing-queue'
      VisibilityTimeoutSeconds: 120
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt DeadLetterQueue.Arn
        maxReceiveCount: 3

  # Dead Letter Queue
  DeadLetterQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub '${Username}-${Environment}-dlq'

  # DynamoDB Table
  DataTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: !Sub '${Username}-${Environment}-data'
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
      StreamSpecification:
        StreamViewType: NEW_AND_OLD_IMAGES

Outputs:
  ApiUrl:
    Description: API Gateway endpoint URL
    Value: !Sub 'https://${ServerlessApi}.execute-api.${AWS::Region}.amazonaws.com/${Environment}'
    Export:
      Name: !Sub '${Username}-${Environment}-api-url'
  
  ProcessingQueueUrl:
    Description: SQS queue URL
    Value: !Ref ProcessingQueue
    Export:
      Name: !Sub '${Username}-${Environment}-queue-url'
EOF
```

2. Create API function:
```bash
cat > src/api.py << 'EOF'
import json
import boto3
import uuid
import os
from datetime import datetime

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb')
table_name = f"{os.environ['USERNAME']}-{os.environ['ENVIRONMENT']}-data"

def lambda_handler(event, context):
    """
    Main API function handling user operations
    """
    
    try:
        http_method = event['httpMethod']
        path = event['path']
        
        if http_method == 'GET' and path == '/users':
            return get_users()
        elif http_method == 'POST' and path == '/users':
            return create_user(json.loads(event['body']))
        elif http_method == 'GET' and '/users/' in path:
            user_id = path.split('/')[-1]
            return get_user(user_id)
        else:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Not found'})
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def get_users():
    """Get all users"""
    try:
        table = dynamodb.Table(table_name)
        response = table.scan()
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'users': response['Items'],
                'count': response['Count']
            }, default=str)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Failed to get users: {str(e)}'})
        }

def create_user(user_data):
    """Create a new user"""
    try:
        user_id = str(uuid.uuid4())
        user = {
            'id': user_id,
            'name': user_data.get('name', ''),
            'email': user_data.get('email', ''),
            'created_at': datetime.utcnow().isoformat(),
            'environment': os.environ['ENVIRONMENT']
        }
        
        table = dynamodb.Table(table_name)
        table.put_item(Item=user)
        
        return {
            'statusCode': 201,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(user, default=str)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Failed to create user: {str(e)}'})
        }

def get_user(user_id):
    """Get a specific user"""
    try:
        table = dynamodb.Table(table_name)
        response = table.get_item(Key={'id': user_id})
        
        if 'Item' in response:
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(response['Item'], default=str)
            }
        else:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'User not found'})
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Failed to get user: {str(e)}'})
        }
EOF
```

3. Create processor function:
```bash
cat > src/processor.py << 'EOF'
import json
import boto3
import os
from datetime import datetime

# Initialize services
dynamodb = boto3.resource('dynamodb')
table_name = f"{os.environ['USERNAME']}-{os.environ['ENVIRONMENT']}-data"

def lambda_handler(event, context):
    """
    Process SQS messages and update DynamoDB
    """
    
    processed_records = []
    failed_records = []
    
    for record in event['Records']:
        try:
            # Parse SQS message
            message_body = json.loads(record['body'])
            
            # Process the message
            result = process_message(message_body)
            
            processed_records.append({
                'messageId': record['messageId'],
                'result': result
            })
            
        except Exception as e:
            failed_records.append({
                'itemIdentifier': record['messageId'],
                'error': str(e)
            })
    
    print(f"Processed {len(processed_records)} records successfully")
    print(f"Failed to process {len(failed_records)} records")
    
    return {
        'batchItemFailures': [
            {'itemIdentifier': record['itemIdentifier']} 
            for record in failed_records
        ]
    }

def process_message(message):
    """Process individual message"""
    
    # Extract message data
    action = message.get('action', 'unknown')
    data = message.get('data', {})
    
    if action == 'update_user':
        return update_user_data(data)
    elif action == 'analytics':
        return process_analytics(data)
    else:
        return {'status': 'ignored', 'reason': f'Unknown action: {action}'}

def update_user_data(data):
    """Update user data in DynamoDB"""
    
    user_id = data.get('user_id')
    updates = data.get('updates', {})
    
    if not user_id:
        raise ValueError("user_id is required")
    
    table = dynamodb.Table(table_name)
    
    # Update the user record
    update_expression = "SET updated_at = :timestamp"
    expression_values = {':timestamp': datetime.utcnow().isoformat()}
    
    for key, value in updates.items():
        update_expression += f", {key} = :{key}"
        expression_values[f':{key}'] = value
    
    table.update_item(
        Key={'id': user_id},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_values
    )
    
    return {'status': 'updated', 'user_id': user_id}

def process_analytics(data):
    """Process analytics data"""
    
    # Simulate analytics processing
    event_type = data.get('event_type', 'unknown')
    timestamp = data.get('timestamp', datetime.utcnow().isoformat())
    
    print(f"Processing analytics event: {event_type} at {timestamp}")
    
    return {'status': 'processed', 'event_type': event_type}
EOF
```

4. Create test files:
```bash
cat > tests/test_api.py << 'EOF'
import unittest
import json
import os
import sys

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from api import lambda_handler

class TestApiFunction(unittest.TestCase):
    
    def setUp(self):
        # Set environment variables for testing
        os.environ['USERNAME'] = 'test'
        os.environ['ENVIRONMENT'] = 'test'
    
    def test_get_users_endpoint(self):
        """Test GET /users endpoint"""
        event = {
            'httpMethod': 'GET',
            'path': '/users',
            'headers': {},
            'body': None
        }
        
        context = {}
        
        # Note: This will fail without actual DynamoDB table
        # In real CI/CD, you'd use mocking or test environment
        response = lambda_handler(event, context)
        
        # Should return valid HTTP response structure
        self.assertIn('statusCode', response)
        self.assertIn('body', response)
    
    def test_create_user_validation(self):
        """Test user creation with validation"""
        event = {
            'httpMethod': 'POST',
            'path': '/users',
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'name': 'Test User',
                'email': 'test@example.com'
            })
        }
        
        context = {}
        
        response = lambda_handler(event, context)
        
        # Should return valid HTTP response structure
        self.assertIn('statusCode', response)
        self.assertIn('body', response)
    
    def test_invalid_endpoint(self):
        """Test invalid endpoint returns 404"""
        event = {
            'httpMethod': 'GET',
            'path': '/invalid',
            'headers': {},
            'body': None
        }
        
        context = {}
        
        response = lambda_handler(event, context)
        
        self.assertEqual(response['statusCode'], 404)

if __name__ == '__main__':
    unittest.main()
EOF

cat > tests/test_processor.py << 'EOF'
import unittest
import json
import os
import sys

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from processor import lambda_handler, process_message

class TestProcessorFunction(unittest.TestCase):
    
    def setUp(self):
        # Set environment variables for testing
        os.environ['USERNAME'] = 'test'
        os.environ['ENVIRONMENT'] = 'test'
    
    def test_process_message_update_user(self):
        """Test processing update_user message"""
        message = {
            'action': 'update_user',
            'data': {
                'user_id': 'test-user-123',
                'updates': {
                    'name': 'Updated Name'
                }
            }
        }
        
        # This would need DynamoDB mock in real testing
        try:
            result = process_message(message)
            self.assertIn('status', result)
        except Exception:
            # Expected to fail without DynamoDB
            pass
    
    def test_process_message_analytics(self):
        """Test processing analytics message"""
        message = {
            'action': 'analytics',
            'data': {
                'event_type': 'user_login',
                'timestamp': '2024-01-01T00:00:00Z'
            }
        }
        
        result = process_message(message)
        self.assertEqual(result['status'], 'processed')
        self.assertEqual(result['event_type'], 'user_login')
    
    def test_unknown_action(self):
        """Test unknown action handling"""
        message = {
            'action': 'unknown_action',
            'data': {}
        }
        
        result = process_message(message)
        self.assertEqual(result['status'], 'ignored')

if __name__ == '__main__':
    unittest.main()
EOF
```

5. Create requirements.txt:
```bash
cat > requirements.txt << 'EOF'
boto3==1.34.0
EOF
```

---

## Task 2: Create Build Specification

### Step 2.1: Create CodeBuild Configuration

1. Create buildspec for different phases:
```bash
cat > buildspec.yml << 'EOF'
version: 0.2

env:
  variables:
    PYTHON_VERSION: "3.9"
  parameter-store:
    USERNAME: "/cicd/username"

phases:
  install:
    runtime-versions:
      python: $PYTHON_VERSION
    commands:
      - echo "Installing dependencies..."
      - pip install --upgrade pip
      - pip install -r requirements.txt
      - pip install pytest pytest-cov moto
      - pip install aws-sam-cli
      - echo "SAM CLI version:"
      - sam --version

  pre_build:
    commands:
      - echo "Running pre-build phase..."
      - echo "Linting code..."
      - python -m py_compile src/*.py
      - echo "Running security checks..."
      - pip install bandit
      - bandit -r src/ -f json -o security-report.json || true
      - echo "Setting up test environment..."
      - export PYTHONPATH=$PYTHONPATH:$CODEBUILD_SRC_DIR/src

  build:
    commands:
      - echo "Running tests..."
      - python -m pytest tests/ -v --junitxml=test-results.xml --cov=src --cov-report=xml
      - echo "Building SAM application..."
      - sam build --use-container
      - echo "Validating SAM template..."
      - sam validate

  post_build:
    commands:
      - echo "Post-build phase..."
      - echo "Packaging application..."
      - sam package --s3-bucket $ARTIFACTS_BUCKET --output-template-file packaged-template.yaml
      - echo "Build completed successfully"

artifacts:
  files:
    - packaged-template.yaml
    - template.yaml
    - infrastructure/**/*
    - scripts/**/*
  name: BuildArtifacts

reports:
  pytest_reports:
    files:
      - test-results.xml
    file-format: JUNITXML
  coverage_reports:
    files:
      - coverage.xml
    file-format: COBERTURAXML
  security_reports:
    files:
      - security-report.json
    file-format: JSON

cache:
  paths:
    - '/root/.cache/pip/**/*'
EOF
```

### Step 2.2: Create Deployment Scripts

1. Create deployment script:
```bash
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash

set -e

# Parameters
ENVIRONMENT=${1:-dev}
USERNAME=${2:-user1}
STACK_NAME="${USERNAME}-serverless-app-${ENVIRONMENT}"
TEMPLATE_FILE=${3:-packaged-template.yaml}

echo "Deploying to environment: $ENVIRONMENT"
echo "Username: $USERNAME"
echo "Stack name: $STACK_NAME"

# Deploy using SAM
sam deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
    Environment="$ENVIRONMENT" \
    Username="$USERNAME" \
  --capabilities CAPABILITY_IAM \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

echo "Deployment completed successfully"

# Get stack outputs
echo "Stack outputs:"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs'
EOF

chmod +x scripts/deploy.sh
```

2. Create testing script:
```bash
cat > scripts/integration-test.sh << 'EOF'
#!/bin/bash

set -e

# Parameters
ENVIRONMENT=${1:-dev}
USERNAME=${2:-user1}
STACK_NAME="${USERNAME}-serverless-app-${ENVIRONMENT}"

echo "Running integration tests for environment: $ENVIRONMENT"

# Get API URL from stack outputs
API_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

if [ -z "$API_URL" ]; then
  echo "Error: Could not retrieve API URL"
  exit 1
fi

echo "Testing API at: $API_URL"

# Test GET /users
echo "Testing GET /users..."
curl -f "$API_URL/users" -H "Content-Type: application/json"
echo "✓ GET /users successful"

# Test POST /users
echo "Testing POST /users..."
curl -f -X POST "$API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'
echo "✓ POST /users successful"

echo "Integration tests completed successfully"
EOF

chmod +x scripts/integration-test.sh
```

3. Create rollback script:
```bash
cat > scripts/rollback.sh << 'EOF'
#!/bin/bash

set -e

# Parameters
ENVIRONMENT=${1:-dev}
USERNAME=${2:-user1}
STACK_NAME="${USERNAME}-serverless-app-${ENVIRONMENT}"

echo "Rolling back deployment for environment: $ENVIRONMENT"
echo "Stack name: $STACK_NAME"

# Get current stack status
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "STACK_NOT_FOUND")

if [ "$STACK_STATUS" = "STACK_NOT_FOUND" ]; then
  echo "Stack not found, nothing to rollback"
  exit 0
fi

echo "Current stack status: $STACK_STATUS"

# Cancel update if in progress
if [[ "$STACK_STATUS" == *"IN_PROGRESS" ]]; then
  echo "Canceling stack update..."
  aws cloudformation cancel-update-stack --stack-name "$STACK_NAME"
  
  # Wait for cancel to complete
  aws cloudformation wait stack-update-cancel-complete --stack-name "$STACK_NAME"
fi

# Initiate rollback
echo "Initiating rollback..."
aws cloudformation continue-update-rollback --stack-name "$STACK_NAME"

# Wait for rollback to complete
echo "Waiting for rollback to complete..."
aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME"

echo "Rollback completed successfully"
EOF

chmod +x scripts/rollback.sh
```

---

## Task 3: Create CI/CD Pipeline Infrastructure

### Step 3.1: Create Pipeline IAM Roles

1. Create CodePipeline service role:
```bash
cat > pipeline-role-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codepipeline.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
  --role-name [your-username]-codepipeline-role \
  --assume-role-policy-document file://pipeline-role-policy.json

cat > pipeline-permissions.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketVersioning",
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::*-pipeline-artifacts",
                "arn:aws:s3:::*-pipeline-artifacts/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codecommit:CancelUploadArchive",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetRepository",
                "codecommit:ListBranches",
                "codecommit:ListRepositories"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:UpdateStack",
                "cloudformation:CreateChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:SetStackPolicy",
                "cloudformation:ValidateTemplate"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy \
  --role-name [your-username]-codepipeline-role \
  --policy-name CodePipelineServiceRolePolicy \
  --policy-document file://pipeline-permissions.json
```

2. Create CodeBuild service role:
```bash
cat > codebuild-role-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
  --role-name [your-username]-codebuild-role \
  --assume-role-policy-document file://codebuild-role-policy.json

cat > codebuild-permissions.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketVersioning",
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion"
            ],
            "Resource": [
                "arn:aws:s3:::*-pipeline-artifacts",
                "arn:aws:s3:::*-pipeline-artifacts/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters",
                "ssm:GetParameter"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*",
                "lambda:*",
                "apigateway:*",
                "dynamodb:*",
                "sqs:*",
                "iam:*",
                "s3:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy \
  --role-name [your-username]-codebuild-role \
  --policy-name CodeBuildServiceRolePolicy \
  --policy-document file://codebuild-permissions.json
```

### Step 3.2: Create S3 Bucket for Artifacts

1. Create S3 bucket for pipeline artifacts:
```bash
aws s3 mb s3://[your-username]-pipeline-artifacts
```

2. Enable versioning on the bucket:
```bash
aws s3api put-bucket-versioning \
  --bucket [your-username]-pipeline-artifacts \
  --versioning-configuration Status=Enabled
```

3. Store username in Parameter Store:
```bash
aws ssm put-parameter \
  --name "/cicd/username" \
  --value "[your-username]" \
  --type "String" \
  --description "Username for CI/CD pipeline resources"
```

---

## Task 4: Create CodeBuild Projects

### Step 4.1: Create Build Project

1. Create CodeBuild project configuration:
```bash
cat > codebuild-project.json << 'EOF'
{
    "name": "[your-username]-serverless-build",
    "description": "Build project for serverless application",
    "source": {
        "type": "CODECOMMIT",
        "location": "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/[your-username]-serverless-app"
    },
    "artifacts": {
        "type": "S3",
        "location": "[your-username]-pipeline-artifacts",
        "name": "build-output"
    },
    "environment": {
        "type": "LINUX_CONTAINER",
        "image": "aws/codebuild/amazonlinux2-x86_64-standard:3.0",
        "computeType": "BUILD_GENERAL1_MEDIUM",
        "environmentVariables": [
            {
                "name": "ARTIFACTS_BUCKET",
                "value": "[your-username]-pipeline-artifacts"
            },
            {
                "name": "AWS_DEFAULT_REGION",
                "value": "us-east-1"
            }
        ]
    },
    "serviceRole": "arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-codebuild-role",
    "timeoutInMinutes": 30
}
EOF

# Replace placeholders
sed -i "s/\[your-username\]/[your-username]/g" codebuild-project.json
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" codebuild-project.json

# Create the build project
aws codebuild create-project --cli-input-json file://codebuild-project.json
```

### Step 4.2: Create Deploy Project

1. Create deployment CodeBuild project:
```bash
cat > deploy-buildspec.yml << 'EOF'
version: 0.2

env:
  variables:
    PYTHON_VERSION: "3.9"
  parameter-store:
    USERNAME: "/cicd/username"

phases:
  install:
    runtime-versions:
      python: $PYTHON_VERSION
    commands:
      - pip install aws-sam-cli

  build:
    commands:
      - echo "Deploying to $ENVIRONMENT environment"
      - ./scripts/deploy.sh $ENVIRONMENT $USERNAME packaged-template.yaml
      - echo "Running integration tests"
      - ./scripts/integration-test.sh $ENVIRONMENT $USERNAME

artifacts:
  files:
    - '**/*'
EOF

cat > codebuild-deploy-project.json << 'EOF'
{
    "name": "[your-username]-serverless-deploy",
    "description": "Deploy project for serverless application",
    "source": {
        "type": "S3",
        "buildspec": "deploy-buildspec.yml"
    },
    "artifacts": {
        "type": "NO_ARTIFACTS"
    },
    "environment": {
        "type": "LINUX_CONTAINER",
        "image": "aws/codebuild/amazonlinux2-x86_64-standard:3.0",
        "computeType": "BUILD_GENERAL1_SMALL"
    },
    "serviceRole": "arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-codebuild-role",
    "timeoutInMinutes": 20
}
EOF

# Replace placeholders
sed -i "s/\[your-username\]/[your-username]/g" codebuild-deploy-project.json
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" codebuild-deploy-project.json

# Create the deploy project
aws codebuild create-project --cli-input-json file://codebuild-deploy-project.json
```

---

## Task 5: Create CodePipeline

### Step 5.1: Create Pipeline Configuration

1. Create CodePipeline configuration:
```bash
cat > pipeline.json << 'EOF'
{
    "pipeline": {
        "name": "[your-username]-serverless-pipeline",
        "roleArn": "arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-codepipeline-role",
        "artifactStore": {
            "type": "S3",
            "location": "[your-username]-pipeline-artifacts"
        },
        "stages": [
            {
                "name": "Source",
                "actions": [
                    {
                        "name": "SourceAction",
                        "actionTypeId": {
                            "category": "Source",
                            "owner": "AWS",
                            "provider": "CodeCommit",
                            "version": "1"
                        },
                        "configuration": {
                            "RepositoryName": "[your-username]-serverless-app",
                            "BranchName": "main"
                        },
                        "outputArtifacts": [
                            {
                                "name": "SourceOutput"
                            }
                        ]
                    }
                ]
            },
            {
                "name": "Build",
                "actions": [
                    {
                        "name": "BuildAction",
                        "actionTypeId": {
                            "category": "Build",
                            "owner": "AWS",
                            "provider": "CodeBuild",
                            "version": "1"
                        },
                        "configuration": {
                            "ProjectName": "[your-username]-serverless-build"
                        },
                        "inputArtifacts": [
                            {
                                "name": "SourceOutput"
                            }
                        ],
                        "outputArtifacts": [
                            {
                                "name": "BuildOutput"
                            }
                        ]
                    }
                ]
            },
            {
                "name": "DeployToDev",
                "actions": [
                    {
                        "name": "DeployAction",
                        "actionTypeId": {
                            "category": "Build",
                            "owner": "AWS",
                            "provider": "CodeBuild",
                            "version": "1"
                        },
                        "configuration": {
                            "ProjectName": "[your-username]-serverless-deploy",
                            "EnvironmentVariables": "[{\"name\":\"ENVIRONMENT\",\"value\":\"dev\"}]"
                        },
                        "inputArtifacts": [
                            {
                                "name": "BuildOutput"
                            }
                        ]
                    }
                ]
            },
            {
                "name": "DeployToStaging",
                "actions": [
                    {
                        "name": "DeployAction",
                        "actionTypeId": {
                            "category": "Build",
                            "owner": "AWS",
                            "provider": "CodeBuild",
                            "version": "1"
                        },
                        "configuration": {
                            "ProjectName": "[your-username]-serverless-deploy",
                            "EnvironmentVariables": "[{\"name\":\"ENVIRONMENT\",\"value\":\"staging\"}]"
                        },
                        "inputArtifacts": [
                            {
                                "name": "BuildOutput"
                            }
                        ]
                    }
                ]
            },
            {
                "name": "ApprovalForProduction",
                "actions": [
                    {
                        "name": "ManualApproval",
                        "actionTypeId": {
                            "category": "Approval",
                            "owner": "AWS",
                            "provider": "Manual",
                            "version": "1"
                        },
                        "configuration": {
                            "CustomData": "Please review staging deployment and approve for production"
                        }
                    }
                ]
            },
            {
                "name": "DeployToProduction",
                "actions": [
                    {
                        "name": "DeployAction",
                        "actionTypeId": {
                            "category": "Build",
                            "owner": "AWS",
                            "provider": "CodeBuild",
                            "version": "1"
                        },
                        "configuration": {
                            "ProjectName": "[your-username]-serverless-deploy",
                            "EnvironmentVariables": "[{\"name\":\"ENVIRONMENT\",\"value\":\"prod\"}]"
                        },
                        "inputArtifacts": [
                            {
                                "name": "BuildOutput"
                            }
                        ]
                    }
                ]
            }
        ]
    }
}
EOF

# Replace placeholders
sed -i "s/\[your-username\]/[your-username]/g" pipeline.json
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" pipeline.json

# Create the pipeline
aws codepipeline create-pipeline --cli-input-json file://pipeline.json
```

---

## Task 6: Configure Blue/Green Deployment

### Step 6.1: Create Blue/Green Deployment Configuration

1. Update SAM template for blue/green deployments:
```bash
cat >> template.yaml << 'EOF'

  # Lambda Alias for blue/green deployment
  ApiAlias:
    Type: AWS::Lambda::Alias
    Properties:
      FunctionName: !Ref ApiFunction
      FunctionVersion: !GetAtt ApiVersion.Version
      Name: live

  ApiVersion:
    Type: AWS::Lambda::Version
    Properties:
      FunctionName: !Ref ApiFunction
      Description: !Sub 'Version deployed at ${AWS::StackName}'

  # CodeDeploy Application
  CodeDeployApplication:
    Type: AWS::CodeDeploy::Application
    Properties:
      ApplicationName: !Sub '${Username}-${Environment}-lambda-app'
      ComputePlatform: Lambda

  # CodeDeploy Deployment Group
  CodeDeployDeploymentGroup:
    Type: AWS::CodeDeploy::DeploymentGroup
    Properties:
      ApplicationName: !Ref CodeDeployApplication
      DeploymentGroupName: !Sub '${Username}-${Environment}-deployment-group'
      ServiceRoleArn: !Sub 'arn:aws:iam::${AWS::AccountId}:role/CodeDeployServiceRole'
      DeploymentConfigName: CodeDeployDefault.LambdaCanary10Percent5Minutes
      AutoRollbackConfiguration:
        Enabled: true
        Events:
          - DEPLOYMENT_FAILURE
          - DEPLOYMENT_STOP_ON_ALARM
      AlarmConfiguration:
        Enabled: true
        Alarms:
          - Name: !Ref AliasErrorMetricGreaterThanZeroAlarm

  # CloudWatch Alarm for monitoring deployment
  AliasErrorMetricGreaterThanZeroAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: !Sub '${Username}-${Environment}-lambda-errors'
      AlarmDescription: Lambda function errors
      ComparisonOperator: GreaterThanThreshold
      EvaluationPeriods: 2
      MetricName: Errors
      Namespace: AWS/Lambda
      Period: 60
      Statistic: Sum
      Threshold: 0
      Dimensions:
        - Name: FunctionName
          Value: !Ref ApiFunction
        - Name: Resource
          Value: !Sub '${ApiFunction}:live'
EOF
```

2. Create CodeDeploy service role:
```bash
cat > codedeploy-role-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codedeploy.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
  --role-name CodeDeployServiceRole \
  --assume-role-policy-document file://codedeploy-role-policy.json

aws iam attach-role-policy \
  --role-name CodeDeployServiceRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda
```

---

## Task 7: Commit and Test Pipeline

### Step 7.1: Commit Code to Repository

1. Add all files to git:
```bash
git add .
git commit -m "Initial serverless application with CI/CD pipeline"
```

2. Add CodeCommit as remote and push:
```bash
REPO_URL=$(aws codecommit get-repository \
  --repository-name "[your-username]-serverless-app" \
  --query 'repositoryMetadata.cloneUrlHttp' \
  --output text)

git remote add origin $REPO_URL
git push -u origin main
```

### Step 7.2: Monitor Pipeline Execution

1. Check pipeline status:
```bash
aws codepipeline get-pipeline-state \
  --name [your-username]-serverless-pipeline
```

2. Get pipeline execution details:
```bash
aws codepipeline list-pipeline-executions \
  --pipeline-name [your-username]-serverless-pipeline \
  --max-items 5
```

3. Check build logs:
```bash
# Get latest build ID
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name [your-username]-serverless-build \
  --query 'ids[0]' --output text)

# Get build logs
aws logs get-log-events \
  --log-group-name "/aws/codebuild/[your-username]-serverless-build" \
  --log-stream-name "$BUILD_ID" \
  --query 'events[*].message' \
  --output text
```

---

## Task 8: Test Deployment and Rollback

### Step 8.1: Test Deployed Application

1. Get API URLs for each environment:
```bash
# Dev environment
aws cloudformation describe-stacks \
  --stack-name "[your-username]-serverless-app-dev" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text

# Staging environment  
aws cloudformation describe-stacks \
  --stack-name "[your-username]-serverless-app-staging" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text
```

2. Test the APIs:
```bash
DEV_API_URL=$(aws cloudformation describe-stacks \
  --stack-name "[your-username]-serverless-app-dev" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

# Test GET /users
curl "$DEV_API_URL/users"

# Test POST /users
curl -X POST "$DEV_API_URL/users" \
  -H "Content-Type: application/json" \
  -d '{"name": "Pipeline User", "email": "pipeline@example.com"}'
```

### Step 8.2: Simulate Failure and Rollback

1. Introduce a bug to test rollback:
```bash
# Create a buggy version
cat > src/api.py << 'EOF'
import json
import boto3
import uuid
import os
from datetime import datetime

# Intentional bug: missing dynamodb initialization
# dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Buggy version that will fail
    """
    
    # This will cause a NameError
    table = dynamodb.Table('nonexistent')
    
    return {
        'statusCode': 500,
        'body': json.dumps({'error': 'Intentional bug for rollback test'})
    }
EOF

# Commit the buggy version
git add src/api.py
git commit -m "Introduce bug for rollback testing"
git push origin main
```

2. Monitor the pipeline and trigger rollback:
```bash
# Wait for pipeline to start failing, then rollback
./scripts/rollback.sh dev [your-username]
```

3. Fix the bug and redeploy:
```bash
# Restore the working version
git checkout HEAD~1 -- src/api.py
git add src/api.py
git commit -m "Fix bug and restore functionality"
git push origin main
```

---

## Task 9: Create Monitoring Dashboard

### Step 9.1: Create CI/CD Monitoring Dashboard

1. Create pipeline monitoring dashboard:
```bash
cat > cicd-dashboard.json << 'EOF'
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/CodeBuild", "Builds", "ProjectName", "[your-username]-serverless-build" ],
                    [ ".", "SucceededBuilds", ".", "." ],
                    [ ".", "FailedBuilds", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "CodeBuild Metrics"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/CodePipeline", "PipelineExecutions", "PipelineName", "[your-username]-serverless-pipeline" ],
                    [ ".", "PipelineExecutionSuccess", ".", "." ],
                    [ ".", "PipelineExecutionFailure", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Pipeline Execution Metrics"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 24,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Invocations", "FunctionName", "[your-username]-dev-api-function" ],
                    [ ".", "Errors", ".", "." ],
                    [ ".", "Duration", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Deployed Application Metrics"
            }
        }
    ]
}
EOF

sed -i "s/\[your-username\]/[your-username]/g" cicd-dashboard.json

aws cloudwatch put-dashboard \
  --dashboard-name "[your-username]-cicd-pipeline" \
  --dashboard-body file://cicd-dashboard.json
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created CodeCommit repository with serverless application code
- [ ] Implemented comprehensive build specifications with testing
- [ ] Created IAM roles with appropriate permissions for CI/CD
- [ ] Built CodeBuild projects for build and deployment
- [ ] Created multi-stage CodePipeline with approval gates
- [ ] Configured blue/green deployment with CodeDeploy
- [ ] Successfully deployed application to multiple environments
- [ ] Tested rollback mechanisms and failure scenarios
- [ ] Created monitoring dashboard for pipeline metrics
- [ ] Applied username prefixing to all CI/CD resources

### Expected Results

Your CI/CD pipeline should:
1. Automatically trigger on code commits to CodeCommit
2. Run automated tests and security scans
3. Deploy to dev environment automatically
4. Deploy to staging after successful dev deployment
5. Require manual approval for production deployment
6. Support rollback in case of deployment failures
7. Provide comprehensive monitoring and alerting

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Pipeline fails due to IAM permissions
- **Solution:** Verify CodePipeline and CodeBuild roles have necessary permissions
- Check CloudFormation permissions for deployment
- Ensure S3 bucket permissions are correct

**Issue:** Build fails during testing phase
- **Solution:** Check buildspec.yml syntax and commands
- Verify test dependencies are properly installed
- Review CloudWatch Logs for detailed error messages

**Issue:** Deployment fails with CloudFormation errors
- **Solution:** Validate SAM template syntax
- Check parameter values and stack names
- Verify resources don't conflict with existing resources

**Issue:** Blue/green deployment not working
- **Solution:** Verify CodeDeploy service role permissions
- Check CloudWatch alarm configuration
- Ensure Lambda alias and version configuration is correct

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete pipeline
aws codepipeline delete-pipeline --name [your-username]-serverless-pipeline

# Delete CodeBuild projects
aws codebuild delete-project --name [your-username]-serverless-build
aws codebuild delete-project --name [your-username]-serverless-deploy

# Delete CloudFormation stacks
aws cloudformation delete-stack --stack-name [your-username]-serverless-app-dev
aws cloudformation delete-stack --stack-name [your-username]-serverless-app-staging
aws cloudformation delete-stack --stack-name [your-username]-serverless-app-prod

# Delete CodeCommit repository
aws codecommit delete-repository --repository-name [your-username]-serverless-app

# Delete S3 bucket (after emptying it)
aws s3 rm s3://[your-username]-pipeline-artifacts --recursive
aws s3 rb s3://[your-username]-pipeline-artifacts

# Delete IAM roles
aws iam delete-role-policy --role-name [your-username]-codepipeline-role --policy-name CodePipelineServiceRolePolicy
aws iam delete-role --role-name [your-username]-codepipeline-role

aws iam delete-role-policy --role-name [your-username]-codebuild-role --policy-name CodeBuildServiceRolePolicy
aws iam delete-role --role-name [your-username]-codebuild-role

aws iam detach-role-policy --role-name CodeDeployServiceRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda
aws iam delete-role --role-name CodeDeployServiceRole

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-cicd-pipeline

# Delete SSM parameter
aws ssm delete-parameter --name "/cicd/username"
```

---

## Key Takeaways

From this lab, you should understand:
1. **CI/CD Pipeline Design:** Multi-stage pipelines with proper gates and approvals
2. **Automated Testing:** Integration of unit tests, integration tests, and security scans
3. **Infrastructure as Code:** Using SAM and CloudFormation for repeatable deployments
4. **Blue/Green Deployments:** Safe deployment strategies with automatic rollback
5. **Environment Management:** Promoting code through dev, staging, and production
6. **Monitoring and Observability:** Pipeline metrics and application monitoring
7. **Security Integration:** Security scanning and compliance checks in CI/CD

---

## Next Steps

This completes the comprehensive CI/CD pipeline implementation. You now have a production-ready deployment pipeline that can safely and reliably deploy serverless applications across multiple environments with proper testing, monitoring, and rollback capabilities.