# Developing Serverless Solutions on AWS - Day 2 - Lab 7
## Observability and Monitoring

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will implement comprehensive observability and monitoring for serverless applications using Amazon CloudWatch, AWS X-Ray, and CloudWatch ServiceLens. You'll learn to write effective logs, create custom metrics, set up alarms, trace distributed transactions, and build dashboards for operational insights.

## Lab Objectives

By the end of this lab, you will be able to:
- Implement structured logging with CloudWatch Logs and Logs Insights
- Create custom metrics using CloudWatch Embedded Metrics Format
- Set up CloudWatch alarms for proactive monitoring
- Enable AWS X-Ray tracing for distributed system observability
- Use CloudWatch ServiceLens for end-to-end application monitoring
- Create comprehensive dashboards for operational visibility
- Implement log aggregation and analysis patterns
- Apply username prefixing to monitoring resources

## Prerequisites

- Completion of Labs 1-6
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of observability concepts (logs, metrics, traces)

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Monitoring
**IMPORTANT:** All monitoring resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- Log groups: `/aws/lambda/user3-monitored-function`
- CloudWatch dashboards: `user3-serverless-dashboard`
- Alarms: `user3-function-error-alarm`

---

## Task 1: Implement Structured Logging

### Step 1.1: Create Enhanced Logging Function

1. Create directory for enhanced logging function:
```bash
mkdir ~/environment/[your-username]-enhanced-logging
cd ~/environment/[your-username]-enhanced-logging
```

2. Create `enhanced_logging.py`:

```python
import json
import logging
import time
import uuid
import os
from datetime import datetime

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Remove default handler and add custom formatter
for handler in logger.handlers:
    logger.removeHandler(handler)

# Create custom handler with JSON formatter
handler = logging.StreamHandler()
handler.setLevel(logging.INFO)

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'level': record.levelname,
            'message': record.getMessage(),
            'function_name': os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'unknown'),
            'function_version': os.environ.get('AWS_LAMBDA_FUNCTION_VERSION', 'unknown'),
            'request_id': getattr(record, 'request_id', 'unknown'),
            'correlation_id': getattr(record, 'correlation_id', 'unknown')
        }
        
        # Add extra fields if they exist
        if hasattr(record, 'custom_fields'):
            log_entry.update(record.custom_fields)
            
        return json.dumps(log_entry)

handler.setFormatter(JSONFormatter())
logger.addHandler(handler)

def log_with_context(level, message, **kwargs):
    """Helper function to log with additional context"""
    extra = {
        'custom_fields': kwargs
    }
    logger.log(level, message, extra=extra)

def lambda_handler(event, context):
    """
    Function demonstrating enhanced logging practices
    """
    
    # Generate correlation ID for request tracking
    correlation_id = str(uuid.uuid4())
    request_id = context.aws_request_id
    
    # Add request context to all logs
    for handler in logger.handlers:
        handler.setFormatter(JSONFormatter())
    
    # Set context for logging
    logger.info("Function invocation started", extra={
        'custom_fields': {
            'correlation_id': correlation_id,
            'request_id': request_id,
            'event_type': event.get('eventType', 'unknown'),
            'cold_start': not hasattr(lambda_handler, 'initialized')
        }
    })
    
    # Mark function as initialized
    lambda_handler.initialized = True
    
    try:
        # Extract and validate input
        body = event.get('body', '{}')
        if isinstance(body, str):
            body = json.loads(body)
        
        operation = body.get('operation', 'default')
        user_id = body.get('userId', 'anonymous')
        
        log_with_context(
            logging.INFO,
            "Processing request",
            correlation_id=correlation_id,
            operation=operation,
            user_id=user_id,
            input_size=len(json.dumps(body))
        )
        
        # Simulate different operations with varying performance
        start_time = time.time()
        
        if operation == 'database_query':
            # Simulate database operation
            time.sleep(0.1)
            result = simulate_database_query(user_id, correlation_id)
            
        elif operation == 'external_api_call':
            # Simulate external API call
            result = simulate_external_api_call(user_id, correlation_id)
            
        elif operation == 'heavy_computation':
            # Simulate CPU-intensive operation
            result = simulate_heavy_computation(correlation_id)
            
        elif operation == 'error_simulation':
            # Simulate error for testing
            raise ValueError("Simulated error for testing purposes")
            
        else:
            result = {
                'message': 'Default operation completed',
                'user_id': user_id,
                'timestamp': datetime.utcnow().isoformat()
            }
        
        processing_time = time.time() - start_time
        
        log_with_context(
            logging.INFO,
            "Request processed successfully",
            correlation_id=correlation_id,
            operation=operation,
            processing_time_ms=round(processing_time * 1000, 2),
            result_size=len(json.dumps(result))
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            },
            'body': json.dumps({
                'result': result,
                'metadata': {
                    'correlation_id': correlation_id,
                    'processing_time_ms': round(processing_time * 1000, 2),
                    'function_version': context.function_version
                }
            })
        }
        
    except Exception as e:
        log_with_context(
            logging.ERROR,
            "Request processing failed",
            correlation_id=correlation_id,
            error_type=type(e).__name__,
            error_message=str(e),
            operation=operation if 'operation' in locals() else 'unknown'
        )
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'correlation_id': correlation_id
            })
        }

def simulate_database_query(user_id, correlation_id):
    """Simulate database query with logging"""
    
    log_with_context(
        logging.INFO,
        "Starting database query",
        correlation_id=correlation_id,
        user_id=user_id,
        query_type="user_profile"
    )
    
    # Simulate query time
    time.sleep(0.05)
    
    result = {
        'user_id': user_id,
        'profile': {
            'name': f'User {user_id}',
            'created_at': '2023-01-01',
            'preferences': ['feature1', 'feature2']
        }
    }
    
    log_with_context(
        logging.INFO,
        "Database query completed",
        correlation_id=correlation_id,
        user_id=user_id,
        records_returned=1
    )
    
    return result

def simulate_external_api_call(user_id, correlation_id):
    """Simulate external API call with logging"""
    
    import random
    
    log_with_context(
        logging.INFO,
        "Making external API call",
        correlation_id=correlation_id,
        user_id=user_id,
        api_endpoint="https://api.example.com/data"
    )
    
    # Simulate API call time and potential failure
    time.sleep(random.uniform(0.1, 0.3))
    
    if random.random() < 0.1:  # 10% chance of API failure
        log_with_context(
            logging.WARNING,
            "External API call failed, using fallback",
            correlation_id=correlation_id,
            user_id=user_id,
            fallback_used=True
        )
        
        return {
            'data': 'fallback_data',
            'source': 'cache',
            'user_id': user_id
        }
    
    result = {
        'data': f'external_data_for_{user_id}',
        'source': 'api',
        'user_id': user_id
    }
    
    log_with_context(
        logging.INFO,
        "External API call successful",
        correlation_id=correlation_id,
        user_id=user_id,
        response_size=len(json.dumps(result))
    )
    
    return result

def simulate_heavy_computation(correlation_id):
    """Simulate CPU-intensive operation with logging"""
    
    log_with_context(
        logging.INFO,
        "Starting heavy computation",
        correlation_id=correlation_id,
        computation_type="fibonacci"
    )
    
    start_time = time.time()
    
    # Calculate fibonacci number (CPU intensive)
    n = 35
    result_value = fibonacci(n)
    
    computation_time = time.time() - start_time
    
    log_with_context(
        logging.INFO,
        "Heavy computation completed",
        correlation_id=correlation_id,
        computation_time_ms=round(computation_time * 1000, 2),
        input_value=n,
        result_value=result_value
    )
    
    return {
        'computation': 'fibonacci',
        'input': n,
        'result': result_value,
        'computation_time_ms': round(computation_time * 1000, 2)
    }

def fibonacci(n):
    """Calculate fibonacci number (recursive for CPU load)"""
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

3. Deploy enhanced logging function:
```bash
zip enhanced-logging.zip enhanced_logging.py

aws lambda create-function \
  --function-name [your-username]-enhanced-logging \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler enhanced_logging.lambda_handler \
  --zip-file fileb://enhanced-logging.zip \
  --timeout 60 \
  --memory-size 256 \
  --description "Function demonstrating enhanced logging practices"
```

---

## Task 2: Implement Custom Metrics with EMF

### Step 2.1: Create Metrics Publishing Function

1. Create directory for metrics function:
```bash
mkdir ~/environment/[your-username]-custom-metrics
cd ~/environment/[your-username]-custom-metrics
```

2. Create `custom_metrics.py`:

```python
import json
import time
import random
from datetime import datetime

def put_metric(metric_name, value, unit='Count', dimensions=None, namespace='ServerlessApp'):
    """
    Publish custom metric using CloudWatch Embedded Metrics Format
    """
    if dimensions is None:
        dimensions = {}
    
    # Create EMF log entry
    emf_log = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": namespace,
                    "Dimensions": [list(dimensions.keys())] if dimensions else [[]],
                    "Metrics": [
                        {
                            "Name": metric_name,
                            "Unit": unit
                        }
                    ]
                }
            ]
        }
    }
    
    # Add dimension values
    emf_log.update(dimensions)
    
    # Add metric value
    emf_log[metric_name] = value
    
    # Print to CloudWatch Logs (EMF format)
    print(json.dumps(emf_log))

def lambda_handler(event, context):
    """
    Function demonstrating custom metrics publishing
    """
    
    start_time = time.time()
    
    try:
        # Extract request information
        body = event.get('body', '{}')
        if isinstance(body, str):
            body = json.loads(body)
        
        operation = body.get('operation', 'default')
        user_type = body.get('userType', 'standard')
        region = body.get('region', 'us-east-1')
        
        # Common dimensions for all metrics
        dimensions = {
            'FunctionName': context.function_name,
            'Operation': operation,
            'UserType': user_type,
            'Region': region
        }
        
        # Publish invocation metric
        put_metric('FunctionInvocations', 1, 'Count', dimensions)
        
        # Simulate business logic and publish business metrics
        if operation == 'create_order':
            order_value = body.get('orderValue', random.uniform(10, 1000))
            
            # Business metrics
            put_metric('OrdersCreated', 1, 'Count', dimensions)
            put_metric('OrderValue', order_value, 'None', dimensions)
            
            # Simulate processing time based on order complexity
            processing_time = random.uniform(0.1, 0.5)
            time.sleep(processing_time)
            
            # Performance metrics
            put_metric('OrderProcessingTime', processing_time * 1000, 'Milliseconds', dimensions)
            
            result = {
                'order_id': f'order-{int(time.time())}',
                'status': 'created',
                'value': order_value
            }
            
        elif operation == 'user_login':
            # Simulate login success/failure
            login_success = random.random() > 0.05  # 95% success rate
            
            if login_success:
                put_metric('LoginSuccess', 1, 'Count', dimensions)
                result = {'status': 'logged_in', 'user_id': body.get('userId', 'user123')}
            else:
                put_metric('LoginFailure', 1, 'Count', dimensions)
                raise Exception("Authentication failed")
                
        elif operation == 'data_processing':
            # Simulate data processing with varying load
            records_processed = body.get('recordCount', random.randint(10, 1000))
            
            processing_time = records_processed * 0.001  # 1ms per record
            time.sleep(processing_time)
            
            # Data processing metrics
            put_metric('RecordsProcessed', records_processed, 'Count', dimensions)
            put_metric('ProcessingRate', records_processed / processing_time, 'Count/Second', dimensions)
            
            result = {
                'records_processed': records_processed,
                'processing_time_ms': processing_time * 1000
            }
            
        else:
            result = {'message': 'Default operation completed'}
        
        # Calculate and publish execution time
        execution_time = (time.time() - start_time) * 1000
        put_metric('ExecutionTime', execution_time, 'Milliseconds', dimensions)
        
        # Publish success metric
        put_metric('FunctionSuccess', 1, 'Count', dimensions)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'result': result,
                'metrics': {
                    'execution_time_ms': execution_time,
                    'operation': operation
                }
            })
        }
        
    except Exception as e:
        # Publish error metrics
        error_dimensions = dimensions.copy()
        error_dimensions['ErrorType'] = type(e).__name__
        
        put_metric('FunctionErrors', 1, 'Count', error_dimensions)
        
        execution_time = (time.time() - start_time) * 1000
        put_metric('ExecutionTime', execution_time, 'Milliseconds', dimensions)
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': str(e),
                'execution_time_ms': execution_time
            })
        }
```

3. Deploy custom metrics function:
```bash
zip custom-metrics.zip custom_metrics.py

aws lambda create-function \
  --function-name [your-username]-custom-metrics \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler custom_metrics.lambda_handler \
  --zip-file fileb://custom-metrics.zip \
  --timeout 60 \
  --memory-size 256 \
  --description "Function demonstrating custom metrics with EMF"
```

---

## Task 3: Enable X-Ray Tracing

### Step 3.1: Create X-Ray Enabled Function

1. Create directory for X-Ray function:
```bash
mkdir ~/environment/[your-username]-xray-tracing
cd ~/environment/[your-username]-xray-tracing
```

2. Create `xray_tracing.py`:

```python
import json
import time
import boto3
import requests
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

# Patch all AWS SDK calls and HTTP requests
patch_all()

# Initialize AWS clients (will be automatically traced)
dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')

@xray_recorder.capture('lambda_handler')
def lambda_handler(event, context):
    """
    Function demonstrating X-Ray tracing capabilities
    """
    
    # Add metadata to trace
    xray_recorder.put_metadata('function_info', {
        'function_name': context.function_name,
        'function_version': context.function_version,
        'memory_limit': context.memory_limit_in_mb,
        'request_id': context.aws_request_id
    })
    
    try:
        # Extract request information
        body = event.get('body', '{}')
        if isinstance(body, str):
            body = json.loads(body)
        
        operation = body.get('operation', 'default')
        user_id = body.get('userId', 'user123')
        
        # Add annotations (indexed for filtering)
        xray_recorder.put_annotation('operation', operation)
        xray_recorder.put_annotation('user_id', user_id)
        
        result = None
        
        if operation == 'database_operation':
            result = perform_database_operation(user_id)
        elif operation == 'external_api_call':
            result = perform_external_api_call(user_id)
        elif operation == 'multi_service_call':
            result = perform_multi_service_call(user_id)
        else:
            result = perform_default_operation(user_id)
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'result': result,
                'trace_id': xray_recorder.current_trace_id
            })
        }
        
    except Exception as e:
        # Add error information to trace
        xray_recorder.put_metadata('error_info', {
            'error_type': type(e).__name__,
            'error_message': str(e)
        })
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': str(e),
                'trace_id': xray_recorder.current_trace_id
            })
        }

@xray_recorder.capture('database_operation')
def perform_database_operation(user_id):
    """Simulate database operation with tracing"""
    
    # Add subsegment metadata
    xray_recorder.put_metadata('database_query', {
        'table_name': 'users',
        'query_type': 'get_item',
        'user_id': user_id
    })
    
    # Simulate database call
    time.sleep(0.1)
    
    # In a real scenario, this would be an actual DynamoDB call
    # table = dynamodb.Table('users')
    # response = table.get_item(Key={'user_id': user_id})
    
    result = {
        'user_id': user_id,
        'name': f'User {user_id}',
        'last_login': '2024-01-15T10:30:00Z'
    }
    
    xray_recorder.put_metadata('database_result', {
        'items_returned': 1,
        'response_size': len(json.dumps(result))
    })
    
    return result

@xray_recorder.capture('external_api_call')
def perform_external_api_call(user_id):
    """Simulate external API call with tracing"""
    
    # Add subsegment annotations
    xray_recorder.put_annotation('api_endpoint', 'jsonplaceholder.typicode.com')
    
    try:
        # Make actual HTTP request (will be automatically traced)
        response = requests.get(
            f'https://jsonplaceholder.typicode.com/users/{user_id}',
            timeout=5
        )
        
        xray_recorder.put_metadata('api_response', {
            'status_code': response.status_code,
            'response_size': len(response.text)
        })
        
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"API call failed with status {response.status_code}")
            
    except requests.exceptions.RequestException as e:
        xray_recorder.put_metadata('api_error', {
            'error_type': type(e).__name__,
            'error_message': str(e)
        })
        
        # Return fallback data
        return {
            'id': user_id,
            'name': f'Fallback User {user_id}',
            'source': 'fallback'
        }

@xray_recorder.capture('multi_service_call')
def perform_multi_service_call(user_id):
    """Perform multiple service calls with tracing"""
    
    results = {}
    
    # First call - database
    with xray_recorder.in_subsegment('get_user_profile'):
        results['profile'] = perform_database_operation(user_id)
    
    # Second call - external API
    with xray_recorder.in_subsegment('get_external_data'):
        results['external_data'] = perform_external_api_call(user_id)
    
    # Third call - S3 operation
    with xray_recorder.in_subsegment('s3_operation'):
        results['s3_info'] = perform_s3_operation(user_id)
    
    return results

@xray_recorder.capture('s3_operation')
def perform_s3_operation(user_id):
    """Simulate S3 operation with tracing"""
    
    # Add metadata for S3 operation
    xray_recorder.put_metadata('s3_operation', {
        'operation_type': 'list_objects',
        'user_id': user_id
    })
    
    # Simulate S3 operation
    time.sleep(0.05)
    
    # In a real scenario, this would be an actual S3 call
    # response = s3.list_objects_v2(Bucket='my-bucket', Prefix=f'users/{user_id}/')
    
    return {
        'bucket': 'example-bucket',
        'prefix': f'users/{user_id}/',
        'object_count': 3
    }

@xray_recorder.capture('default_operation')
def perform_default_operation(user_id):
    """Default operation with tracing"""
    
    time.sleep(0.02)
    
    return {
        'message': 'Default operation completed',
        'user_id': user_id,
        'timestamp': time.time()
    }
```

3. Create requirements.txt for X-Ray dependencies:
```bash
cat > requirements.txt << 'EOF'
aws-xray-sdk==2.12.1
requests==2.28.1
EOF
```

4. Install dependencies and deploy:
```bash
pip install -r requirements.txt -t .
zip -r xray-tracing.zip .

aws lambda create-function \
  --function-name [your-username]-xray-tracing \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler xray_tracing.lambda_handler \
  --zip-file fileb://xray-tracing.zip \
  --timeout 60 \
  --memory-size 256 \
  --description "Function demonstrating X-Ray tracing" \
  --tracing-config Mode=Active
```

---

## Task 4: Create CloudWatch Dashboards

### Step 4.1: Create Comprehensive Dashboard

1. Create dashboard configuration:
```bash
cat > monitoring-dashboard.json << 'EOF'
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
                    [ "AWS/Lambda", "Invocations", "FunctionName", "[your-username]-enhanced-logging" ],
                    [ ".", ".", ".", "[your-username]-custom-metrics" ],
                    [ ".", ".", ".", "[your-username]-xray-tracing" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Lambda Invocations"
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
                    [ "AWS/Lambda", "Errors", "FunctionName", "[your-username]-enhanced-logging" ],
                    [ ".", ".", ".", "[your-username]-custom-metrics" ],
                    [ ".", ".", ".", "[your-username]-xray-tracing" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Lambda Errors"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Duration", "FunctionName", "[your-username]-enhanced-logging" ],
                    [ ".", ".", ".", "[your-username]-custom-metrics" ],
                    [ ".", ".", ".", "[your-username]-xray-tracing" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Average Duration"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "ServerlessApp", "FunctionInvocations", "FunctionName", "[your-username]-custom-metrics" ],
                    [ ".", "OrdersCreated", ".", "." ],
                    [ ".", "LoginSuccess", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Custom Business Metrics"
            }
        },
        {
            "type": "log",
            "x": 0,
            "y": 12,
            "width": 24,
            "height": 6,
            "properties": {
                "query": "SOURCE '/aws/lambda/[your-username]-enhanced-logging'\n| fields @timestamp, level, message, correlation_id, operation\n| filter level = \"ERROR\"\n| sort @timestamp desc\n| limit 100",
                "region": "us-east-1",
                "title": "Recent Errors",
                "view": "table"
            }
        }
    ]
}
EOF

sed -i "s/\[your-username\]/[your-username]/g" monitoring-dashboard.json

aws cloudwatch put-dashboard \
  --dashboard-name "[your-username]-serverless-monitoring" \
  --dashboard-body file://monitoring-dashboard.json
```

---

## Task 5: Set Up CloudWatch Alarms

### Step 5.1: Create Function Error Alarms

1. Create error rate alarm:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "[your-username]-lambda-error-rate" \
  --alarm-description "Alert when Lambda error rate exceeds threshold" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:[ACCOUNT-ID]:[your-username]-alerts \
  --dimensions Name=FunctionName,Value=[your-username]-enhanced-logging
```

2. Create duration alarm:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "[your-username]-lambda-duration" \
  --alarm-description "Alert when Lambda duration exceeds threshold" \
  --metric-name Duration \
  --namespace AWS/Lambda \
  --statistic Average \
  --period 300 \
  --threshold 10000 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=FunctionName,Value=[your-username]-enhanced-logging
```

3. Create custom business metric alarm:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "[your-username]-login-failure-rate" \
  --alarm-description "Alert when login failure rate is high" \
  --metric-name LoginFailure \
  --namespace ServerlessApp \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=FunctionName,Value=[your-username]-custom-metrics
```

---

## Task 6: Test and Generate Data

### Step 6.1: Create API Gateways for Testing

1. Create API Gateway for enhanced logging function:
```bash
aws apigateway create-rest-api \
  --name "[your-username]-monitoring-api" \
  --description "API for testing monitoring functions"

# Follow previous lab patterns to create resources and methods
# Create /logs resource and integrate with [your-username]-enhanced-logging
# Create /metrics resource and integrate with [your-username]-custom-metrics  
# Create /tracing resource and integrate with [your-username]-xray-tracing
```

### Step 6.2: Generate Test Data

1. Create test script:
```bash
cat > generate_test_data.sh << 'EOF'
#!/bin/bash

API_BASE="https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod"

echo "Generating test data for monitoring..."

# Test enhanced logging
echo "Testing enhanced logging..."
for i in {1..10}; do
    OPERATION=$(shuf -n1 -e "database_query" "external_api_call" "heavy_computation" "error_simulation")
    USER_ID="user$(($RANDOM % 100))"
    
    curl -X POST "$API_BASE/logs" \
      -H "Content-Type: application/json" \
      -d "{\"operation\": \"$OPERATION\", \"userId\": \"$USER_ID\"}" \
      -w "Status: %{http_code}\n" -s -o /dev/null
    
    sleep 0.5
done

# Test custom metrics
echo "Testing custom metrics..."
for i in {1..15}; do
    OPERATION=$(shuf -n1 -e "create_order" "user_login" "data_processing")
    USER_TYPE=$(shuf -n1 -e "standard" "premium" "enterprise")
    
    if [ "$OPERATION" = "create_order" ]; then
        ORDER_VALUE=$((RANDOM % 900 + 100))
        PAYLOAD="{\"operation\": \"$OPERATION\", \"userType\": \"$USER_TYPE\", \"orderValue\": $ORDER_VALUE}"
    elif [ "$OPERATION" = "data_processing" ]; then
        RECORD_COUNT=$((RANDOM % 1000 + 100))
        PAYLOAD="{\"operation\": \"$OPERATION\", \"userType\": \"$USER_TYPE\", \"recordCount\": $RECORD_COUNT}"
    else
        PAYLOAD="{\"operation\": \"$OPERATION\", \"userType\": \"$USER_TYPE\", \"userId\": \"user$((RANDOM % 100))\"}"
    fi
    
    curl -X POST "$API_BASE/metrics" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      -w "Status: %{http_code}\n" -s -o /dev/null
    
    sleep 0.3
done

# Test X-Ray tracing
echo "Testing X-Ray tracing..."
for i in {1..8}; do
    OPERATION=$(shuf -n1 -e "database_operation" "external_api_call" "multi_service_call")
    USER_ID=$((RANDOM % 10 + 1))
    
    curl -X POST "$API_BASE/tracing" \
      -H "Content-Type: application/json" \
      -d "{\"operation\": \"$OPERATION\", \"userId\": \"$USER_ID\"}" \
      -w "Status: %{http_code}\n" -s -o /dev/null
    
    sleep 1
done

echo "Test data generation completed!"
EOF

chmod +x generate_test_data.sh
```

2. Run the test script:
```bash
./generate_test_data.sh
```

---

## Task 7: Analyze Logs with CloudWatch Logs Insights

### Step 7.1: Create Log Analysis Queries

1. Query for error analysis:
```bash
aws logs start-query \
  --log-group-name "/aws/lambda/[your-username]-enhanced-logging" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, level, message, correlation_id, operation, error_type
| filter level = "ERROR"
| stats count() by operation, error_type
| sort count desc'
```

2. Query for performance analysis:
```bash
aws logs start-query \
  --log-group-name "/aws/lambda/[your-username]-enhanced-logging" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, correlation_id, operation, processing_time_ms
| filter ispresent(processing_time_ms)
| stats avg(processing_time_ms), max(processing_time_ms), min(processing_time_ms) by operation'
```

3. Query for correlation tracking:
```bash
aws logs start-query \
  --log-group-name "/aws/lambda/[your-username]-enhanced-logging" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, message, correlation_id, operation
| filter correlation_id = "YOUR_CORRELATION_ID_HERE"
| sort @timestamp asc'
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created Lambda function with structured JSON logging
- [ ] Implemented custom metrics using CloudWatch EMF
- [ ] Enabled X-Ray tracing with annotations and metadata
- [ ] Created comprehensive CloudWatch dashboard
- [ ] Set up CloudWatch alarms for monitoring
- [ ] Generated test data across all monitoring functions
- [ ] Analyzed logs using CloudWatch Logs Insights
- [ ] Applied username prefixing to all monitoring resources

### Expected Results

Your monitoring setup should provide:
1. Structured, searchable logs with correlation IDs
2. Custom business metrics visible in CloudWatch
3. Distributed traces showing service interactions
4. Operational dashboards with key metrics
5. Proactive alerting on errors and performance issues
6. Log analysis capabilities for troubleshooting

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** X-Ray traces not appearing
- **Solution:** Verify X-Ray tracing is enabled on Lambda function
- Check IAM permissions for X-Ray service
- Ensure X-Ray SDK is properly configured

**Issue:** Custom metrics not showing in CloudWatch
- **Solution:** Verify EMF format is correct
- Check that metrics are being printed to CloudWatch Logs
- Wait 5-15 minutes for metrics to appear

**Issue:** Logs Insights queries returning no results
- **Solution:** Verify log group name is correct
- Check time range for query
- Ensure logs are being generated

**Issue:** Alarms not triggering
- **Solution:** Verify alarm thresholds are appropriate
- Check alarm configuration and metric dimensions
- Generate test data to trigger alarm conditions

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-enhanced-logging
aws lambda delete-function --function-name [your-username]-custom-metrics
aws lambda delete-function --function-name [your-username]-xray-tracing

# Delete CloudWatch alarms
aws cloudwatch delete-alarms --alarm-names [your-username]-lambda-error-rate [your-username]-lambda-duration [your-username]-login-failure-rate

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-serverless-monitoring

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id [your-api-id]
```

---

## Key Takeaways

From this lab, you should understand:
1. **Structured Logging:** How to implement searchable, contextual logging
2. **Custom Metrics:** Using EMF to publish business and operational metrics
3. **Distributed Tracing:** X-Ray for understanding service interactions
4. **Dashboards:** Creating operational visibility with CloudWatch
5. **Alerting:** Proactive monitoring with CloudWatch alarms
6. **Log Analysis:** Using Logs Insights for troubleshooting and analysis

---

## Next Steps

In the next lab, you will explore security best practices for serverless applications, building on the monitoring and observability foundation you've established.