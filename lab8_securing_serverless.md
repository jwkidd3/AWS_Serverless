# Developing Serverless Solutions on AWS - Day 2 - Lab 8
## Securing Serverless Applications

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will implement comprehensive security controls for serverless applications using AWS security services and best practices. You'll secure APIs with authentication and authorization, implement Lambda function security, protect data at rest and in transit, and establish auditing and compliance measures.

## Lab Objectives

By the end of this lab, you will be able to:
- Implement API Gateway authentication and authorization using Amazon Cognito
- Configure Lambda function security with IAM roles and resource-based policies
- Secure data using encryption at rest and in transit
- Implement security monitoring and auditing with CloudTrail and GuardDuty
- Apply least privilege access principles to serverless applications
- Configure VPC integration for Lambda functions
- Implement input validation and sanitization
- Apply username prefixing to security resources

## Prerequisites

- Completion of Labs 1-7
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of AWS security concepts

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Security Resources
**IMPORTANT:** All security resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- Cognito User Pool: `user3-secure-app-pool`
- IAM roles: `user3-secure-lambda-role`
- KMS keys: `user3-encryption-key`

---

## Task 1: Implement API Authentication with Amazon Cognito

### Step 1.1: Create Cognito User Pool

1. Create a Cognito User Pool:
```bash
aws cognito-idp create-user-pool \
  --pool-name "[your-username]-secure-app-pool" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": true
    }
  }' \
  --mfa-configuration "OPTIONAL" \
  --account-recovery-setting '{
    "RecoveryMechanisms": [
      {
        "Priority": 1,
        "Name": "verified_email"
      }
    ]
  }' \
  --user-pool-tags "Project=ServerlessLab,Owner=[your-username]"
```

2. Note the User Pool ID from the response and create a User Pool Client:
```bash
aws cognito-idp create-user-pool-client \
  --user-pool-id [USER-POOL-ID] \
  --client-name "[your-username]-secure-app-client" \
  --generate-secret \
  --explicit-auth-flows "ADMIN_NO_SRP_AUTH" "ALLOW_USER_PASSWORD_AUTH" "ALLOW_REFRESH_TOKEN_AUTH" \
  --supported-identity-providers "COGNITO" \
  --callback-urls "https://localhost:3000/callback" \
  --logout-urls "https://localhost:3000/logout" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "email" "openid" "profile" \
  --allowed-o-auth-flows-user-pool-client
```

3. Create a test user:
```bash
aws cognito-idp admin-create-user \
  --user-pool-id [USER-POOL-ID] \
  --username "testuser" \
  --user-attributes Name=email,Value="test@example.com" Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action "SUPPRESS"
```

### Step 1.2: Create Secure Lambda Function

1. Create directory for secure function:
```bash
mkdir ~/environment/[your-username]-secure-function
cd ~/environment/[your-username]-secure-function
```

2. Create `secure_function.py`:

```python
import json
import boto3
import logging
import re
import html
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
dynamodb = boto3.resource('dynamodb')
kms = boto3.client('kms')

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
    
    # Sanitize HTML
    sanitized_message = html.escape(message)
    
    # Validate email if provided
    email = data.get('email', '')
    if email and not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
        errors.append("Invalid email format")
    
    return {
        'valid': len(errors) == 0,
        'errors': errors,
        'sanitized_data': {
            'message': sanitized_message,
            'email': email
        }
    }

def encrypt_sensitive_data(data, key_id):
    """Encrypt sensitive data using KMS"""
    try:
        response = kms.encrypt(
            KeyId=key_id,
            Plaintext=json.dumps(data)
        )
        return response['CiphertextBlob']
    except Exception as e:
        logger.error(f"Encryption failed: {str(e)}")
        raise

def decrypt_sensitive_data(encrypted_data):
    """Decrypt sensitive data using KMS"""
    try:
        response = kms.decrypt(CiphertextBlob=encrypted_data)
        return json.loads(response['Plaintext'].decode('utf-8'))
    except Exception as e:
        logger.error(f"Decryption failed: {str(e)}")
        raise

def log_security_event(event_type, details, user_id=None):
    """Log security-related events for monitoring"""
    security_log = {
        'timestamp': datetime.utcnow().isoformat(),
        'event_type': event_type,
        'details': details,
        'user_id': user_id,
        'function_name': 'secure-function'
    }
    logger.info(f"SECURITY_EVENT: {json.dumps(security_log)}")

def lambda_handler(event, context):
    """
    Secure Lambda function with authentication and authorization
    """
    
    try:
        # Extract user information from Cognito authorizer
        authorizer = event.get('requestContext', {}).get('authorizer', {})
        user_id = authorizer.get('claims', {}).get('sub', 'unknown')
        user_email = authorizer.get('claims', {}).get('email', 'unknown')
        user_groups = authorizer.get('claims', {}).get('cognito:groups', '').split(',')
        
        # Log authenticated access
        log_security_event('AUTHENTICATED_ACCESS', {
            'user_id': user_id,
            'user_email': user_email,
            'user_groups': user_groups,
            'source_ip': event.get('requestContext', {}).get('identity', {}).get('sourceIp')
        }, user_id)
        
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'read')
        
        # Validate input
        validation_result = validate_input(body)
        if not validation_result['valid']:
            log_security_event('INPUT_VALIDATION_FAILED', {
                'errors': validation_result['errors'],
                'user_id': user_id
            }, user_id)
            
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'X-Content-Type-Options': 'nosniff',
                    'X-Frame-Options': 'DENY',
                    'X-XSS-Protection': '1; mode=block'
                },
                'body': json.dumps({
                    'error': 'Invalid input',
                    'details': validation_result['errors']
                })
            }
        
        # Check authorization for operation
        if operation == 'admin' and 'admin' not in user_groups:
            log_security_event('UNAUTHORIZED_ACCESS_ATTEMPT', {
                'operation': operation,
                'user_groups': user_groups,
                'user_id': user_id
            }, user_id)
            
            return {
                'statusCode': 403,
                'headers': {
                    'Content-Type': 'application/json',
                    'X-Content-Type-Options': 'nosniff',
                    'X-Frame-Options': 'DENY',
                    'X-XSS-Protection': '1; mode=block'
                },
                'body': json.dumps({'error': 'Insufficient permissions'})
            }
        
        # Process the request based on operation
        if operation == 'create':
            result = create_secure_record(validation_result['sanitized_data'], user_id)
        elif operation == 'read':
            result = read_secure_data(user_id)
        elif operation == 'admin':
            result = admin_operation(user_id)
        else:
            result = {'message': 'Operation completed', 'user_id': user_id}
        
        # Log successful operation
        log_security_event('OPERATION_SUCCESS', {
            'operation': operation,
            'user_id': user_id
        }, user_id)
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'X-Content-Type-Options': 'nosniff',
                'X-Frame-Options': 'DENY',
                'X-XSS-Protection': '1; mode=block',
                'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload'
            },
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Function error: {str(e)}")
        
        log_security_event('FUNCTION_ERROR', {
            'error': str(e),
            'user_id': user_id if 'user_id' in locals() else 'unknown'
        })
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'X-Content-Type-Options': 'nosniff',
                'X-Frame-Options': 'DENY',
                'X-XSS-Protection': '1; mode=block'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }

def create_secure_record(data, user_id):
    """Create a secure record with encryption"""
    
    # Simulate creating encrypted record
    record = {
        'user_id': user_id,
        'message': data['message'],
        'email': data.get('email', ''),
        'created_at': datetime.utcnow().isoformat(),
        'encrypted': True
    }
    
    return {
        'message': 'Secure record created',
        'record_id': f'rec_{user_id}_{int(datetime.utcnow().timestamp())}',
        'encrypted': True
    }

def read_secure_data(user_id):
    """Read user's secure data"""
    
    return {
        'message': 'Secure data retrieved',
        'user_id': user_id,
        'data': f'Secure data for user {user_id}',
        'timestamp': datetime.utcnow().isoformat()
    }

def admin_operation(user_id):
    """Admin-only operation"""
    
    return {
        'message': 'Admin operation completed',
        'admin_user': user_id,
        'timestamp': datetime.utcnow().isoformat(),
        'admin_data': 'This is sensitive admin information'
    }
```

### Step 1.3: Create IAM Role with Least Privilege

1. Create IAM role for secure function:
```bash
cat > secure-function-policy.json << 'EOF'
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
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "arn:aws:kms:us-east-1:[ACCOUNT-ID]:key/*",
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "dynamodb.us-east-1.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:[ACCOUNT-ID]:table/[your-username]-secure-*"
        }
    ]
}
EOF

aws iam create-role \
  --role-name [your-username]-secure-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

aws iam put-role-policy \
  --role-name [your-username]-secure-lambda-role \
  --policy-name SecureFunctionPolicy \
  --policy-document file://secure-function-policy.json
```

2. Deploy secure function:
```bash
zip secure-function.zip secure_function.py

aws lambda create-function \
  --function-name [your-username]-secure-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-secure-lambda-role \
  --handler secure_function.lambda_handler \
  --zip-file fileb://secure-function.zip \
  --timeout 30 \
  --memory-size 256 \
  --description "Secure function with authentication and authorization"
```

---

## Task 2: Create Secure API Gateway with Cognito Authorization

### Step 2.1: Create API Gateway with Cognito Authorizer

1. Create REST API:
```bash
aws apigateway create-rest-api \
  --name "[your-username]-secure-api" \
  --description "Secure API with Cognito authentication"
```

2. Create Cognito authorizer:
```bash
aws apigateway create-authorizer \
  --rest-api-id [your-api-id] \
  --name "[your-username]-cognito-authorizer" \
  --type COGNITO_USER_POOLS \
  --provider-arns arn:aws:cognito-idp:us-east-1:[ACCOUNT-ID]:userpool/[USER-POOL-ID] \
  --identity-source method.request.header.Authorization
```

3. Create API resources and methods:
```bash
# Get root resource ID
aws apigateway get-resources --rest-api-id [your-api-id]

# Create /secure resource
aws apigateway create-resource \
  --rest-api-id [your-api-id] \
  --parent-id [root-resource-id] \
  --path-part secure

# Create POST method with Cognito authorization
aws apigateway put-method \
  --rest-api-id [your-api-id] \
  --resource-id [secure-resource-id] \
  --http-method POST \
  --authorization-type COGNITO_USER_POOLS \
  --authorizer-id [authorizer-id]
```

4. Configure Lambda integration:
```bash
aws apigateway put-integration \
  --rest-api-id [your-api-id] \
  --resource-id [secure-resource-id] \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-secure-function/invocations

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
  --function-name [your-username]-secure-function \
  --statement-id secure-api-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:[ACCOUNT-ID]:[your-api-id]/*/*"
```

5. Deploy the API:
```bash
aws apigateway create-deployment \
  --rest-api-id [your-api-id] \
  --stage-name prod
```

---

## Task 3: Implement Data Encryption

### Step 3.1: Create KMS Key for Encryption

1. Create KMS key:
```bash
aws kms create-key \
  --description "[your-username] serverless encryption key" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT
```

2. Create key alias:
```bash
aws kms create-alias \
  --alias-name alias/[your-username]-serverless-key \
  --target-key-id [key-id-from-above]
```

3. Update the key policy for least privilege access:
```bash
cat > kms-key-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::[ACCOUNT-ID]:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow Lambda Function Access",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-secure-lambda-role"
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws kms put-key-policy \
  --key-id [key-id] \
  --policy-name default \
  --policy file://kms-key-policy.json
```

### Step 3.2: Create Encrypted DynamoDB Table

1. Create DynamoDB table with encryption:
```bash
aws dynamodb create-table \
  --table-name [your-username]-secure-data \
  --attribute-definitions \
    AttributeName=userId,AttributeType=S \
    AttributeName=recordId,AttributeType=S \
  --key-schema \
    AttributeName=userId,KeyType=HASH \
    AttributeName=recordId,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=alias/[your-username]-serverless-key \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --tags Key=Project,Value=ServerlessLab Key=Owner,Value=[your-username]
```

---

## Task 4: Implement Security Monitoring

### Step 4.1: Create Security Monitoring Function

1. Create directory for security monitoring:
```bash
mkdir ~/environment/[your-username]-security-monitor
cd ~/environment/[your-username]-security-monitor
```

2. Create `security_monitor.py`:

```python
import json
import boto3
import re
from datetime import datetime

# Initialize clients
sns = boto3.client('sns')
logs = boto3.client('logs')

def lambda_handler(event, context):
    """
    Monitor security events and send alerts
    """
    
    # Parse CloudWatch Logs event
    logs_data = event.get('awslogs', {}).get('data', '')
    if logs_data:
        import gzip
        import base64
        
        compressed_payload = base64.b64decode(logs_data)
        uncompressed_payload = gzip.decompress(compressed_payload)
        log_data = json.loads(uncompressed_payload)
        
        # Process log events
        for log_event in log_data.get('logEvents', []):
            message = log_event.get('message', '')
            
            # Check for security events
            if 'SECURITY_EVENT' in message:
                process_security_event(message, log_event)
            
            # Check for suspicious patterns
            if check_suspicious_activity(message):
                send_security_alert('Suspicious Activity Detected', message)
    
    return {'statusCode': 200}

def process_security_event(message, log_event):
    """Process identified security events"""
    
    try:
        # Extract security event data
        security_data = json.loads(message.split('SECURITY_EVENT: ')[1])
        event_type = security_data.get('event_type')
        
        # Handle different security event types
        if event_type == 'UNAUTHORIZED_ACCESS_ATTEMPT':
            handle_unauthorized_access(security_data, log_event)
        elif event_type == 'INPUT_VALIDATION_FAILED':
            handle_validation_failure(security_data, log_event)
        elif event_type == 'FUNCTION_ERROR':
            handle_function_error(security_data, log_event)
            
    except Exception as e:
        print(f"Error processing security event: {str(e)}")

def handle_unauthorized_access(security_data, log_event):
    """Handle unauthorized access attempts"""
    
    user_id = security_data.get('user_id', 'unknown')
    operation = security_data.get('details', {}).get('operation', 'unknown')
    
    alert_message = f"""
    SECURITY ALERT: Unauthorized Access Attempt
    
    User ID: {user_id}
    Operation: {operation}
    Timestamp: {datetime.fromtimestamp(log_event['timestamp']/1000)}
    
    Action Required: Review user permissions and consider account suspension.
    """
    
    send_security_alert('Unauthorized Access Attempt', alert_message)

def handle_validation_failure(security_data, log_event):
    """Handle input validation failures"""
    
    user_id = security_data.get('user_id', 'unknown')
    errors = security_data.get('details', {}).get('errors', [])
    
    # Check for potential attack patterns
    if any('Invalid characters detected' in error for error in errors):
        alert_message = f"""
        SECURITY ALERT: Potential XSS Attack
        
        User ID: {user_id}
        Validation Errors: {', '.join(errors)}
        Timestamp: {datetime.fromtimestamp(log_event['timestamp']/1000)}
        
        Potential malicious input detected.
        """
        send_security_alert('Potential XSS Attack', alert_message)

def handle_function_error(security_data, log_event):
    """Handle function errors that might indicate attacks"""
    
    error = security_data.get('details', {}).get('error', '')
    
    # Check for suspicious error patterns
    if any(pattern in error.lower() for pattern in ['injection', 'overflow', 'malformed']):
        alert_message = f"""
        SECURITY ALERT: Suspicious Function Error
        
        Error: {error}
        Timestamp: {datetime.fromtimestamp(log_event['timestamp']/1000)}
        
        Error pattern suggests potential attack attempt.
        """
        send_security_alert('Suspicious Function Error', alert_message)

def check_suspicious_activity(message):
    """Check for suspicious activity patterns"""
    
    suspicious_patterns = [
        r'DROP TABLE',
        r'SELECT.*FROM.*WHERE',
        r'<script.*>',
        r'javascript:',
        r'eval\(',
        r'UNION.*SELECT'
    ]
    
    for pattern in suspicious_patterns:
        if re.search(pattern, message, re.IGNORECASE):
            return True
    
    return False

def send_security_alert(subject, message):
    """Send security alert via SNS"""
    
    try:
        # In a real scenario, you would send to an SNS topic
        print(f"SECURITY ALERT: {subject}")
        print(f"Message: {message}")
        
        # Uncomment to actually send SNS alert
        # sns.publish(
        #     TopicArn='arn:aws:sns:us-east-1:[ACCOUNT-ID]:[your-username]-security-alerts',
        #     Subject=subject,
        #     Message=message
        # )
        
    except Exception as e:
        print(f"Failed to send security alert: {str(e)}")
```

3. Deploy security monitoring function:
```bash
zip security-monitor.zip security_monitor.py

aws lambda create-function \
  --function-name [your-username]-security-monitor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler security_monitor.lambda_handler \
  --zip-file fileb://security-monitor.zip \
  --timeout 60 \
  --memory-size 256 \
  --description "Security monitoring and alerting function"
```

### Step 4.2: Configure CloudWatch Log Subscription

1. Create log subscription filter:
```bash
aws logs put-subscription-filter \
  --log-group-name "/aws/lambda/[your-username]-secure-function" \
  --filter-name "[your-username]-security-filter" \
  --filter-pattern "SECURITY_EVENT" \
  --destination-arn arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-security-monitor
```

2. Grant CloudWatch Logs permission to invoke security monitor:
```bash
aws lambda add-permission \
  --function-name [your-username]-security-monitor \
  --statement-id security-logs-invoke \
  --action lambda:InvokeFunction \
  --principal logs.amazonaws.com \
  --source-arn "arn:aws:logs:us-east-1:[ACCOUNT-ID]:log-group:/aws/lambda/[your-username]-secure-function:*"
```

---

## Task 5: Implement VPC Security

### Step 5.1: Create VPC Lambda Function

1. Create directory for VPC function:
```bash
mkdir ~/environment/[your-username]-vpc-function
cd ~/environment/[your-username]-vpc-function
```

2. Create `vpc_function.py`:

```python
import json
import boto3
import requests
from datetime import datetime

def lambda_handler(event, context):
    """
    VPC-enabled Lambda function demonstrating network security
    """
    
    try:
        # This function runs in a VPC and can access private resources
        
        # Extract request data
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'network_test')
        
        if operation == 'network_test':
            result = test_network_connectivity()
        elif operation == 'private_resource':
            result = access_private_resource()
        else:
            result = {'message': 'VPC function executed successfully'}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'result': result,
                'vpc_enabled': True,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def test_network_connectivity():
    """Test network connectivity from VPC"""
    
    # This would test connectivity to private resources
    # For demo, we'll simulate network tests
    
    return {
        'network_status': 'connected',
        'vpc_id': 'vpc-simulated',
        'private_subnet': True,
        'nat_gateway': True
    }

def access_private_resource():
    """Access resources only available within VPC"""
    
    # This would access private databases, internal APIs, etc.
    # For demo, we'll simulate private resource access
    
    return {
        'private_database': 'connected',
        'internal_api': 'accessible',
        'security_groups': 'configured'
    }
```

3. Create VPC configuration (simulated for lab):
```bash
# Note: In a real scenario, you would configure actual VPC settings
# For this lab, we'll deploy without VPC but document the configuration

zip vpc-function.zip vpc_function.py

aws lambda create-function \
  --function-name [your-username]-vpc-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler vpc_function.lambda_handler \
  --zip-file fileb://vpc-function.zip \
  --timeout 30 \
  --memory-size 256 \
  --description "VPC-enabled function for network security demonstration"
```

---

## Task 6: Test Security Implementation

### Step 6.1: Test Authentication and Authorization

1. Test unauthenticated access (should fail):
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/secure" \
  -H "Content-Type: application/json" \
  -d '{"operation": "read", "message": "test"}' \
  -v
```

2. Get authentication token (simulated - in real scenario, use Cognito SDK):
```bash
# In a real implementation, you would authenticate with Cognito
# For demo purposes, we'll test with a simulated token
echo "In production, obtain JWT token from Cognito User Pool authentication"
```

3. Test with authentication token:
```bash
# Example with JWT token (replace with actual token)
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/secure" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [JWT-TOKEN]" \
  -d '{"operation": "read", "message": "Authenticated test"}'
```

### Step 6.2: Test Input Validation

1. Test XSS protection:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/secure" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [JWT-TOKEN]" \
  -d '{"operation": "create", "message": "<script>alert(\"xss\")</script>"}'
```

2. Test input length validation:
```bash
# Create a message over 1000 characters
LONG_MESSAGE=$(python3 -c "print('A' * 1001)")
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/secure" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [JWT-TOKEN]" \
  -d "{\"operation\": \"create\", \"message\": \"$LONG_MESSAGE\"}"
```

### Step 6.3: Test Security Monitoring

1. Trigger security events and check monitoring:
```bash
# Check CloudWatch logs for security events
aws logs filter-log-events \
  --log-group-name "/aws/lambda/[your-username]-secure-function" \
  --filter-pattern "SECURITY_EVENT" \
  --start-time $(date -d '1 hour ago' +%s)000
```

2. Check security monitor function logs:
```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/[your-username]-security-monitor" \
  --start-time $(date -d '1 hour ago' +%s)000
```

---

## Task 7: Create Security Dashboard

### Step 7.1: Create Security Monitoring Dashboard

1. Create security dashboard:
```bash
cat > security-dashboard.json << 'EOF'
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
                    [ "AWS/Lambda", "Invocations", "FunctionName", "[your-username]-secure-function" ],
                    [ ".", "Errors", ".", "." ],
                    [ ".", "Throttles", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Secure Function Metrics"
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
                    [ "AWS/ApiGateway", "4XXError", "ApiName", "[your-username]-secure-api" ],
                    [ ".", "5XXError", ".", "." ],
                    [ ".", "Count", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "API Gateway Security Metrics"
            }
        },
        {
            "type": "log",
            "x": 0,
            "y": 6,
            "width": 24,
            "height": 6,
            "properties": {
                "query": "SOURCE '/aws/lambda/[your-username]-secure-function'\n| fields @timestamp, @message\n| filter @message like /SECURITY_EVENT/\n| sort @timestamp desc\n| limit 100",
                "region": "us-east-1",
                "title": "Security Events",
                "view": "table"
            }
        }
    ]
}
EOF

sed -i "s/\[your-username\]/[your-username]/g" security-dashboard.json

aws cloudwatch put-dashboard \
  --dashboard-name "[your-username]-security-monitoring" \
  --dashboard-body file://security-dashboard.json
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created Cognito User Pool with security policies
- [ ] Implemented secure Lambda function with input validation
- [ ] Created IAM role with least privilege permissions
- [ ] Configured API Gateway with Cognito authorization
- [ ] Implemented data encryption with KMS
- [ ] Created encrypted DynamoDB table
- [ ] Implemented security monitoring and alerting
- [ ] Configured CloudWatch log filtering for security events
- [ ] Created security monitoring dashboard
- [ ] Applied username prefixing to all security resources

### Expected Results

Your secure serverless application should:
1. Require authentication for API access
2. Validate and sanitize all input data
3. Implement proper authorization controls
4. Encrypt sensitive data at rest and in transit
5. Monitor and alert on security events
6. Follow least privilege access principles
7. Include comprehensive security logging

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Cognito authentication failing
- **Solution:** Verify User Pool configuration and client settings
- Check JWT token format and expiration
- Ensure API Gateway authorizer is correctly configured

**Issue:** KMS encryption errors
- **Solution:** Verify IAM permissions for KMS access
- Check key policy allows Lambda function access
- Ensure key is in the correct region

**Issue:** Security monitoring not triggering
- **Solution:** Verify log subscription filter pattern
- Check CloudWatch Logs permissions
- Ensure security events are being logged correctly

**Issue:** VPC configuration errors
- **Solution:** Verify VPC, subnet, and security group settings
- Check NAT Gateway configuration for internet access
- Ensure Lambda execution role has VPC permissions

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-secure-function
aws lambda delete-function --function-name [your-username]-security-monitor
aws lambda delete-function --function-name [your-username]-vpc-function

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id [your-api-id]

# Delete Cognito User Pool
aws cognito-idp delete-user-pool --user-pool-id [USER-POOL-ID]

# Delete DynamoDB table
aws dynamodb delete-table --table-name [your-username]-secure-data

# Delete KMS key alias (key will be scheduled for deletion)
aws kms delete-alias --alias-name alias/[your-username]-serverless-key

# Delete IAM role
aws iam delete-role-policy --role-name [your-username]-secure-lambda-role --policy-name SecureFunctionPolicy
aws iam delete-role --role-name [your-username]-secure-lambda-role

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-security-monitoring
```

---

## Key Takeaways

From this lab, you should understand:
1. **Authentication & Authorization:** Using Cognito for secure API access
2. **Input Validation:** Sanitizing and validating user input
3. **Data Encryption:** Protecting data at rest and in transit with KMS
4. **Least Privilege:** Implementing minimal required permissions
5. **Security Monitoring:** Detecting and alerting on security events
6. **Network Security:** VPC integration for Lambda functions
7. **Security Logging:** Comprehensive audit trails for compliance

---

## Next Steps

This completes Day 2 of the course. In Day 3, you will explore scaling strategies, performance optimization, and automated deployment pipelines for production-ready serverless applications.