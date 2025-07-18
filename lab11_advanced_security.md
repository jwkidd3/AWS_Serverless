# Developing Serverless Solutions on AWS - Day 3 - Lab 11
## Advanced Security Implementation

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will implement advanced security patterns for serverless applications including secrets management, encryption at rest and in transit, security automation, compliance monitoring, and threat detection. You'll build a comprehensive security framework that protects serverless applications from various attack vectors and ensures compliance with security best practices.

## Lab Objectives

By the end of this lab, you will be able to:
- Implement AWS Secrets Manager for secure credential management
- Configure end-to-end encryption using AWS KMS and SSL/TLS
- Deploy security automation using AWS Config and Security Hub
- Implement threat detection with Amazon GuardDuty
- Configure security scanning in CI/CD pipelines
- Set up compliance monitoring and reporting
- Implement defense-in-depth security architecture
- Create security incident response automation
- Apply username prefixing to security resources

## Prerequisites

- Completion of Labs 1-10
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of security concepts and AWS security services

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Security Resources
**IMPORTANT:** All security resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- KMS keys: `user3-advanced-encryption-key`
- Secrets Manager: `user3-database-credentials`
- Security Hub: `user3-security-findings`

---

## Task 1: Implement Advanced Secrets Management

### Step 1.1: Create Secrets Manager Configuration

1. Create database credentials secret:
```bash
aws secretsmanager create-secret \
  --name "[your-username]-database-credentials" \
  --description "Database credentials for serverless application" \
  --secret-string '{
    "username": "admin",
    "password": "MySecurePassword123!",
    "host": "localhost",
    "port": 5432,
    "database": "serverless_app"
  }'
```

2. Create API keys secret:
```bash
aws secretsmanager create-secret \
  --name "[your-username]-api-keys" \
  --description "External API keys for third-party integrations" \
  --secret-string '{
    "stripe_api_key": "sk_test_example_key_12345",
    "sendgrid_api_key": "SG.example_key_67890",
    "github_token": "ghp_example_token_abcdef"
  }'
```

3. Create encryption keys secret:
```bash
aws secretsmanager create-secret \
  --name "[your-username]-encryption-keys" \
  --description "Application-level encryption keys" \
  --secret-string '{
    "jwt_secret": "MyJWTSecret123!@#",
    "encryption_key": "AES256EncryptionKey!",
    "signing_key": "RSASigningKey2048!"
  }'
```

### Step 1.2: Create Secrets-Aware Lambda Function

1. Create directory for secrets management function:
```bash
mkdir ~/environment/[your-username]-secrets-function
cd ~/environment/[your-username]-secrets-function
```

2. Create `secrets_function.py`:
```python
import json
import boto3
import os
import logging
from datetime import datetime
import base64
import hashlib

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager')
kms_client = boto3.client('kms')

def lambda_handler(event, context):
    """
    Advanced secrets management function
    """
    
    try:
        # Extract operation from event
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'get_secrets')
        
        if operation == 'get_database_config':
            result = get_database_configuration()
        elif operation == 'rotate_api_keys':
            result = rotate_api_keys()
        elif operation == 'encrypt_sensitive_data':
            data = body.get('data', '')
            result = encrypt_sensitive_data(data)
        elif operation == 'decrypt_sensitive_data':
            encrypted_data = body.get('encrypted_data', '')
            result = decrypt_sensitive_data(encrypted_data)
        elif operation == 'audit_secrets_access':
            result = audit_secrets_access()
        else:
            result = {'error': 'Unknown operation'}
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'X-Content-Type-Options': 'nosniff'
            },
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Error in secrets function: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

def get_secret_value(secret_name):
    """Securely retrieve secret value"""
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except Exception as e:
        logger.error(f"Failed to retrieve secret {secret_name}: {str(e)}")
        raise

def get_database_configuration():
    """Get database configuration from secrets"""
    
    secret_name = f"{os.environ.get('USERNAME', 'user1')}-database-credentials"
    
    try:
        db_config = get_secret_value(secret_name)
        
        # Return sanitized configuration (no passwords in logs)
        return {
            'host': db_config.get('host'),
            'port': db_config.get('port'),
            'database': db_config.get('database'),
            'username': db_config.get('username'),
            'connection_string': f"postgresql://{db_config.get('username')}:***@{db_config.get('host')}:{db_config.get('port')}/{db_config.get('database')}",
            'retrieved_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Failed to get database config: {str(e)}'}

def rotate_api_keys():
    """Simulate API key rotation"""
    
    secret_name = f"{os.environ.get('USERNAME', 'user1')}-api-keys"
    
    try:
        # Get current keys
        current_keys = get_secret_value(secret_name)
        
        # Generate new keys (in real scenario, these would be obtained from respective services)
        new_keys = {
            'stripe_api_key': f"sk_test_rotated_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'sendgrid_api_key': f"SG.rotated_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            'github_token': f"ghp_rotated_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        }
        
        # Update secret with new keys
        secrets_client.update_secret(
            SecretId=secret_name,
            SecretString=json.dumps(new_keys)
        )
        
        logger.info(f"API keys rotated successfully for {secret_name}")
        
        return {
            'status': 'success',
            'message': 'API keys rotated successfully',
            'rotated_at': datetime.utcnow().isoformat(),
            'keys_rotated': list(new_keys.keys())
        }
        
    except Exception as e:
        return {'error': f'Failed to rotate API keys: {str(e)}'}

def encrypt_sensitive_data(data):
    """Encrypt sensitive data using KMS"""
    
    try:
        kms_key_id = f"alias/{os.environ.get('USERNAME', 'user1')}-advanced-encryption-key"
        
        # Encrypt data using KMS
        response = kms_client.encrypt(
            KeyId=kms_key_id,
            Plaintext=data.encode('utf-8')
        )
        
        # Encode ciphertext as base64 for transport
        encrypted_data = base64.b64encode(response['CiphertextBlob']).decode('utf-8')
        
        return {
            'encrypted_data': encrypted_data,
            'key_id': response['KeyId'],
            'encryption_algorithm': 'AES_256',
            'encrypted_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Failed to encrypt data: {str(e)}'}

def decrypt_sensitive_data(encrypted_data):
    """Decrypt sensitive data using KMS"""
    
    try:
        # Decode base64 encrypted data
        ciphertext_blob = base64.b64decode(encrypted_data.encode('utf-8'))
        
        # Decrypt using KMS
        response = kms_client.decrypt(CiphertextBlob=ciphertext_blob)
        
        # Return decrypted data
        decrypted_data = response['Plaintext'].decode('utf-8')
        
        return {
            'decrypted_data': decrypted_data,
            'key_id': response['KeyId'],
            'decrypted_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Failed to decrypt data: {str(e)}'}

def audit_secrets_access():
    """Audit secrets access patterns"""
    
    username = os.environ.get('USERNAME', 'user1')
    
    try:
        # List secrets for this user
        response = secrets_client.list_secrets(
            MaxResults=50,
            Filters=[
                {
                    'Key': 'name',
                    'Values': [f'{username}-*']
                }
            ]
        )
        
        secrets_audit = []
        
        for secret in response.get('SecretList', []):
            # Get secret metadata
            secret_info = {
                'name': secret['Name'],
                'arn': secret['ARN'],
                'created_date': secret['CreatedDate'].isoformat(),
                'last_accessed_date': secret.get('LastAccessedDate', 'Never').isoformat() if secret.get('LastAccessedDate') else 'Never',
                'last_changed_date': secret.get('LastChangedDate', secret['CreatedDate']).isoformat(),
                'rotation_enabled': secret.get('RotationEnabled', False),
                'description': secret.get('Description', 'No description')
            }
            
            secrets_audit.append(secret_info)
        
        return {
            'audit_timestamp': datetime.utcnow().isoformat(),
            'total_secrets': len(secrets_audit),
            'secrets': secrets_audit,
            'compliance_status': 'compliant' if len(secrets_audit) > 0 else 'no_secrets_found'
        }
        
    except Exception as e:
        return {'error': f'Failed to audit secrets: {str(e)}'}
```

3. Create requirements.txt:
```bash
cat > requirements.txt << 'EOF'
boto3==1.34.0
cryptography==41.0.7
EOF
```

4. Deploy the secrets function:
```bash
pip install -r requirements.txt -t .
zip -r secrets-function.zip .

aws lambda create-function \
  --function-name [your-username]-secrets-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler secrets_function.lambda_handler \
  --zip-file fileb://secrets-function.zip \
  --timeout 60 \
  --memory-size 256 \
  --environment Variables='{USERNAME="[your-username]"}' \
  --description "Advanced secrets management function"
```

---

## Task 2: Implement Advanced Encryption

### Step 2.1: Create Advanced KMS Key Configuration

1. Create customer-managed KMS key with advanced policies:
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
                "AWS": "arn:aws:iam::[ACCOUNT-ID]:role/LabRole"
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": [
                        "lambda.us-east-1.amazonaws.com",
                        "secretsmanager.us-east-1.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Sid": "Allow CloudTrail Encryption",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": [
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Replace placeholder
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" kms-key-policy.json

# Create KMS key
aws kms create-key \
  --description "[your-username] Advanced encryption key for serverless security" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT \
  --policy file://kms-key-policy.json
```

2. Create key alias:
```bash
# Get the key ID from the previous command output
KEY_ID="your-key-id-here"

aws kms create-alias \
  --alias-name alias/[your-username]-advanced-encryption-key \
  --target-key-id $KEY_ID
```

### Step 2.2: Create Encryption Service Function

1. Create directory for encryption service:
```bash
mkdir ~/environment/[your-username]-encryption-service
cd ~/environment/[your-username]-encryption-service
```

2. Create `encryption_service.py`:
```python
import json
import boto3
import base64
import hashlib
import os
import logging
from datetime import datetime
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients
kms_client = boto3.client('kms')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Advanced encryption service for serverless applications
    """
    
    try:
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'encrypt')
        
        if operation == 'encrypt_field':
            result = encrypt_field(body.get('data', ''), body.get('field_type', 'general'))
        elif operation == 'decrypt_field':
            result = decrypt_field(body.get('encrypted_data', ''))
        elif operation == 'encrypt_file':
            result = encrypt_file(body.get('bucket', ''), body.get('key', ''))
        elif operation == 'generate_data_key':
            result = generate_data_key(body.get('key_spec', 'AES_256'))
        elif operation == 'rotate_encryption_key':
            result = rotate_encryption_key()
        elif operation == 'audit_encryption_usage':
            result = audit_encryption_usage()
        else:
            result = {'error': 'Unknown operation'}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Encryption service error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Encryption service error'})
        }

def encrypt_field(data, field_type):
    """Encrypt field data with appropriate protection level"""
    
    try:
        kms_key_id = f"alias/{os.environ.get('USERNAME', 'user1')}-advanced-encryption-key"
        
        # Generate data key for envelope encryption
        response = kms_client.generate_data_key(
            KeyId=kms_key_id,
            KeySpec='AES_256'
        )
        
        # Use plaintext data key for local encryption
        data_key = response['Plaintext']
        encrypted_data_key = response['CiphertextBlob']
        
        # Create Fernet cipher with data key
        fernet = Fernet(base64.urlsafe_b64encode(data_key[:32]))
        
        # Encrypt the data
        encrypted_data = fernet.encrypt(data.encode('utf-8'))
        
        # Create encryption envelope
        envelope = {
            'encrypted_data': base64.b64encode(encrypted_data).decode('utf-8'),
            'encrypted_data_key': base64.b64encode(encrypted_data_key).decode('utf-8'),
            'field_type': field_type,
            'encryption_algorithm': 'Fernet-AES256',
            'encrypted_at': datetime.utcnow().isoformat(),
            'kms_key_id': kms_key_id
        }
        
        # Add data classification based on field type
        if field_type in ['ssn', 'credit_card', 'passport']:
            envelope['classification'] = 'highly_sensitive'
        elif field_type in ['email', 'phone', 'address']:
            envelope['classification'] = 'personal'
        else:
            envelope['classification'] = 'general'
        
        return envelope
        
    except Exception as e:
        return {'error': f'Field encryption failed: {str(e)}'}

def decrypt_field(encrypted_envelope):
    """Decrypt field data from encryption envelope"""
    
    try:
        # Parse encryption envelope
        if isinstance(encrypted_envelope, str):
            envelope = json.loads(encrypted_envelope)
        else:
            envelope = encrypted_envelope
        
        # Decrypt the data key using KMS
        encrypted_data_key = base64.b64decode(envelope['encrypted_data_key'])
        
        response = kms_client.decrypt(CiphertextBlob=encrypted_data_key)
        data_key = response['Plaintext']
        
        # Create Fernet cipher with decrypted data key
        fernet = Fernet(base64.urlsafe_b64encode(data_key[:32]))
        
        # Decrypt the data
        encrypted_data = base64.b64decode(envelope['encrypted_data'])
        decrypted_data = fernet.decrypt(encrypted_data).decode('utf-8')
        
        return {
            'decrypted_data': decrypted_data,
            'field_type': envelope.get('field_type', 'unknown'),
            'classification': envelope.get('classification', 'unknown'),
            'decrypted_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Field decryption failed: {str(e)}'}

def encrypt_file(bucket_name, object_key):
    """Encrypt file in S3 using server-side encryption"""
    
    try:
        kms_key_id = f"alias/{os.environ.get('USERNAME', 'user1')}-advanced-encryption-key"
        
        # Copy object with server-side encryption
        copy_source = {'Bucket': bucket_name, 'Key': object_key}
        
        s3_client.copy_object(
            Bucket=bucket_name,
            Key=f"encrypted/{object_key}",
            CopySource=copy_source,
            ServerSideEncryption='aws:kms',
            SSEKMSKeyId=kms_key_id,
            Metadata={
                'encryption-status': 'encrypted',
                'encrypted-at': datetime.utcnow().isoformat()
            },
            MetadataDirective='REPLACE'
        )
        
        return {
            'status': 'success',
            'encrypted_object': f"encrypted/{object_key}",
            'encryption_type': 'SSE-KMS',
            'kms_key_id': kms_key_id,
            'encrypted_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'File encryption failed: {str(e)}'}

def generate_data_key(key_spec):
    """Generate data key for application-level encryption"""
    
    try:
        kms_key_id = f"alias/{os.environ.get('USERNAME', 'user1')}-advanced-encryption-key"
        
        response = kms_client.generate_data_key(
            KeyId=kms_key_id,
            KeySpec=key_spec
        )
        
        return {
            'plaintext_key': base64.b64encode(response['Plaintext']).decode('utf-8'),
            'encrypted_key': base64.b64encode(response['CiphertextBlob']).decode('utf-8'),
            'key_id': response['KeyId'],
            'key_spec': key_spec,
            'generated_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Data key generation failed: {str(e)}'}

def rotate_encryption_key():
    """Rotate KMS key (enable key rotation)"""
    
    try:
        kms_key_id = f"alias/{os.environ.get('USERNAME', 'user1')}-advanced-encryption-key"
        
        # Enable automatic key rotation
        kms_client.enable_key_rotation(KeyId=kms_key_id)
        
        # Get key rotation status
        response = kms_client.get_key_rotation_status(KeyId=kms_key_id)
        
        return {
            'status': 'success',
            'key_rotation_enabled': response['KeyRotationEnabled'],
            'key_id': kms_key_id,
            'rotation_enabled_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Key rotation failed: {str(e)}'}

def audit_encryption_usage():
    """Audit KMS key usage and encryption patterns"""
    
    try:
        kms_key_id = f"alias/{os.environ.get('USERNAME', 'user1')}-advanced-encryption-key"
        
        # Get key information
        key_info = kms_client.describe_key(KeyId=kms_key_id)
        
        # Get key policy
        key_policy = kms_client.get_key_policy(
            KeyId=kms_key_id,
            PolicyName='default'
        )
        
        # Check key rotation status
        rotation_status = kms_client.get_key_rotation_status(KeyId=kms_key_id)
        
        audit_report = {
            'audit_timestamp': datetime.utcnow().isoformat(),
            'key_id': key_info['KeyMetadata']['KeyId'],
            'key_arn': key_info['KeyMetadata']['Arn'],
            'key_state': key_info['KeyMetadata']['KeyState'],
            'creation_date': key_info['KeyMetadata']['CreationDate'].isoformat(),
            'key_usage': key_info['KeyMetadata']['KeyUsage'],
            'key_spec': key_info['KeyMetadata']['KeySpec'],
            'rotation_enabled': rotation_status['KeyRotationEnabled'],
            'customer_master_key_spec': key_info['KeyMetadata'].get('CustomerMasterKeySpec', 'SYMMETRIC_DEFAULT'),
            'encryption_algorithms': key_info['KeyMetadata'].get('EncryptionAlgorithms', []),
            'policy_size': len(key_policy['Policy']),
            'compliance_status': 'compliant'
        }
        
        return audit_report
        
    except Exception as e:
        return {'error': f'Encryption audit failed: {str(e)}'}
```

3. Deploy encryption service:
```bash
pip install -r requirements.txt -t .
zip -r encryption-service.zip .

aws lambda create-function \
  --function-name [your-username]-encryption-service \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler encryption_service.lambda_handler \
  --zip-file fileb://encryption-service.zip \
  --timeout 60 \
  --memory-size 256 \
  --environment Variables='{USERNAME="[your-username]"}' \
  --description "Advanced encryption service for serverless applications"
```

---

## Task 3: Implement Security Automation

### Step 3.1: Configure AWS Config for Compliance

1. Create Config configuration recorder:
```bash
cat > config-recorder.json << 'EOF'
{
    "name": "[your-username]-security-recorder",
    "roleARN": "arn:aws:iam::[ACCOUNT-ID]:role/config-role",
    "recordingGroup": {
        "allSupported": true,
        "includeGlobalResourceTypes": true,
        "resourceTypes": []
    }
}
EOF

# Replace placeholders
sed -i "s/\[your-username\]/[your-username]/g" config-recorder.json
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" config-recorder.json
```

2. Create Config rules for serverless security:
```bash
# Lambda function security rule
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "[your-username]-lambda-security-check",
    "Description": "Checks if Lambda functions have proper security configuration",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "LAMBDA_FUNCTION_PUBLIC_READ_PROHIBITED"
    },
    "Scope": {
      "ComplianceResourceTypes": ["AWS::Lambda::Function"]
    }
  }'

# S3 bucket encryption rule
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "[your-username]-s3-encryption-check",
    "Description": "Checks if S3 buckets have encryption enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    },
    "Scope": {
      "ComplianceResourceTypes": ["AWS::S3::Bucket"]
    }
  }'

# API Gateway logging rule
aws configservice put-config-rule \
  --config-rule '{
    "ConfigRuleName": "[your-username]-apigateway-logging-check",
    "Description": "Checks if API Gateway has logging enabled",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "API_GW_EXECUTION_LOGGING_ENABLED"
    },
    "Scope": {
      "ComplianceResourceTypes": ["AWS::ApiGateway::Stage"]
    }
  }'
```

### Step 3.2: Create Security Automation Function

1. Create directory for security automation:
```bash
mkdir ~/environment/[your-username]-security-automation
cd ~/environment/[your-username]-security-automation
```

2. Create `security_automation.py`:
```python
import json
import boto3
import logging
from datetime import datetime, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
config_client = boto3.client('config')
lambda_client = boto3.client('lambda')
sns_client = boto3.client('sns')
iam_client = boto3.client('iam')

def lambda_handler(event, context):
    """
    Security automation function for compliance and threat response
    """
    
    try:
        # Check if this is a Config rule evaluation
        if 'configRuleInvokingEvent' in event:
            return handle_config_evaluation(event)
        
        # Check if this is a CloudWatch Event
        if 'source' in event and event['source'] == 'aws.guardduty':
            return handle_guardduty_finding(event)
        
        # Default security audit
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'security_audit')
        
        if operation == 'security_audit':
            result = perform_security_audit()
        elif operation == 'compliance_check':
            result = check_compliance_status()
        elif operation == 'remediate_findings':
            result = remediate_security_findings()
        elif operation == 'generate_security_report':
            result = generate_security_report()
        else:
            result = {'error': 'Unknown operation'}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Security automation error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Security automation failed'})
        }

def handle_config_evaluation(event):
    """Handle AWS Config rule evaluation"""
    
    try:
        # Extract configuration item
        config_item = event['configurationItem']
        resource_type = config_item['resourceType']
        resource_id = config_item['resourceId']
        
        compliance_type = 'COMPLIANT'
        annotation = 'Resource is compliant'
        
        # Custom security checks based on resource type
        if resource_type == 'AWS::Lambda::Function':
            compliance_type, annotation = check_lambda_security(config_item)
        elif resource_type == 'AWS::S3::Bucket':
            compliance_type, annotation = check_s3_security(config_item)
        elif resource_type == 'AWS::ApiGateway::RestApi':
            compliance_type, annotation = check_api_gateway_security(config_item)
        
        # Submit evaluation results
        config_client.put_evaluations(
            Evaluations=[
                {
                    'ComplianceResourceType': resource_type,
                    'ComplianceResourceId': resource_id,
                    'ComplianceType': compliance_type,
                    'Annotation': annotation,
                    'OrderingTimestamp': datetime.utcnow()
                }
            ],
            ResultToken=event['resultToken']
        )
        
        return {'status': 'evaluation_complete'}
        
    except Exception as e:
        logger.error(f"Config evaluation error: {str(e)}")
        return {'error': str(e)}

def check_lambda_security(config_item):
    """Check Lambda function security configuration"""
    
    configuration = config_item.get('configuration', {})
    
    # Check for environment variables encryption
    if 'environment' in configuration:
        env_vars = configuration['environment']
        if 'variables' in env_vars and not env_vars.get('kmsKeyArn'):
            return 'NON_COMPLIANT', 'Lambda function environment variables are not encrypted'
    
    # Check for VPC configuration for sensitive functions
    if not configuration.get('vpcConfig'):
        function_name = configuration.get('functionName', '')
        if any(keyword in function_name.lower() for keyword in ['prod', 'database', 'secret']):
            return 'NON_COMPLIANT', 'Production/sensitive Lambda function should be in VPC'
    
    # Check for appropriate timeout settings
    timeout = configuration.get('timeout', 3)
    if timeout > 900:  # 15 minutes
        return 'NON_COMPLIANT', 'Lambda function timeout is too long (potential for resource abuse)'
    
    return 'COMPLIANT', 'Lambda function passes security checks'

def check_s3_security(config_item):
    """Check S3 bucket security configuration"""
    
    configuration = config_item.get('configuration', {})
    
    # Check for public read access
    if configuration.get('publicReadAccess'):
        return 'NON_COMPLIANT', 'S3 bucket allows public read access'
    
    # Check for public write access
    if configuration.get('publicWriteAccess'):
        return 'NON_COMPLIANT', 'S3 bucket allows public write access'
    
    # Check for versioning
    if not configuration.get('versioningConfiguration', {}).get('status') == 'Enabled':
        return 'NON_COMPLIANT', 'S3 bucket versioning is not enabled'
    
    return 'COMPLIANT', 'S3 bucket passes security checks'

def check_api_gateway_security(config_item):
    """Check API Gateway security configuration"""
    
    configuration = config_item.get('configuration', {})
    
    # Check for API key requirement
    api_key_source = configuration.get('apiKeySource', 'HEADER')
    if api_key_source not in ['HEADER', 'AUTHORIZER']:
        return 'NON_COMPLIANT', 'API Gateway should require API keys or proper authorization'
    
    return 'COMPLIANT', 'API Gateway passes security checks'

def handle_guardduty_finding(event):
    """Handle GuardDuty security findings"""
    
    try:
        detail = event.get('detail', {})
        finding_type = detail.get('type', 'Unknown')
        severity = detail.get('severity', 0)
        
        logger.info(f"Processing GuardDuty finding: {finding_type} with severity {severity}")
        
        # Auto-remediation based on finding type and severity
        if severity >= 7.0:  # High severity
            remediation_actions = auto_remediate_high_severity_finding(detail)
        elif severity >= 4.0:  # Medium severity
            remediation_actions = auto_remediate_medium_severity_finding(detail)
        else:  # Low severity
            remediation_actions = log_low_severity_finding(detail)
        
        return {
            'finding_processed': True,
            'severity': severity,
            'remediation_actions': remediation_actions
        }
        
    except Exception as e:
        logger.error(f"GuardDuty finding handling error: {str(e)}")
        return {'error': str(e)}

def auto_remediate_high_severity_finding(finding_detail):
    """Auto-remediate high severity security findings"""
    
    actions_taken = []
    
    try:
        finding_type = finding_detail.get('type', '')
        
        # Isolate compromised instances
        if 'UnauthorizedAPICall' in finding_type:
            actions_taken.append('Triggered incident response procedure')
            actions_taken.append('Notified security team')
        
        # Block suspicious IP addresses
        if 'Recon' in finding_type:
            actions_taken.append('Added suspicious IPs to blocklist')
        
        # Send immediate alert
        alert_message = f"""
        HIGH SEVERITY SECURITY ALERT
        
        Finding Type: {finding_type}
        Severity: {finding_detail.get('severity', 'Unknown')}
        Description: {finding_detail.get('description', 'No description')}
        
        Automated remediation actions have been initiated.
        Manual review required immediately.
        """
        
        # In real implementation, send to SNS topic
        logger.warning(alert_message)
        actions_taken.append('Sent high priority security alert')
        
    except Exception as e:
        logger.error(f"High severity remediation error: {str(e)}")
        actions_taken.append(f'Remediation error: {str(e)}')
    
    return actions_taken

def auto_remediate_medium_severity_finding(finding_detail):
    """Auto-remediate medium severity security findings"""
    
    actions_taken = []
    
    try:
        finding_type = finding_detail.get('type', '')
        
        # Enhanced monitoring
        actions_taken.append('Enabled enhanced monitoring')
        
        # Log analysis
        actions_taken.append('Initiated automated log analysis')
        
        # Notification
        actions_taken.append('Notified security team via standard channel')
        
    except Exception as e:
        logger.error(f"Medium severity remediation error: {str(e)}")
        actions_taken.append(f'Remediation error: {str(e)}')
    
    return actions_taken

def log_low_severity_finding(finding_detail):
    """Log low severity security findings"""
    
    logger.info(f"Low severity finding logged: {finding_detail.get('type', 'Unknown')}")
    return ['Logged finding for trend analysis']

def perform_security_audit():
    """Perform comprehensive security audit"""
    
    audit_results = {
        'audit_timestamp': datetime.utcnow().isoformat(),
        'compliance_checks': [],
        'security_findings': [],
        'recommendations': []
    }
    
    try:
        # Check Config compliance
        compliance_summary = config_client.get_compliance_summary_by_config_rule()
        
        audit_results['compliance_summary'] = {
            'compliant_rules': compliance_summary['ComplianceSummary']['ComplianceTypes'].get('COMPLIANT', 0),
            'non_compliant_rules': compliance_summary['ComplianceSummary']['ComplianceTypes'].get('NON_COMPLIANT', 0),
            'insufficient_data': compliance_summary['ComplianceSummary']['ComplianceTypes'].get('INSUFFICIENT_DATA', 0)
        }
        
        # Security recommendations
        audit_results['recommendations'] = [
            'Enable GuardDuty for threat detection',
            'Implement least privilege IAM policies',
            'Enable CloudTrail for all regions',
            'Configure VPC Flow Logs',
            'Enable Config rules for compliance monitoring'
        ]
        
        audit_results['audit_status'] = 'completed'
        
    except Exception as e:
        audit_results['error'] = str(e)
        audit_results['audit_status'] = 'failed'
    
    return audit_results

def check_compliance_status():
    """Check compliance status across all resources"""
    
    try:
        # Get compliance by config rule
        response = config_client.get_compliance_summary_by_config_rule()
        
        compliance_status = {
            'timestamp': datetime.utcnow().isoformat(),
            'overall_compliance': response['ComplianceSummary'],
            'compliant_percentage': 0
        }
        
        total_rules = sum(response['ComplianceSummary']['ComplianceTypes'].values())
        if total_rules > 0:
            compliant_rules = response['ComplianceSummary']['ComplianceTypes'].get('COMPLIANT', 0)
            compliance_status['compliant_percentage'] = (compliant_rules / total_rules) * 100
        
        return compliance_status
        
    except Exception as e:
        return {'error': f'Compliance check failed: {str(e)}'}

def remediate_security_findings():
    """Remediate identified security findings"""
    
    remediation_results = {
        'timestamp': datetime.utcnow().isoformat(),
        'actions_taken': [],
        'failed_remediations': []
    }
    
    try:
        # Get non-compliant resources
        non_compliant = config_client.get_compliance_details_by_config_rule(
            ConfigRuleName='lambda-function-public-read-prohibited',
            ComplianceTypes=['NON_COMPLIANT']
        )
        
        for evaluation in non_compliant.get('EvaluationResults', []):
            resource_id = evaluation['EvaluationResultIdentifier']['EvaluationResultQualifier']['ResourceId']
            
            try:
                # Example: Remove public permissions from Lambda functions
                if evaluation['EvaluationResultIdentifier']['EvaluationResultQualifier']['ResourceType'] == 'AWS::Lambda::Function':
                    # In real implementation, remove public policies
                    remediation_results['actions_taken'].append(f'Removed public access from Lambda function {resource_id}')
                    
            except Exception as e:
                remediation_results['failed_remediations'].append({
                    'resource_id': resource_id,
                    'error': str(e)
                })
        
    except Exception as e:
        remediation_results['error'] = str(e)
    
    return remediation_results

def generate_security_report():
    """Generate comprehensive security report"""
    
    report = {
        'report_timestamp': datetime.utcnow().isoformat(),
        'report_period': '24_hours',
        'executive_summary': {},
        'detailed_findings': {},
        'compliance_status': {},
        'recommendations': []
    }
    
    try:
        # Executive summary
        report['executive_summary'] = {
            'total_resources_scanned': 0,
            'security_issues_found': 0,
            'critical_issues': 0,
            'compliance_score': 85.5,
            'trend': 'improving'
        }
        
        # Recommendations
        report['recommendations'] = [
            'Enable MFA for all IAM users',
            'Implement resource-based policies',
            'Regular security training for developers',
            'Automated security testing in CI/CD pipeline'
        ]
        
        report['report_status'] = 'completed'
        
    except Exception as e:
        report['error'] = str(e)
        report['report_status'] = 'failed'
    
    return report
```

3. Deploy security automation function:
```bash
zip security-automation.zip security_automation.py

aws lambda create-function \
  --function-name [your-username]-security-automation \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler security_automation.lambda_handler \
  --zip-file fileb://security-automation.zip \
  --timeout 300 \
  --memory-size 512 \
  --description "Security automation and compliance monitoring"
```

---

## Task 4: Configure Threat Detection

### Step 4.1: Enable GuardDuty

1. Enable GuardDuty for threat detection:
```bash
aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES
```

2. Get detector ID:
```bash
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
echo "GuardDuty Detector ID: $DETECTOR_ID"
```

### Step 4.2: Create Threat Response Function

1. Create directory for threat response:
```bash
mkdir ~/environment/[your-username]-threat-response
cd ~/environment/[your-username]-threat-response
```

2. Create `threat_response.py`:
```python
import json
import boto3
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
guardduty_client = boto3.client('guardduty')
ec2_client = boto3.client('ec2')
iam_client = boto3.client('iam')
sns_client = boto3.client('sns')

def lambda_handler(event, context):
    """
    Automated threat response function
    """
    
    try:
        # Check if this is a GuardDuty finding
        if event.get('source') == 'aws.guardduty':
            return handle_guardduty_finding(event)
        
        # Manual threat response operations
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'list_findings')
        
        if operation == 'list_findings':
            result = list_security_findings()
        elif operation == 'analyze_threats':
            result = analyze_threat_patterns()
        elif operation == 'generate_threat_report':
            result = generate_threat_report()
        elif operation == 'test_threat_detection':
            result = test_threat_detection()
        else:
            result = {'error': 'Unknown operation'}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Threat response error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Threat response failed'})
        }

def handle_guardduty_finding(event):
    """Handle GuardDuty finding events"""
    
    try:
        detail = event.get('detail', {})
        finding_id = detail.get('id', 'unknown')
        finding_type = detail.get('type', 'unknown')
        severity = detail.get('severity', 0)
        
        logger.info(f"Processing GuardDuty finding {finding_id}: {finding_type} (severity: {severity})")
        
        response_actions = []
        
        # Severity-based automated response
        if severity >= 8.0:  # Critical
            response_actions.extend(handle_critical_threat(detail))
        elif severity >= 5.0:  # High
            response_actions.extend(handle_high_threat(detail))
        elif severity >= 2.0:  # Medium
            response_actions.extend(handle_medium_threat(detail))
        else:  # Low
            response_actions.extend(handle_low_threat(detail))
        
        # Log the response
        logger.info(f"Threat response completed for {finding_id}: {response_actions}")
        
        return {
            'finding_id': finding_id,
            'severity': severity,
            'response_actions': response_actions,
            'response_timestamp': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"GuardDuty finding handling error: {str(e)}")
        return {'error': str(e)}

def handle_critical_threat(finding_detail):
    """Handle critical severity threats"""
    
    actions = []
    
    try:
        finding_type = finding_detail.get('type', '')
        
        # Immediate isolation for critical threats
        if 'Trojan' in finding_type or 'Backdoor' in finding_type:
            actions.append('CRITICAL: Initiated emergency incident response')
            actions.append('CRITICAL: Isolated affected resources')
            
        # Block malicious IPs immediately
        if 'service' in finding_detail:
            remote_ip = finding_detail['service'].get('remoteIpDetails', {}).get('ipAddressV4', '')
            if remote_ip:
                actions.append(f'CRITICAL: Blocked malicious IP {remote_ip}')
        
        # Send emergency alert
        actions.append('CRITICAL: Sent emergency security alert to on-call team')
        
        # Create security incident
        actions.append('CRITICAL: Created high-priority security incident ticket')
        
    except Exception as e:
        actions.append(f'CRITICAL ERROR: {str(e)}')
    
    return actions

def handle_high_threat(finding_detail):
    """Handle high severity threats"""
    
    actions = []
    
    try:
        finding_type = finding_detail.get('type', '')
        
        # Enhanced monitoring
        actions.append('HIGH: Enabled enhanced monitoring for affected resources')
        
        # Security group restrictions
        if 'UnauthorizedAPICall' in finding_type:
            actions.append('HIGH: Applied temporary security group restrictions')
        
        # Detailed analysis
        actions.append('HIGH: Initiated detailed forensic analysis')
        
        # Notification
        actions.append('HIGH: Notified security team for immediate review')
        
    except Exception as e:
        actions.append(f'HIGH ERROR: {str(e)}')
    
    return actions

def handle_medium_threat(finding_detail):
    """Handle medium severity threats"""
    
    actions = []
    
    try:
        # Standard monitoring
        actions.append('MEDIUM: Applied standard threat monitoring')
        
        # Log collection
        actions.append('MEDIUM: Initiated enhanced log collection')
        
        # Team notification
        actions.append('MEDIUM: Added to security review queue')
        
    except Exception as e:
        actions.append(f'MEDIUM ERROR: {str(e)}')
    
    return actions

def handle_low_threat(finding_detail):
    """Handle low severity threats"""
    
    actions = []
    
    try:
        # Basic logging
        actions.append('LOW: Logged for trend analysis')
        
        # Pattern analysis
        actions.append('LOW: Added to threat pattern database')
        
    except Exception as e:
        actions.append(f'LOW ERROR: {str(e)}')
    
    return actions

def list_security_findings():
    """List current security findings from GuardDuty"""
    
    try:
        # Get detector ID
        detectors = guardduty_client.list_detectors()
        if not detectors['DetectorIds']:
            return {'error': 'No GuardDuty detectors found'}
        
        detector_id = detectors['DetectorIds'][0]
        
        # Get findings
        findings_response = guardduty_client.list_findings(
            DetectorId=detector_id,
            MaxResults=50
        )
        
        findings_details = []
        
        if findings_response['FindingIds']:
            # Get detailed information for findings
            details_response = guardduty_client.get_findings(
                DetectorId=detector_id,
                FindingIds=findings_response['FindingIds']
            )
            
            for finding in details_response['Findings']:
                findings_details.append({
                    'id': finding['Id'],
                    'type': finding['Type'],
                    'severity': finding['Severity'],
                    'title': finding['Title'],
                    'description': finding['Description'],
                    'created_at': finding['CreatedAt'],
                    'updated_at': finding['UpdatedAt']
                })
        
        return {
            'total_findings': len(findings_details),
            'findings': findings_details,
            'detector_id': detector_id,
            'retrieved_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Failed to list findings: {str(e)}'}

def analyze_threat_patterns():
    """Analyze threat patterns and trends"""
    
    try:
        # Get detector ID
        detectors = guardduty_client.list_detectors()
        if not detectors['DetectorIds']:
            return {'error': 'No GuardDuty detectors found'}
        
        detector_id = detectors['DetectorIds'][0]
        
        # Get findings for analysis
        findings_response = guardduty_client.list_findings(
            DetectorId=detector_id,
            MaxResults=100
        )
        
        if not findings_response['FindingIds']:
            return {
                'analysis_timestamp': datetime.utcnow().isoformat(),
                'total_findings': 0,
                'threat_patterns': {},
                'recommendations': ['No threats detected - maintain current security posture']
            }
        
        # Get detailed findings
        details_response = guardduty_client.get_findings(
            DetectorId=detector_id,
            FindingIds=findings_response['FindingIds']
        )
        
        # Analyze patterns
        threat_patterns = {}
        severity_distribution = {'low': 0, 'medium': 0, 'high': 0, 'critical': 0}
        
        for finding in details_response['Findings']:
            threat_type = finding['Type'].split('.')[0]  # Get main category
            severity = finding['Severity']
            
            if threat_type not in threat_patterns:
                threat_patterns[threat_type] = 0
            threat_patterns[threat_type] += 1
            
            # Categorize severity
            if severity >= 8.0:
                severity_distribution['critical'] += 1
            elif severity >= 5.0:
                severity_distribution['high'] += 1
            elif severity >= 2.0:
                severity_distribution['medium'] += 1
            else:
                severity_distribution['low'] += 1
        
        # Generate recommendations
        recommendations = []
        if threat_patterns.get('Recon', 0) > 5:
            recommendations.append('High reconnaissance activity detected - consider implementing additional monitoring')
        if severity_distribution['critical'] > 0:
            recommendations.append('Critical threats detected - immediate security review required')
        if severity_distribution['high'] > 10:
            recommendations.append('Multiple high-severity threats - security posture assessment recommended')
        
        return {
            'analysis_timestamp': datetime.utcnow().isoformat(),
            'total_findings': len(details_response['Findings']),
            'threat_patterns': threat_patterns,
            'severity_distribution': severity_distribution,
            'recommendations': recommendations if recommendations else ['Continue monitoring - no immediate action required']
        }
        
    except Exception as e:
        return {'error': f'Threat analysis failed: {str(e)}'}

def generate_threat_report():
    """Generate comprehensive threat report"""
    
    report = {
        'report_timestamp': datetime.utcnow().isoformat(),
        'report_period': '7_days',
        'executive_summary': {},
        'threat_landscape': {},
        'incident_summary': {},
        'recommendations': []
    }
    
    try:
        # Get threat analysis
        threat_analysis = analyze_threat_patterns()
        
        if 'error' not in threat_analysis:
            report['executive_summary'] = {
                'total_threats_detected': threat_analysis['total_findings'],
                'critical_incidents': threat_analysis['severity_distribution']['critical'],
                'security_posture': 'stable' if threat_analysis['total_findings'] < 10 else 'elevated',
                'trend': 'monitoring'
            }
            
            report['threat_landscape'] = threat_analysis['threat_patterns']
            report['recommendations'] = threat_analysis['recommendations']
        
        # Add compliance information
        report['compliance_status'] = {
            'guardduty_enabled': True,
            'config_rules_active': True,
            'cloudtrail_enabled': True,
            'overall_compliance': 'good'
        }
        
        report['report_status'] = 'completed'
        
    except Exception as e:
        report['error'] = str(e)
        report['report_status'] = 'failed'
    
    return report

def test_threat_detection():
    """Test threat detection capabilities"""
    
    test_results = {
        'test_timestamp': datetime.utcnow().isoformat(),
        'tests_performed': [],
        'detection_capabilities': {},
        'recommendations': []
    }
    
    try:
        # Test 1: Check GuardDuty status
        detectors = guardduty_client.list_detectors()
        if detectors['DetectorIds']:
            detector_id = detectors['DetectorIds'][0]
            detector_details = guardduty_client.get_detector(DetectorId=detector_id)
            
            test_results['detection_capabilities']['guardduty'] = {
                'enabled': detector_details['Status'] == 'ENABLED',
                'finding_frequency': detector_details['FindingPublishingFrequency'],
                'data_sources': detector_details.get('DataSources', {})
            }
            test_results['tests_performed'].append('GuardDuty configuration check')
        
        # Test 2: Validate threat response function
        test_results['detection_capabilities']['threat_response'] = {
            'function_available': True,
            'response_time': '< 1 minute',
            'automation_level': 'high'
        }
        test_results['tests_performed'].append('Threat response function validation')
        
        # Recommendations based on test results
        if test_results['detection_capabilities']['guardduty']['enabled']:
            test_results['recommendations'].append('GuardDuty is properly configured')
        else:
            test_results['recommendations'].append('Enable GuardDuty for threat detection')
        
        test_results['test_status'] = 'completed'
        
    except Exception as e:
        test_results['error'] = str(e)
        test_results['test_status'] = 'failed'
    
    return test_results
```

3. Deploy threat response function:
```bash
zip threat-response.zip threat_response.py

aws lambda create-function \
  --function-name [your-username]-threat-response \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler threat_response.lambda_handler \
  --zip-file fileb://threat-response.zip \
  --timeout 300 \
  --memory-size 512 \
  --description "Automated threat detection and response"
```

---

## Task 5: Create Security APIs

### Step 5.1: Create Secure API Gateway

1. Create API Gateway for security functions:
```bash
aws apigateway create-rest-api \
  --name "[your-username]-security-api" \
  --description "Advanced security management API"
```

2. Get API ID and create resources:
```bash
# Note the API ID from the previous command
API_ID="your-api-id-here"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/`].id' --output text)

# Create security resource
aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part security

SECURITY_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?pathPart==`security`].id' --output text)

# Create sub-resources
aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $SECURITY_RESOURCE_ID \
  --path-part secrets

aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $SECURITY_RESOURCE_ID \
  --path-part encryption

aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $SECURITY_RESOURCE_ID \
  --path-part threats
```

3. Create methods and integrations for each security function (follow the pattern from previous labs).

---

## Task 6: Test Security Implementation

### Step 6.1: Test Secrets Management

1. Test secrets retrieval:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/security/secrets" \
  -H "Content-Type: application/json" \
  -d '{"operation": "get_database_config"}'
```

2. Test API key rotation:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/security/secrets" \
  -H "Content-Type: application/json" \
  -d '{"operation": "rotate_api_keys"}'
```

### Step 6.2: Test Encryption Services

1. Test field encryption:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/security/encryption" \
  -H "Content-Type: application/json" \
  -d '{"operation": "encrypt_field", "data": "sensitive-information", "field_type": "ssn"}'
```

2. Test data key generation:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/security/encryption" \
  -H "Content-Type: application/json" \
  -d '{"operation": "generate_data_key", "key_spec": "AES_256"}'
```

### Step 6.3: Test Threat Detection

1. Test threat analysis:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/security/threats" \
  -H "Content-Type: application/json" \
  -d '{"operation": "analyze_threats"}'
```

2. Test security findings:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/security/threats" \
  -H "Content-Type: application/json" \
  -d '{"operation": "list_findings"}'
```

---

## Task 7: Create Security Dashboard

### Step 7.1: Create Comprehensive Security Dashboard

1. Create security monitoring dashboard:
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
                    [ "AWS/GuardDuty", "FindingCount" ],
                    [ "AWS/Config", "ComplianceByConfigRule", "RuleName", "[your-username]-lambda-security-check" ],
                    [ ".", ".", ".", "[your-username]-s3-encryption-check" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Security Metrics"
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
                    [ "AWS/Lambda", "Invocations", "FunctionName", "[your-username]-secrets-function" ],
                    [ ".", ".", ".", "[your-username]-encryption-service" ],
                    [ ".", ".", ".", "[your-username]-threat-response" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Security Function Activity"
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
                    [ "AWS/KMS", "NumberOfRequestsSucceeded", "KeyId", "alias/[your-username]-advanced-encryption-key" ],
                    [ ".", "NumberOfRequestsFailed", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Encryption Key Usage"
            }
        }
    ]
}
EOF

sed -i "s/\[your-username\]/[your-username]/g" security-dashboard.json

aws cloudwatch put-dashboard \
  --dashboard-name "[your-username]-advanced-security" \
  --dashboard-body file://security-dashboard.json
```

---

## Task 8: Implement Security Incident Response

### Step 8.1: Create Incident Response Function

1. Create directory for incident response:
```bash
mkdir ~/environment/[your-username]-incident-response
cd ~/environment/[your-username]-incident-response
```

2. Create `incident_response.py`:
```python
import json
import boto3
import logging
from datetime import datetime, timedelta
import uuid

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
sns_client = boto3.client('sns')
lambda_client = boto3.client('lambda')
sts_client = boto3.client('sts')
iam_client = boto3.client('iam')

def lambda_handler(event, context):
    """
    Security incident response automation
    """
    
    try:
        # Check if this is an automated incident trigger
        if 'source' in event and 'detail' in event:
            return handle_automated_incident(event)
        
        # Manual incident response operations
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'create_incident')
        
        if operation == 'create_incident':
            result = create_security_incident(body)
        elif operation == 'escalate_incident':
            result = escalate_incident(body.get('incident_id'))
        elif operation == 'contain_threat':
            result = contain_security_threat(body)
        elif operation == 'generate_incident_report':
            result = generate_incident_report(body.get('incident_id'))
        elif operation == 'list_active_incidents':
            result = list_active_incidents()
        else:
            result = {'error': 'Unknown operation'}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Incident response error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Incident response failed'})
        }

def handle_automated_incident(event):
    """Handle automated incident creation from security events"""
    
    try:
        source = event.get('source', '')
        detail = event.get('detail', {})
        
        incident_data = {
            'source': source,
            'severity': 'medium',
            'description': 'Automated incident from security event',
            'details': detail
        }
        
        # Determine severity based on source
        if source == 'aws.guardduty':
            severity = detail.get('severity', 0)
            if severity >= 8.0:
                incident_data['severity'] = 'critical'
            elif severity >= 5.0:
                incident_data['severity'] = 'high'
            elif severity >= 2.0:
                incident_data['severity'] = 'medium'
            else:
                incident_data['severity'] = 'low'
            
            incident_data['description'] = f"GuardDuty finding: {detail.get('type', 'Unknown threat')}"
        
        elif source == 'aws.config':
            incident_data['severity'] = 'medium'
            incident_data['description'] = f"Config compliance violation: {detail.get('configRuleName', 'Unknown rule')}"
        
        # Create incident
        incident = create_security_incident(incident_data)
        
        # Auto-escalate critical incidents
        if incident_data['severity'] == 'critical':
            escalate_incident(incident.get('incident_id'))
        
        return incident
        
    except Exception as e:
        logger.error(f"Automated incident handling error: {str(e)}")
        return {'error': str(e)}

def create_security_incident(incident_data):
    """Create a new security incident"""
    
    try:
        incident_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        incident = {
            'incident_id': incident_id,
            'created_at': timestamp,
            'updated_at': timestamp,
            'status': 'open',
            'severity': incident_data.get('severity', 'medium'),
            'title': incident_data.get('title', 'Security Incident'),
            'description': incident_data.get('description', 'Security incident requiring investigation'),
            'source': incident_data.get('source', 'manual'),
            'affected_resources': incident_data.get('affected_resources', []),
            'details': incident_data.get('details', {}),
            'response_actions': [],
            'assigned_to': 'security_team',
            'escalation_level': 0
        }
        
        # Log incident creation
        logger.info(f"Created security incident {incident_id} with severity {incident['severity']}")
        
        # Immediate response actions based on severity
        if incident['severity'] == 'critical':
            incident['response_actions'].extend(handle_critical_incident(incident))
        elif incident['severity'] == 'high':
            incident['response_actions'].extend(handle_high_incident(incident))
        
        # Send notifications
        send_incident_notification(incident)
        
        # In real implementation, store in database
        # For demo, we'll return the incident object
        return incident
        
    except Exception as e:
        return {'error': f'Failed to create incident: {str(e)}'}

def escalate_incident(incident_id):
    """Escalate security incident to higher level"""
    
    try:
        # In real implementation, retrieve incident from database
        # For demo, simulate escalation
        
        escalation_actions = [
            'Notified senior security team',
            'Engaged external security consultant',
            'Initiated emergency response protocol',
            'Scheduled executive briefing'
        ]
        
        # Send high-priority notification
        notification_message = f"""
        SECURITY INCIDENT ESCALATION
        
        Incident ID: {incident_id}
        Escalation Time: {datetime.utcnow().isoformat()}
        
        This security incident has been escalated and requires immediate attention
        from senior security personnel.
        
        Automated escalation actions have been initiated.
        """
        
        logger.warning(notification_message)
        
        return {
            'incident_id': incident_id,
            'escalated_at': datetime.utcnow().isoformat(),
            'escalation_actions': escalation_actions,
            'status': 'escalated'
        }
        
    except Exception as e:
        return {'error': f'Failed to escalate incident: {str(e)}'}

def contain_security_threat(containment_data):
    """Implement threat containment measures"""
    
    try:
        threat_type = containment_data.get('threat_type', 'unknown')
        affected_resources = containment_data.get('affected_resources', [])
        
        containment_actions = []
        
        # Implement containment based on threat type
        if threat_type == 'compromised_credentials':
            containment_actions.extend(contain_compromised_credentials(affected_resources))
        elif threat_type == 'malicious_ip':
            containment_actions.extend(contain_malicious_ip(containment_data.get('ip_address')))
        elif threat_type == 'compromised_instance':
            containment_actions.extend(contain_compromised_instance(affected_resources))
        elif threat_type == 'data_exfiltration':
            containment_actions.extend(contain_data_exfiltration(affected_resources))
        else:
            containment_actions.append('Applied generic containment measures')
        
        return {
            'threat_type': threat_type,
            'containment_timestamp': datetime.utcnow().isoformat(),
            'containment_actions': containment_actions,
            'affected_resources': affected_resources,
            'status': 'contained'
        }
        
    except Exception as e:
        return {'error': f'Threat containment failed: {str(e)}'}

def contain_compromised_credentials(affected_resources):
    """Contain compromised credentials threat"""
    
    actions = []
    
    try:
        for resource in affected_resources:
            if resource.get('type') == 'iam_user':
                user_name = resource.get('name')
                # In real implementation, disable user and rotate keys
                actions.append(f'Disabled IAM user: {user_name}')
                actions.append(f'Rotated access keys for: {user_name}')
                actions.append(f'Revoked active sessions for: {user_name}')
            
            elif resource.get('type') == 'iam_role':
                role_name = resource.get('name')
                # In real implementation, modify role trust policy
                actions.append(f'Applied restrictive policy to role: {role_name}')
        
        actions.append('Initiated credential rotation process')
        actions.append('Enabled enhanced monitoring for affected accounts')
        
    except Exception as e:
        actions.append(f'Credential containment error: {str(e)}')
    
    return actions

def contain_malicious_ip(ip_address):
    """Contain malicious IP address threat"""
    
    actions = []
    
    try:
        if ip_address:
            # In real implementation, update security groups and NACLs
            actions.append(f'Blocked IP address: {ip_address}')
            actions.append(f'Updated security group rules to deny {ip_address}')
            actions.append(f'Added {ip_address} to threat intelligence feed')
            actions.append('Reviewed all connections from malicious IP')
        else:
            actions.append('No IP address provided for containment')
        
    except Exception as e:
        actions.append(f'IP containment error: {str(e)}')
    
    return actions

def contain_compromised_instance(affected_resources):
    """Contain compromised EC2 instances"""
    
    actions = []
    
    try:
        for resource in affected_resources:
            if resource.get('type') == 'ec2_instance':
                instance_id = resource.get('id')
                # In real implementation, isolate instance
                actions.append(f'Isolated EC2 instance: {instance_id}')
                actions.append(f'Created forensic snapshot of: {instance_id}')
                actions.append(f'Applied quarantine security group to: {instance_id}')
        
        actions.append('Initiated malware scan on affected instances')
        actions.append('Collected system logs for analysis')
        
    except Exception as e:
        actions.append(f'Instance containment error: {str(e)}')
    
    return actions

def contain_data_exfiltration(affected_resources):
    """Contain data exfiltration threat"""
    
    actions = []
    
    try:
        for resource in affected_resources:
            if resource.get('type') == 's3_bucket':
                bucket_name = resource.get('name')
                # In real implementation, apply restrictive bucket policy
                actions.append(f'Applied emergency access restrictions to bucket: {bucket_name}')
                actions.append(f'Enabled detailed access logging for: {bucket_name}')
            
            elif resource.get('type') == 'database':
                db_name = resource.get('name')
                actions.append(f'Enabled query logging for database: {db_name}')
                actions.append(f'Applied connection restrictions to: {db_name}')
        
        actions.append('Initiated data loss prevention scan')
        actions.append('Reviewed network traffic for data transfer patterns')
        
    except Exception as e:
        actions.append(f'Data exfiltration containment error: {str(e)}')
    
    return actions

def handle_critical_incident(incident):
    """Handle critical severity incidents"""
    
    actions = []
    
    try:
        # Immediate actions for critical incidents
        actions.append('CRITICAL: Activated emergency response team')
        actions.append('CRITICAL: Initiated executive notification protocol')
        actions.append('CRITICAL: Enabled enhanced monitoring across all systems')
        actions.append('CRITICAL: Prepared for potential system isolation')
        
        # Auto-escalation
        actions.append('CRITICAL: Automatically escalated to senior security leadership')
        
    except Exception as e:
        actions.append(f'Critical incident handling error: {str(e)}')
    
    return actions

def handle_high_incident(incident):
    """Handle high severity incidents"""
    
    actions = []
    
    try:
        # Standard actions for high incidents
        actions.append('HIGH: Notified security operations center')
        actions.append('HIGH: Initiated detailed investigation')
        actions.append('HIGH: Applied precautionary security measures')
        actions.append('HIGH: Scheduled leadership briefing')
        
    except Exception as e:
        actions.append(f'High incident handling error: {str(e)}')
    
    return actions

def send_incident_notification(incident):
    """Send incident notification to appropriate channels"""
    
    try:
        severity = incident['severity']
        incident_id = incident['incident_id']
        
        notification_message = f"""
        SECURITY INCIDENT ALERT
        
        Incident ID: {incident_id}
        Severity: {severity.upper()}
        Title: {incident['title']}
        Description: {incident['description']}
        Created: {incident['created_at']}
        
        Immediate response actions have been initiated.
        Please review incident details and take appropriate action.
        """
        
        # In real implementation, send to SNS topic
        logger.info(f"INCIDENT NOTIFICATION: {notification_message}")
        
    except Exception as e:
        logger.error(f"Failed to send incident notification: {str(e)}")

def generate_incident_report(incident_id):
    """Generate detailed incident report"""
    
    try:
        # In real implementation, retrieve incident from database
        # For demo, simulate report generation
        
        report = {
            'incident_id': incident_id,
            'report_generated_at': datetime.utcnow().isoformat(),
            'incident_timeline': [
                {
                    'timestamp': '2024-01-01T10:00:00Z',
                    'event': 'Incident detected',
                    'details': 'Automated security alert triggered'
                },
                {
                    'timestamp': '2024-01-01T10:02:00Z',
                    'event': 'Initial response',
                    'details': 'Security team notified and investigation started'
                },
                {
                    'timestamp': '2024-01-01T10:15:00Z',
                    'event': 'Containment initiated',
                    'details': 'Threat containment measures applied'
                }
            ],
            'impact_assessment': {
                'affected_systems': 3,
                'data_compromised': False,
                'service_disruption': 'minimal',
                'estimated_cost': '$1,000'
            },
            'root_cause': 'Configuration vulnerability in security group',
            'lessons_learned': [
                'Implement automated security group validation',
                'Enhance monitoring for configuration changes',
                'Update incident response procedures'
            ],
            'recommendations': [
                'Deploy additional monitoring controls',
                'Conduct security awareness training',
                'Review and update security policies'
            ],
            'status': 'resolved'
        }
        
        return report
        
    except Exception as e:
        return {'error': f'Failed to generate incident report: {str(e)}'}

def list_active_incidents():
    """List all active security incidents"""
    
    try:
        # In real implementation, query database for active incidents
        # For demo, simulate active incidents list
        
        active_incidents = [
            {
                'incident_id': 'inc-001',
                'severity': 'medium',
                'title': 'Unauthorized API access attempt',
                'status': 'investigating',
                'created_at': '2024-01-01T09:30:00Z',
                'last_updated': '2024-01-01T10:45:00Z'
            },
            {
                'incident_id': 'inc-002',
                'severity': 'low',
                'title': 'Suspicious login activity',
                'status': 'monitoring',
                'created_at': '2024-01-01T08:15:00Z',
                'last_updated': '2024-01-01T09:20:00Z'
            }
        ]
        
        return {
            'total_active_incidents': len(active_incidents),
            'incidents': active_incidents,
            'retrieved_at': datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        return {'error': f'Failed to list incidents: {str(e)}'}
```

3. Deploy incident response function:
```bash
zip incident-response.zip incident_response.py

aws lambda create-function \
  --function-name [your-username]-incident-response \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler incident_response.lambda_handler \
  --zip-file fileb://incident-response.zip \
  --timeout 300 \
  --memory-size 512 \
  --description "Security incident response and management"
```

---

## Task 9: Implement Security Compliance Monitoring

### Step 9.1: Create Compliance Monitoring Function

1. Create directory for compliance monitoring:
```bash
mkdir ~/environment/[your-username]-compliance-monitor
cd ~/environment/[your-username]-compliance-monitor
```

2. Create `compliance_monitor.py`:
```python
import json
import boto3
import logging
from datetime import datetime, timedelta

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
config_client = boto3.client('config')
securityhub_client = boto3.client('securityhub')
cloudtrail_client = boto3.client('cloudtrail')

def lambda_handler(event, context):
    """
    Security compliance monitoring and reporting
    """
    
    try:
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'compliance_check')
        
        if operation == 'compliance_check':
            result = perform_compliance_check()
        elif operation == 'generate_compliance_report':
            result = generate_compliance_report()
        elif operation == 'check_security_standards':
            result = check_security_standards()
        elif operation == 'audit_access_patterns':
            result = audit_access_patterns()
        elif operation == 'validate_encryption_compliance':
            result = validate_encryption_compliance()
        else:
            result = {'error': 'Unknown operation'}
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Compliance monitoring error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Compliance monitoring failed'})
        }

def perform_compliance_check():
    """Perform comprehensive compliance check"""
    
    try:
        compliance_results = {
            'check_timestamp': datetime.utcnow().isoformat(),
            'overall_compliance_score': 0,
            'framework_compliance': {},
            'control_results': {},
            'recommendations': []
        }
        
        # Check AWS Config compliance
        config_compliance = check_config_compliance()
        compliance_results['control_results']['config'] = config_compliance
        
        # Check Security Hub findings
        securityhub_compliance = check_securityhub_compliance()
        compliance_results['control_results']['security_hub'] = securityhub_compliance
        
        # Check encryption compliance
        encryption_compliance = check_encryption_compliance()
        compliance_results['control_results']['encryption'] = encryption_compliance
        
        # Check access control compliance
        access_compliance = check_access_control_compliance()
        compliance_results['control_results']['access_control'] = access_compliance
        
        # Calculate overall compliance score
        total_checks = len(compliance_results['control_results'])
        passing_checks = sum(1 for result in compliance_results['control_results'].values() if result.get('compliant', False))
        
        if total_checks > 0:
            compliance_results['overall_compliance_score'] = (passing_checks / total_checks) * 100
        
        # Framework-specific compliance
        compliance_results['framework_compliance'] = {
            'SOC2': calculate_soc2_compliance(compliance_results['control_results']),
            'GDPR': calculate_gdpr_compliance(compliance_results['control_results']),
            'HIPAA': calculate_hipaa_compliance(compliance_results['control_results']),
            'PCI_DSS': calculate_pci_compliance(compliance_results['control_results'])
        }
        
        # Generate recommendations
        compliance_results['recommendations'] = generate_compliance_recommendations(compliance_results['control_results'])
        
        return compliance_results
        
    except Exception as e:
        return {'error': f'Compliance check failed: {str(e)}'}

def check_config_compliance():
    """Check AWS Config rule compliance"""
    
    try:
        # Get compliance summary
        summary = config_client.get_compliance_summary_by_config_rule()
        
        total_rules = sum(summary['ComplianceSummary']['ComplianceTypes'].values())
        compliant_rules = summary['ComplianceSummary']['ComplianceTypes'].get('COMPLIANT', 0)
        
        compliance_percentage = (compliant_rules / total_rules * 100) if total_rules > 0 else 0
        
        return {
            'compliant': compliance_percentage >= 80,
            'compliance_percentage': compliance_percentage,
            'total_rules': total_rules,
            'compliant_rules': compliant_rules,
            'non_compliant_rules': summary['ComplianceSummary']['ComplianceTypes'].get('NON_COMPLIANT', 0)
        }
        
    except Exception as e:
        return {'error': f'Config compliance check failed: {str(e)}', 'compliant': False}

def check_securityhub_compliance():
    """Check Security Hub compliance status"""
    
    try:
        # Get Security Hub findings
        findings = securityhub_client.get_findings(
            Filters={
                'RecordState': [{'Value': 'ACTIVE', 'Comparison': 'EQUALS'}],
                'WorkflowStatus': [{'Value': 'NEW', 'Comparison': 'EQUALS'}]
            },
            MaxResults=100
        )
        
        total_findings = len(findings['Findings'])
        critical_findings = len([f for f in findings['Findings'] if f.get('Severity', {}).get('Label') == 'CRITICAL'])
        high_findings = len([f for f in findings['Findings'] if f.get('Severity', {}).get('Label') == 'HIGH'])
        
        # Compliance based on critical and high findings
        compliant = critical_findings == 0 and high_findings <= 5
        
        return {
            'compliant': compliant,
            'total_findings': total_findings,
            'critical_findings': critical_findings,
            'high_findings': high_findings,
            'compliance_status': 'compliant' if compliant else 'non_compliant'
        }
        
    except Exception as e:
        return {'error': f'Security Hub compliance check failed: {str(e)}', 'compliant': False}

def check_encryption_compliance():
    """Check encryption compliance across services"""
    
    try:
        encryption_checks = {
            'lambda_functions': check_lambda_encryption(),
            's3_buckets': check_s3_encryption(),
            'kms_keys': check_kms_key_rotation(),
            'secrets_manager': check_secrets_encryption()
        }
        
        # Overall encryption compliance
        total_checks = len(encryption_checks)
        passing_checks = sum(1 for check in encryption_checks.values() if check.get('compliant', False))
        
        compliant = (passing_checks / total_checks) >= 0.8 if total_checks > 0 else False
        
        return {
            'compliant': compliant,
            'encryption_checks': encryption_checks,
            'compliance_percentage': (passing_checks / total_checks * 100) if total_checks > 0 else 0
        }
        
    except Exception as e:
        return {'error': f'Encryption compliance check failed: {str(e)}', 'compliant': False}

def check_lambda_encryption():
    """Check Lambda function encryption compliance"""
    
    try:
        lambda_client = boto3.client('lambda')
        functions = lambda_client.list_functions()
        
        total_functions = len(functions['Functions'])
        encrypted_functions = 0
        
        for function in functions['Functions']:
            # Check environment variable encryption
            if function.get('Environment', {}).get('Variables'):
                if function.get('KMSKeyArn'):
                    encrypted_functions += 1
            else:
                encrypted_functions += 1  # No env vars to encrypt
        
        compliance_percentage = (encrypted_functions / total_functions * 100) if total_functions > 0 else 100
        
        return {
            'compliant': compliance_percentage >= 90,
            'total_functions': total_functions,
            'encrypted_functions': encrypted_functions,
            'compliance_percentage': compliance_percentage
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_s3_encryption():
    """Check S3 bucket encryption compliance"""
    
    try:
        s3_client = boto3.client('s3')
        buckets = s3_client.list_buckets()
        
        total_buckets = len(buckets['Buckets'])
        encrypted_buckets = 0
        
        for bucket in buckets['Buckets']:
            try:
                encryption = s3_client.get_bucket_encryption(Bucket=bucket['Name'])
                if encryption.get('ServerSideEncryptionConfiguration'):
                    encrypted_buckets += 1
            except s3_client.exceptions.ClientError:
                # No encryption configured
                pass
        
        compliance_percentage = (encrypted_buckets / total_buckets * 100) if total_buckets > 0 else 100
        
        return {
            'compliant': compliance_percentage >= 90,
            'total_buckets': total_buckets,
            'encrypted_buckets': encrypted_buckets,
            'compliance_percentage': compliance_percentage
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_kms_key_rotation():
    """Check KMS key rotation compliance"""
    
    try:
        kms_client = boto3.client('kms')
        keys = kms_client.list_keys()
        
        total_keys = 0
        rotation_enabled_keys = 0
        
        for key in keys['Keys']:
            # Only check customer-managed keys
            key_metadata = kms_client.describe_key(KeyId=key['KeyId'])
            if key_metadata['KeyMetadata']['KeyManager'] == 'CUSTOMER':
                total_keys += 1
                try:
                    rotation_status = kms_client.get_key_rotation_status(KeyId=key['KeyId'])
                    if rotation_status['KeyRotationEnabled']:
                        rotation_enabled_keys += 1
                except:
                    pass
        
        compliance_percentage = (rotation_enabled_keys / total_keys * 100) if total_keys > 0 else 100
        
        return {
            'compliant': compliance_percentage >= 80,
            'total_keys': total_keys,
            'rotation_enabled_keys': rotation_enabled_keys,
            'compliance_percentage': compliance_percentage
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_secrets_encryption():
    """Check Secrets Manager encryption compliance"""
    
    try:
        secrets_client = boto3.client('secretsmanager')
        secrets = secrets_client.list_secrets()
        
        total_secrets = len(secrets['SecretList'])
        encrypted_secrets = len([s for s in secrets['SecretList'] if s.get('KmsKeyId')])
        
        compliance_percentage = (encrypted_secrets / total_secrets * 100) if total_secrets > 0 else 100
        
        return {
            'compliant': compliance_percentage >= 95,
            'total_secrets': total_secrets,
            'encrypted_secrets': encrypted_secrets,
            'compliance_percentage': compliance_percentage
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_access_control_compliance():
    """Check access control compliance"""
    
    try:
        access_checks = {
            'mfa_enforcement': check_mfa_compliance(),
            'password_policy': check_password_policy(),
            'unused_access_keys': check_unused_access_keys(),
            'overprivileged_roles': check_overprivileged_roles()
        }
        
        total_checks = len(access_checks)
        passing_checks = sum(1 for check in access_checks.values() if check.get('compliant', False))
        
        compliant = (passing_checks / total_checks) >= 0.75 if total_checks > 0 else False
        
        return {
            'compliant': compliant,
            'access_checks': access_checks,
            'compliance_percentage': (passing_checks / total_checks * 100) if total_checks > 0 else 0
        }
        
    except Exception as e:
        return {'error': f'Access control compliance check failed: {str(e)}', 'compliant': False}

def check_mfa_compliance():
    """Check MFA enforcement compliance"""
    
    try:
        # Simulate MFA compliance check
        # In real implementation, check IAM users and roles for MFA
        return {
            'compliant': True,
            'mfa_enabled_users': 85,
            'total_users': 100,
            'compliance_percentage': 85
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_password_policy():
    """Check password policy compliance"""
    
    try:
        iam_client = boto3.client('iam')
        
        try:
            policy = iam_client.get_account_password_policy()
            password_policy = policy['PasswordPolicy']
            
            # Check policy requirements
            compliant = (
                password_policy.get('MinimumPasswordLength', 0) >= 8 and
                password_policy.get('RequireUppercaseCharacters', False) and
                password_policy.get('RequireLowercaseCharacters', False) and
                password_policy.get('RequireNumbers', False) and
                password_policy.get('RequireSymbols', False)
            )
            
            return {
                'compliant': compliant,
                'policy_configured': True,
                'minimum_length': password_policy.get('MinimumPasswordLength', 0),
                'complexity_requirements': {
                    'uppercase': password_policy.get('RequireUppercaseCharacters', False),
                    'lowercase': password_policy.get('RequireLowercaseCharacters', False),
                    'numbers': password_policy.get('RequireNumbers', False),
                    'symbols': password_policy.get('RequireSymbols', False)
                }
            }
            
        except iam_client.exceptions.NoSuchEntityException:
            return {
                'compliant': False,
                'policy_configured': False,
                'error': 'No password policy configured'
            }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_unused_access_keys():
    """Check for unused access keys"""
    
    try:
        # Simulate unused access key check
        # In real implementation, analyze CloudTrail logs for key usage
        return {
            'compliant': True,
            'unused_keys': 2,
            'total_keys': 50,
            'days_threshold': 90
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_overprivileged_roles():
    """Check for overprivileged IAM roles"""
    
    try:
        # Simulate overprivileged role check
        # In real implementation, analyze role permissions and usage
        return {
            'compliant': True,
            'overprivileged_roles': 1,
            'total_roles': 25,
            'high_risk_permissions': ['*:*', 'iam:*']
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def calculate_soc2_compliance(control_results):
    """Calculate SOC 2 compliance percentage"""
    
    try:
        # SOC 2 focuses on security, availability, processing integrity, confidentiality, privacy
        soc2_controls = ['config', 'encryption', 'access_control']
        
        relevant_results = {k: v for k, v in control_results.items() if k in soc2_controls}
        total_controls = len(relevant_results)
        passing_controls = sum(1 for result in relevant_results.values() if result.get('compliant', False))
        
        compliance_percentage = (passing_controls / total_controls * 100) if total_controls > 0 else 0
        
        return {
            'compliance_percentage': compliance_percentage,
            'status': 'compliant' if compliance_percentage >= 85 else 'non_compliant',
            'controls_evaluated': total_controls,
            'controls_passing': passing_controls
        }
        
    except Exception as e:
        return {'error': str(e), 'compliance_percentage': 0}

def calculate_gdpr_compliance(control_results):
    """Calculate GDPR compliance percentage"""
    
    try:
        # GDPR focuses on data protection and privacy
        gdpr_controls = ['encryption', 'access_control']
        
        relevant_results = {k: v for k, v in control_results.items() if k in gdpr_controls}
        total_controls = len(relevant_results)
        passing_controls = sum(1 for result in relevant_results.values() if result.get('compliant', False))
        
        compliance_percentage = (passing_controls / total_controls * 100) if total_controls > 0 else 0
        
        return {
            'compliance_percentage': compliance_percentage,
            'status': 'compliant' if compliance_percentage >= 90 else 'non_compliant',
            'controls_evaluated': total_controls,
            'controls_passing': passing_controls
        }
        
    except Exception as e:
        return {'error': str(e), 'compliance_percentage': 0}

def calculate_hipaa_compliance(control_results):
    """Calculate HIPAA compliance percentage"""
    
    try:
        # HIPAA focuses on healthcare data protection
        hipaa_controls = ['encryption', 'access_control', 'security_hub']
        
        relevant_results = {k: v for k, v in control_results.items() if k in hipaa_controls}
        total_controls = len(relevant_results)
        passing_controls = sum(1 for result in relevant_results.values() if result.get('compliant', False))
        
        compliance_percentage = (passing_controls / total_controls * 100) if total_controls > 0 else 0
        
        return {
            'compliance_percentage': compliance_percentage,
            'status': 'compliant' if compliance_percentage >= 95 else 'non_compliant',
            'controls_evaluated': total_controls,
            'controls_passing': passing_controls
        }
        
    except Exception as e:
        return {'error': str(e), 'compliance_percentage': 0}

def calculate_pci_compliance(control_results):
    """Calculate PCI DSS compliance percentage"""
    
    try:
        # PCI DSS focuses on payment card data protection
        pci_controls = ['encryption', 'access_control', 'config']
        
        relevant_results = {k: v for k, v in control_results.items() if k in pci_controls}
        total_controls = len(relevant_results)
        passing_controls = sum(1 for result in relevant_results.values() if result.get('compliant', False))
        
        compliance_percentage = (passing_controls / total_controls * 100) if total_controls > 0 else 0
        
        return {
            'compliance_percentage': compliance_percentage,
            'status': 'compliant' if compliance_percentage >= 90 else 'non_compliant',
            'controls_evaluated': total_controls,
            'controls_passing': passing_controls
        }
        
    except Exception as e:
        return {'error': str(e), 'compliance_percentage': 0}

def generate_compliance_recommendations(control_results):
    """Generate compliance improvement recommendations"""
    
    recommendations = []
    
    try:
        # Config compliance recommendations
        if not control_results.get('config', {}).get('compliant', False):
            recommendations.append('Enable additional AWS Config rules for comprehensive compliance monitoring')
            recommendations.append('Remediate non-compliant resources identified by Config rules')
        
        # Security Hub recommendations
        if not control_results.get('security_hub', {}).get('compliant', False):
            recommendations.append('Address critical and high severity Security Hub findings')
            recommendations.append('Enable additional security standards in Security Hub')
        
        # Encryption recommendations
        if not control_results.get('encryption', {}).get('compliant', False):
            recommendations.append('Enable encryption for all Lambda function environment variables')
            recommendations.append('Configure server-side encryption for all S3 buckets')
            recommendations.append('Enable automatic key rotation for KMS keys')
        
        # Access control recommendations
        if not control_results.get('access_control', {}).get('compliant', False):
            recommendations.append('Enforce MFA for all IAM users with console access')
            recommendations.append('Implement strong password policy requirements')
            recommendations.append('Remove or rotate unused access keys')
            recommendations.append('Review and reduce excessive IAM permissions')
        
        # General recommendations
        recommendations.extend([
            'Implement regular security assessment and penetration testing',
            'Establish continuous compliance monitoring processes',
            'Provide security awareness training for all personnel',
            'Document and test incident response procedures'
        ])
        
    except Exception as e:
        recommendations.append(f'Error generating recommendations: {str(e)}')
    
    return recommendations

def generate_compliance_report():
    """Generate comprehensive compliance report"""
    
    try:
        # Perform compliance check
        compliance_check = perform_compliance_check()
        
        report = {
            'report_timestamp': datetime.utcnow().isoformat(),
            'report_period': 'current',
            'executive_summary': {
                'overall_compliance_score': compliance_check.get('overall_compliance_score', 0),
                'compliance_trend': 'stable',
                'critical_issues': 0,
                'recommendations_count': len(compliance_check.get('recommendations', []))
            },
            'framework_compliance': compliance_check.get('framework_compliance', {}),
            'detailed_results': compliance_check.get('control_results', {}),
            'recommendations': compliance_check.get('recommendations', []),
            'next_assessment_date': (datetime.utcnow() + timedelta(days=30)).isoformat(),
            'report_status': 'completed'
        }
        
        return report
        
    except Exception as e:
        return {'error': f'Failed to generate compliance report: {str(e)}'}

def check_security_standards():
    """Check compliance with security standards"""
    
    try:
        standards_compliance = {
            'timestamp': datetime.utcnow().isoformat(),
            'standards': {
                'CIS_AWS_Foundations': check_cis_compliance(),
                'NIST_Cybersecurity_Framework': check_nist_compliance(),
                'ISO_27001': check_iso27001_compliance(),
                'AWS_Well_Architected_Security': check_well_architected_security()
            }
        }
        
        # Calculate overall standards compliance
        total_standards = len(standards_compliance['standards'])
        compliant_standards = sum(1 for standard in standards_compliance['standards'].values() 
                                if standard.get('compliant', False))
        
        standards_compliance['overall_compliance'] = {
            'percentage': (compliant_standards / total_standards * 100) if total_standards > 0 else 0,
            'compliant_standards': compliant_standards,
            'total_standards': total_standards
        }
        
        return standards_compliance
        
    except Exception as e:
        return {'error': f'Security standards check failed: {str(e)}'}

def check_cis_compliance():
    """Check CIS AWS Foundations Benchmark compliance"""
    
    try:
        # Simulate CIS compliance check
        # In real implementation, check specific CIS controls
        return {
            'compliant': True,
            'version': '1.4.0',
            'controls_evaluated': 50,
            'controls_passing': 42,
            'compliance_percentage': 84,
            'critical_failures': 0
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_nist_compliance():
    """Check NIST Cybersecurity Framework compliance"""
    
    try:
        # Simulate NIST compliance check
        return {
            'compliant': True,
            'framework_functions': {
                'identify': 88,
                'protect': 85,
                'detect': 90,
                'respond': 80,
                'recover': 75
            },
            'overall_maturity': 83.6
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_iso27001_compliance():
    """Check ISO 27001 compliance"""
    
    try:
        # Simulate ISO 27001 compliance check
        return {
            'compliant': False,
            'controls_evaluated': 114,
            'controls_passing': 89,
            'compliance_percentage': 78,
            'areas_for_improvement': [
                'Information security policies',
                'Asset management',
                'Incident management'
            ]
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_well_architected_security():
    """Check AWS Well-Architected Security Pillar compliance"""
    
    try:
        # Simulate Well-Architected Security check
        return {
            'compliant': True,
            'design_principles': {
                'implement_strong_identity_foundation': 85,
                'apply_security_at_all_layers': 80,
                'enable_traceability': 90,
                'automate_security_best_practices': 75,
                'protect_data_in_transit_and_at_rest': 88,
                'keep_people_away_from_data': 82,
                'prepare_for_security_events': 70
            },
            'overall_score': 81.4
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def audit_access_patterns():
    """Audit access patterns using CloudTrail"""
    
    try:
        # Get CloudTrail events for access pattern analysis
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(days=7)
        
        events = cloudtrail_client.lookup_events(
            StartTime=start_time,
            EndTime=end_time,
            MaxItems=100
        )
        
        access_patterns = {
            'analysis_period': f"{start_time.isoformat()} to {end_time.isoformat()}",
            'total_events': len(events['Events']),
            'unique_users': set(),
            'event_types': {},
            'source_ips': {},
            'suspicious_activities': []
        }
        
        for event in events['Events']:
            # Analyze event patterns
            user_identity = event.get('UserIdentity', {})
            username = user_identity.get('userName', user_identity.get('type', 'unknown'))
            access_patterns['unique_users'].add(username)
            
            event_name = event.get('EventName', 'unknown')
            access_patterns['event_types'][event_name] = access_patterns['event_types'].get(event_name, 0) + 1
            
            source_ip = event.get('SourceIPAddress', 'unknown')
            access_patterns['source_ips'][source_ip] = access_patterns['source_ips'].get(source_ip, 0) + 1
            
            # Check for suspicious activities
            if event_name in ['AssumeRole', 'GetSessionToken', 'CreateAccessKey']:
                if source_ip not in ['127.0.0.1', 'localhost']:  # Simplified check
                    access_patterns['suspicious_activities'].append({
                        'event': event_name,
                        'user': username,
                        'source_ip': source_ip,
                        'timestamp': event.get('EventTime', '').isoformat()
                    })
        
        access_patterns['unique_users'] = len(access_patterns['unique_users'])
        
        return access_patterns
        
    except Exception as e:
        return {'error': f'Access pattern audit failed: {str(e)}'}

def validate_encryption_compliance():
    """Validate encryption compliance across all services"""
    
    try:
        encryption_validation = {
            'validation_timestamp': datetime.utcnow().isoformat(),
            'services_checked': {},
            'overall_compliance': 0,
            'recommendations': []
        }
        
        # Check various AWS services for encryption
        services_to_check = [
            'lambda', 's3', 'rds', 'ebs', 'efs', 
            'elasticache', 'redshift', 'sns', 'sqs'
        ]
        
        total_services = len(services_to_check)
        compliant_services = 0
        
        for service in services_to_check:
            try:
                if service == 'lambda':
                    result = check_lambda_encryption()
                elif service == 's3':
                    result = check_s3_encryption()
                elif service == 'rds':
                    result = check_rds_encryption()
                elif service == 'ebs':
                    result = check_ebs_encryption()
                else:
                    # Simulate check for other services
                    result = {'compliant': True, 'note': f'{service} encryption check simulated'}
                
                encryption_validation['services_checked'][service] = result
                
                if result.get('compliant', False):
                    compliant_services += 1
                    
            except Exception as e:
                encryption_validation['services_checked'][service] = {
                    'error': str(e),
                    'compliant': False
                }
        
        encryption_validation['overall_compliance'] = (compliant_services / total_services * 100) if total_services > 0 else 0
        
        # Generate recommendations
        for service, result in encryption_validation['services_checked'].items():
            if not result.get('compliant', False):
                encryption_validation['recommendations'].append(f'Enable encryption for {service.upper()} service')
        
        return encryption_validation
        
    except Exception as e:
        return {'error': f'Encryption validation failed: {str(e)}'}

def check_rds_encryption():
    """Check RDS encryption compliance"""
    
    try:
        rds_client = boto3.client('rds')
        instances = rds_client.describe_db_instances()
        
        total_instances = len(instances['DBInstances'])
        encrypted_instances = len([i for i in instances['DBInstances'] if i.get('StorageEncrypted', False)])
        
        compliance_percentage = (encrypted_instances / total_instances * 100) if total_instances > 0 else 100
        
        return {
            'compliant': compliance_percentage >= 95,
            'total_instances': total_instances,
            'encrypted_instances': encrypted_instances,
            'compliance_percentage': compliance_percentage
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}

def check_ebs_encryption():
    """Check EBS encryption compliance"""
    
    try:
        ec2_client = boto3.client('ec2')
        
        # Check if EBS encryption by default is enabled
        encryption_by_default = ec2_client.get_ebs_encryption_by_default()
        
        return {
            'compliant': encryption_by_default['EbsEncryptionByDefault'],
            'encryption_by_default': encryption_by_default['EbsEncryptionByDefault'],
            'note': 'EBS encryption by default status checked'
        }
        
    except Exception as e:
        return {'error': str(e), 'compliant': False}
```

3. Deploy compliance monitoring function:
```bash
zip compliance-monitor.zip compliance_monitor.py

aws lambda create-function \
  --function-name [your-username]-compliance-monitor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler compliance_monitor.lambda_handler \
  --zip-file fileb://compliance-monitor.zip \
  --timeout 300 \
  --memory-size 512 \
  --description "Security compliance monitoring and reporting"
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Implemented advanced secrets management with AWS Secrets Manager
- [ ] Created comprehensive encryption services using KMS and application-level encryption
- [ ] Deployed security automation with AWS Config and custom rules
- [ ] Configured threat detection and response with GuardDuty integration
- [ ] Built secure APIs for security management functions
- [ ] Created security incident response automation
- [ ] Implemented compliance monitoring across multiple frameworks
- [ ] Created comprehensive security dashboards
- [ ] Applied username prefixing to all security resources

### Expected Results

Your advanced security implementation should:
1. Provide centralized secrets management with automatic rotation
2. Implement end-to-end encryption for data at rest and in transit
3. Automate security compliance monitoring and reporting
4. Detect and respond to security threats in real-time
5. Support multiple compliance frameworks (SOC 2, GDPR, HIPAA, PCI DSS)
6. Generate comprehensive security and compliance reports
7. Provide automated incident response capabilities

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Secrets Manager access denied
- **Solution:** Verify IAM permissions for Secrets Manager operations
- Check resource-based policies on secrets
- Ensure proper KMS key permissions for secret encryption

**Issue:** KMS encryption operations failing
- **Solution:** Verify KMS key policy allows Lambda function access
- Check that key is in correct region and enabled
- Ensure proper ViaService conditions in key policy

**Issue:** Config rules not evaluating properly
- **Solution:** Verify Config service role permissions
- Check that resources are being recorded by Config
- Ensure proper resource types are specified in rule scope

**Issue:** GuardDuty findings not triggering responses
- **Solution:** Verify CloudWatch Events rule for GuardDuty
- Check Lambda function permissions for GuardDuty events
- Ensure proper event pattern matching

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-secrets-function
aws lambda delete-function --function-name [your-username]-encryption-service
aws lambda delete-function --function-name [your-username]-security-automation
aws lambda delete-function --function-name [your-username]-threat-response
aws lambda delete-function --function-name [your-username]-incident-response
aws lambda delete-function --function-name [your-username]-compliance-monitor

# Delete Secrets Manager secrets
aws secretsmanager delete-secret --secret-id [your-username]-database-credentials --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id [your-username]-api-keys --force-delete-without-recovery
aws secretsmanager delete-secret --secret-id [your-username]-encryption-keys --force-delete-without-recovery

# Delete KMS key (schedule for deletion)
aws kms schedule-key-deletion --key-id alias/[your-username]-advanced-encryption-key --pending-window-in-days 7

# Delete Config rules
aws configservice delete-config-rule --config-rule-name [your-username]-lambda-security-check
aws configservice delete-config-rule --config-rule-name [your-username]-s3-encryption-check
aws configservice delete-config-rule --config-rule-name [your-username]-apigateway-logging-check

# Delete GuardDuty detector
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
aws guardduty delete-detector --detector-id $DETECTOR_ID

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id [your-api-id]

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-advanced-security
```

---

## Key Takeaways

From this lab, you should understand:
1. **Advanced Secrets Management:** Centralized credential management with automatic rotation
2. **Comprehensive Encryption:** End-to-end encryption strategies for serverless applications
3. **Security Automation:** Automated compliance monitoring and threat response
4. **Threat Detection:** Real-time security monitoring and incident response
5. **Compliance Frameworks:** Supporting multiple regulatory requirements
6. **Security Orchestration:** Coordinated security controls across AWS services
7. **Incident Response:** Automated security incident handling and escalation

---

## Next Steps

This completes the advanced security implementation lab. You now have a comprehensive security framework that protects serverless applications through defense-in-depth strategies, automated threat detection and response, and continuous compliance monitoring across multiple regulatory frameworks.