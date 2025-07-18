# Developing Serverless Solutions on AWS - Day 2 - Lab 5
## Lambda Function Optimization

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will optimize Lambda functions by implementing best practices for performance, reliability, and cost efficiency. You'll explore function configuration, error handling strategies, layers, versions and aliases, environment reuse, and concurrency management to build production-ready serverless applications.

## Lab Objectives

By the end of this lab, you will be able to:
- Implement Lambda function best practices for performance optimization
- Configure Lambda layers for code reuse and dependency management
- Use versions and aliases for deployment management
- Implement comprehensive error handling and retry strategies
- Configure concurrency and memory settings for optimal performance
- Apply environment reuse patterns and connection pooling
- Monitor function performance and troubleshoot issues
- Apply username prefixing to Lambda optimization resources

## Prerequisites

- Completion of Labs 1-4
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of Lambda lifecycle and execution model

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Lambda Resources
**IMPORTANT:** All Lambda optimization resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- Lambda functions: `user3-optimized-function`
- Lambda layers: `user3-shared-dependencies`
- Aliases: `user3-prod-alias`

---

## Task 1: Create Baseline Lambda Function

### Step 1.1: Create Unoptimized Function

1. Create directory for baseline function:
```bash
mkdir ~/environment/[your-username]-baseline-function
cd ~/environment/[your-username]-baseline-function
```

2. Create `baseline_function.py`:

```python
import json
import time
import requests
import boto3
from datetime import datetime

def lambda_handler(event, context):
    """
    Baseline function demonstrating common performance issues
    """
    
    # Poor practice: Creating clients inside handler
    dynamodb = boto3.resource('dynamodb')
    s3 = boto3.client('s3')
    
    # Poor practice: No connection reuse
    response = requests.get('https://api.github.com/repos/aws/aws-sdk-python')
    
    # Simulate processing
    start_time = time.time()
    
    # Extract request data
    body = json.loads(event.get('body', '{}'))
    operation = body.get('operation', 'default')
    
    # Poor practice: No input validation
    data = {
        'timestamp': datetime.now().isoformat(),
        'operation': operation,
        'github_stars': response.json().get('stargazers_count', 0),
        'processing_start': start_time
    }
    
    # Simulate different operations with varying complexity
    if operation == 'heavy':
        # Simulate CPU-intensive work
        result = sum(i * i for i in range(100000))
        data['calculation_result'] = result
        time.sleep(2)  # Simulate slow operation
    elif operation == 'memory':
        # Simulate memory-intensive work
        large_list = [i for i in range(500000)]
        data['list_length'] = len(large_list)
    else:
        # Default lightweight operation
        data['message'] = 'Default operation completed'
    
    # Poor practice: No error handling
    processing_time = time.time() - start_time
    data['processing_time'] = processing_time
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(data)
    }
```

3. Create requirements.txt:
```bash
cat > requirements.txt << 'EOF'
requests==2.28.1
boto3==1.26.137
EOF
```

4. Install dependencies and create deployment package:
```bash
pip install -r requirements.txt -t .
zip -r baseline-function.zip .
```

5. Deploy baseline function:
```bash
aws lambda create-function \
  --function-name [your-username]-baseline-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler baseline_function.lambda_handler \
  --zip-file fileb://baseline-function.zip \
  --timeout 30 \
  --memory-size 128 \
  --description "Baseline function demonstrating optimization opportunities"
```

### Step 1.2: Test Baseline Performance

1. Test the baseline function:
```bash
aws lambda invoke \
  --function-name [your-username]-baseline-function \
  --payload '{"body": "{\"operation\": \"default\"}"}' \
  baseline-output.json

cat baseline-output.json
```

2. Test with different operations:
```bash
# Test heavy operation
aws lambda invoke \
  --function-name [your-username]-baseline-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  heavy-output.json

# Test memory operation
aws lambda invoke \
  --function-name [your-username]-baseline-function \
  --payload '{"body": "{\"operation\": \"memory\"}"}' \
  memory-output.json
```

3. Note the execution times and duration metrics.

---

## Task 2: Create Lambda Layer for Dependencies

### Step 2.1: Create Shared Dependencies Layer

1. Create directory for layer:
```bash
mkdir ~/environment/[your-username]-lambda-layer
cd ~/environment/[your-username]-lambda-layer
mkdir python
```

2. Install common dependencies in layer:
```bash
pip install requests boto3 -t python/
```

3. Create layer deployment package:
```bash
zip -r [your-username]-dependencies-layer.zip python/
```

4. Create the Lambda layer:
```bash
aws lambda publish-layer-version \
  --layer-name [your-username]-shared-dependencies \
  --description "Shared dependencies for optimized functions" \
  --zip-file fileb://[your-username]-dependencies-layer.zip \
  --compatible-runtimes python3.9
```

5. Note the layer ARN from the response for use in optimized functions.

### Step 2.2: Create Utility Functions Layer

1. Create directory for utilities layer:
```bash
mkdir ~/environment/[your-username]-utils-layer
cd ~/environment/[your-username]-utils-layer
mkdir python
```

2. Create utility functions:
```bash
cat > python/lambda_utils.py << 'EOF'
import json
import time
import logging
from functools import wraps
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def timer(func):
    """Decorator to time function execution"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        result = func(*args, **kwargs)
        end_time = time.time()
        logger.info(f"{func.__name__} executed in {end_time - start_time:.4f} seconds")
        return result
    return wrapper

def validate_input(event, required_fields=None):
    """Validate input event structure"""
    if required_fields is None:
        required_fields = []
    
    try:
        body = json.loads(event.get('body', '{}'))
        missing_fields = [field for field in required_fields if field not in body]
        
        if missing_fields:
            raise ValueError(f"Missing required fields: {missing_fields}")
        
        return body
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in request body: {str(e)}")

def create_response(status_code, data, headers=None):
    """Create standardized API response"""
    if headers is None:
        headers = {'Content-Type': 'application/json'}
    
    return {
        'statusCode': status_code,
        'headers': headers,
        'body': json.dumps(data) if isinstance(data, dict) else data
    }

def handle_errors(func):
    """Decorator for comprehensive error handling"""
    @wraps(func)
    def wrapper(event, context):
        try:
            return func(event, context)
        except ValueError as e:
            logger.error(f"Validation error: {str(e)}")
            return create_response(400, {'error': 'Bad Request', 'message': str(e)})
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")
            return create_response(500, {'error': 'Internal Server Error', 'message': 'An unexpected error occurred'})
    return wrapper

class ConnectionManager:
    """Manage external connections for reuse"""
    
    def __init__(self):
        self._connections = {}
    
    def get_connection(self, connection_type, **kwargs):
        """Get or create connection of specified type"""
        key = f"{connection_type}_{hash(frozenset(kwargs.items()))}"
        
        if key not in self._connections:
            if connection_type == 'requests_session':
                import requests
                session = requests.Session()
                # Configure session settings
                session.headers.update({'User-Agent': 'OptimizedLambda/1.0'})
                self._connections[key] = session
            elif connection_type == 'boto3_client':
                import boto3
                service = kwargs.get('service', 's3')
                self._connections[key] = boto3.client(service)
            elif connection_type == 'boto3_resource':
                import boto3
                service = kwargs.get('service', 'dynamodb')
                self._connections[key] = boto3.resource(service)
        
        return self._connections[key]

# Global connection manager for reuse across invocations
connection_manager = ConnectionManager()
EOF
```

3. Create utilities layer:
```bash
zip -r [your-username]-utils-layer.zip python/
```

4. Publish utilities layer:
```bash
aws lambda publish-layer-version \
  --layer-name [your-username]-lambda-utils \
  --description "Utility functions for Lambda optimization" \
  --zip-file fileb://[your-username]-utils-layer.zip \
  --compatible-runtimes python3.9
```

---

## Task 3: Create Optimized Lambda Function

### Step 3.1: Build Optimized Function

1. Create directory for optimized function:
```bash
mkdir ~/environment/[your-username]-optimized-function
cd ~/environment/[your-username]-optimized-function
```

2. Create `optimized_function.py`:

```python
import json
import time
import os
from datetime import datetime

# Import utilities from layer
from lambda_utils import timer, validate_input, create_response, handle_errors, connection_manager

# Environment variables
GITHUB_API_URL = os.environ.get('GITHUB_API_URL', 'https://api.github.com/repos/aws/aws-sdk-python')

# Global variables for connection reuse (initialized outside handler)
requests_session = None
s3_client = None
dynamodb_resource = None

def initialize_connections():
    """Initialize connections outside handler for reuse"""
    global requests_session, s3_client, dynamodb_resource
    
    if requests_session is None:
        requests_session = connection_manager.get_connection('requests_session')
    
    if s3_client is None:
        s3_client = connection_manager.get_connection('boto3_client', service='s3')
    
    if dynamodb_resource is None:
        dynamodb_resource = connection_manager.get_connection('boto3_resource', service='dynamodb')

# Initialize connections at module level
initialize_connections()

@timer
def fetch_github_data():
    """Fetch data from GitHub API with connection reuse"""
    try:
        response = requests_session.get(GITHUB_API_URL, timeout=5)
        response.raise_for_status()
        return response.json().get('stargazers_count', 0)
    except Exception as e:
        print(f"Error fetching GitHub data: {str(e)}")
        return 0

@timer
def perform_heavy_operation():
    """Optimized CPU-intensive operation"""
    # Use more efficient calculation
    return sum(i * i for i in range(50000))  # Reduced range for better performance

@timer
def perform_memory_operation():
    """Optimized memory operation"""
    # Use generator for memory efficiency
    return sum(1 for _ in range(500000))

@handle_errors
def lambda_handler(event, context):
    """
    Optimized Lambda function with best practices
    """
    
    # Validate input
    body = validate_input(event, required_fields=[])
    operation = body.get('operation', 'default')
    
    # Start processing
    start_time = time.time()
    
    # Prepare response data
    data = {
        'timestamp': datetime.now().isoformat(),
        'operation': operation,
        'function_name': context.function_name,
        'memory_limit': context.memory_limit_in_mb,
        'remaining_time': context.get_remaining_time_in_millis()
    }
    
    # Fetch external data with optimized connection
    github_stars = fetch_github_data()
    data['github_stars'] = github_stars
    
    # Perform operations based on type
    if operation == 'heavy':
        result = perform_heavy_operation()
        data['calculation_result'] = result
    elif operation == 'memory':
        result = perform_memory_operation()
        data['list_sum'] = result
    else:
        data['message'] = 'Default operation completed efficiently'
    
    # Calculate processing time
    processing_time = time.time() - start_time
    data['processing_time'] = processing_time
    data['remaining_time_after'] = context.get_remaining_time_in_millis()
    
    return create_response(200, data)
```

### Step 3.2: Deploy Optimized Function with Layers

1. Create deployment package (no dependencies needed - using layers):
```bash
zip optimized-function.zip optimized_function.py
```

2. Deploy optimized function with layers:
```bash
aws lambda create-function \
  --function-name [your-username]-optimized-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler optimized_function.lambda_handler \
  --zip-file fileb://optimized-function.zip \
  --timeout 30 \
  --memory-size 256 \
  --environment Variables='{GITHUB_API_URL="https://api.github.com/repos/aws/aws-sdk-python"}' \
  --layers arn:aws:lambda:us-east-1:[ACCOUNT-ID]:layer:[your-username]-shared-dependencies:1 arn:aws:lambda:us-east-1:[ACCOUNT-ID]:layer:[your-username]-lambda-utils:1 \
  --description "Optimized function with best practices applied"
```

---

## Task 4: Configure Versions and Aliases

### Step 4.1: Create Function Versions

1. Publish version 1 of optimized function:
```bash
aws lambda publish-version \
  --function-name [your-username]-optimized-function \
  --description "Initial optimized version"
```

2. Update function with additional optimizations:
```bash
cat > optimized_function_v2.py << 'EOF'
import json
import time
import os
from datetime import datetime

# Import utilities from layer
from lambda_utils import timer, validate_input, create_response, handle_errors, connection_manager

# Environment variables
GITHUB_API_URL = os.environ.get('GITHUB_API_URL', 'https://api.github.com/repos/aws/aws-sdk-python')

# Global variables for connection reuse (initialized outside handler)
requests_session = None
s3_client = None
dynamodb_resource = None

def initialize_connections():
    """Initialize connections outside handler for reuse"""
    global requests_session, s3_client, dynamodb_resource
    
    if requests_session is None:
        requests_session = connection_manager.get_connection('requests_session')
    
    if s3_client is None:
        s3_client = connection_manager.get_connection('boto3_client', service='s3')
    
    if dynamodb_resource is None:
        dynamodb_resource = connection_manager.get_connection('boto3_resource', service='dynamodb')

# Initialize connections at module level
initialize_connections()

@timer
def fetch_github_data():
    """Fetch data from GitHub API with connection reuse and caching"""
    try:
        response = requests_session.get(GITHUB_API_URL, timeout=5)
        response.raise_for_status()
        return response.json().get('stargazers_count', 0)
    except Exception as e:
        print(f"Error fetching GitHub data: {str(e)}")
        return 0

@timer
def perform_heavy_operation():
    """Further optimized CPU-intensive operation"""
    # Use even more efficient calculation
    return sum(i * i for i in range(25000))  # Further reduced for better performance

@timer
def perform_memory_operation():
    """Further optimized memory operation"""
    # Use more memory-efficient approach
    return sum(1 for _ in range(250000))  # Reduced memory usage

@handle_errors
def lambda_handler(event, context):
    """
    Enhanced optimized Lambda function with additional improvements
    """
    
    # Validate input
    body = validate_input(event, required_fields=[])
    operation = body.get('operation', 'default')
    
    # Start processing
    start_time = time.time()
    
    # Prepare response data
    data = {
        'timestamp': datetime.now().isoformat(),
        'operation': operation,
        'function_name': context.function_name,
        'function_version': context.function_version,
        'memory_limit': context.memory_limit_in_mb,
        'remaining_time': context.get_remaining_time_in_millis(),
        'version': '2.0'  # Version indicator
    }
    
    # Fetch external data with optimized connection
    github_stars = fetch_github_data()
    data['github_stars'] = github_stars
    
    # Perform operations based on type
    if operation == 'heavy':
        result = perform_heavy_operation()
        data['calculation_result'] = result
    elif operation == 'memory':
        result = perform_memory_operation()
        data['list_sum'] = result
    else:
        data['message'] = 'Default operation completed with enhanced efficiency'
    
    # Calculate processing time
    processing_time = time.time() - start_time
    data['processing_time'] = processing_time
    data['remaining_time_after'] = context.get_remaining_time_in_millis()
    
    return create_response(200, data)
EOF
```

3. Update function code:
```bash
zip optimized-function-v2.zip optimized_function_v2.py
mv optimized_function_v2.py optimized_function.py

aws lambda update-function-code \
  --function-name [your-username]-optimized-function \
  --zip-file fileb://optimized-function-v2.zip
```

4. Publish version 2:
```bash
aws lambda publish-version \
  --function-name [your-username]-optimized-function \
  --description "Enhanced optimized version with additional improvements"
```

### Step 4.2: Create Aliases

1. Create development alias pointing to latest version:
```bash
aws lambda create-alias \
  --function-name [your-username]-optimized-function \
  --name [your-username]-dev \
  --function-version '$LATEST' \
  --description "Development environment alias"
```

2. Create production alias pointing to version 1:
```bash
aws lambda create-alias \
  --function-name [your-username]-optimized-function \
  --name [your-username]-prod \
  --function-version '1' \
  --description "Production environment alias"
```

3. Create staging alias pointing to version 2:
```bash
aws lambda create-alias \
  --function-name [your-username]-optimized-function \
  --name [your-username]-staging \
  --function-version '2' \
  --description "Staging environment alias"
```

---

## Task 5: Configure Concurrency and Performance Settings

### Step 5.1: Configure Reserved Concurrency

1. Set reserved concurrency for the optimized function:
```bash
aws lambda put-reserved-concurrency \
  --function-name [your-username]-optimized-function \
  --reserved-concurrent-executions 10
```

2. Configure provisioned concurrency for production alias:
```bash
aws lambda put-provisioned-concurrency-config \
  --function-name [your-username]-optimized-function \
  --qualifier [your-username]-prod \
  --provisioned-concurrency-config ProvisionedConcurrencyExecutions=2
```

### Step 5.2: Optimize Memory Configuration

1. Test function with different memory settings:
```bash
# Test with 256MB (current)
aws lambda invoke \
  --function-name [your-username]-optimized-function:staging \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  memory-256-output.json

# Update to 512MB for comparison
aws lambda update-function-configuration \
  --function-name [your-username]-optimized-function \
  --memory-size 512

# Test with 512MB
aws lambda invoke \
  --function-name [your-username]-optimized-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  memory-512-output.json

# Compare results
echo "256MB Results:"
cat memory-256-output.json | jq '.processing_time'

echo "512MB Results:"
cat memory-512-output.json | jq '.processing_time'
```

---

## Task 6: Implement Advanced Error Handling

### Step 6.1: Create Error Handling Function

1. Create directory for error handling demo:
```bash
mkdir ~/environment/[your-username]-error-handling
cd ~/environment/[your-username]-error-handling
```

2. Create `error_handling_function.py`:

```python
import json
import random
import time
from datetime import datetime
from lambda_utils import validate_input, create_response, handle_errors

class RetryableError(Exception):
    """Custom exception for retryable errors"""
    pass

class NonRetryableError(Exception):
    """Custom exception for non-retryable errors"""
    pass

def simulate_external_service_call():
    """Simulate external service with potential failures"""
    failure_rate = 0.3  # 30% failure rate
    
    if random.random() < failure_rate:
        error_type = random.choice(['timeout', 'rate_limit', 'server_error', 'invalid_data'])
        
        if error_type == 'timeout':
            time.sleep(2)
            raise RetryableError("Service timeout - retryable")
        elif error_type == 'rate_limit':
            raise RetryableError("Rate limit exceeded - retryable")
        elif error_type == 'server_error':
            raise RetryableError("Internal server error - retryable")
        else:
            raise NonRetryableError("Invalid data format - not retryable")
    
    return {"data": "Success", "timestamp": datetime.now().isoformat()}

def retry_with_backoff(func, max_retries=3, base_delay=1):
    """Implement exponential backoff retry logic"""
    for attempt in range(max_retries + 1):
        try:
            return func()
        except RetryableError as e:
            if attempt == max_retries:
                raise e
            
            delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
            print(f"Attempt {attempt + 1} failed: {str(e)}. Retrying in {delay:.2f} seconds...")
            time.sleep(delay)
        except NonRetryableError as e:
            print(f"Non-retryable error: {str(e)}")
            raise e

@handle_errors
def lambda_handler(event, context):
    """
    Function demonstrating advanced error handling patterns
    """
    
    body = validate_input(event)
    operation = body.get('operation', 'default')
    
    data = {
        'timestamp': datetime.now().isoformat(),
        'operation': operation,
        'function_name': context.function_name,
        'request_id': context.aws_request_id
    }
    
    try:
        if operation == 'retry_demo':
            # Demonstrate retry logic
            result = retry_with_backoff(simulate_external_service_call)
            data['result'] = result
            data['status'] = 'success'
        
        elif operation == 'timeout_demo':
            # Demonstrate timeout handling
            remaining_time = context.get_remaining_time_in_millis()
            if remaining_time < 5000:  # Less than 5 seconds remaining
                raise Exception("Insufficient time remaining for operation")
            
            # Simulate work
            time.sleep(1)
            data['result'] = 'Timeout demo completed'
            data['remaining_time'] = context.get_remaining_time_in_millis()
        
        elif operation == 'memory_demo':
            # Demonstrate memory management
            try:
                # Attempt memory-intensive operation
                large_data = [i for i in range(1000000)]
                data['result'] = f'Processed {len(large_data)} items'
                del large_data  # Explicit cleanup
            except MemoryError:
                raise Exception("Memory limit exceeded")
        
        else:
            data['result'] = 'Default operation completed'
        
        return create_response(200, data)
        
    except RetryableError as e:
        print(f"Retryable error after all attempts: {str(e)}")
        return create_response(503, {
            'error': 'Service Unavailable',
            'message': 'Service temporarily unavailable, please try again later',
            'retryable': True
        })
    
    except NonRetryableError as e:
        print(f"Non-retryable error: {str(e)}")
        return create_response(400, {
            'error': 'Bad Request',
            'message': str(e),
            'retryable': False
        })
```

3. Deploy error handling function:
```bash
zip error-handling-function.zip error_handling_function.py

aws lambda create-function \
  --function-name [your-username]-error-handling-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler error_handling_function.lambda_handler \
  --zip-file fileb://error-handling-function.zip \
  --timeout 30 \
  --memory-size 256 \
  --layers arn:aws:lambda:us-east-1:[ACCOUNT-ID]:layer:[your-username]-lambda-utils:1 \
  --description "Function demonstrating advanced error handling patterns"
```

---

## Task 7: Performance Testing and Comparison

### Step 7.1: Performance Benchmarking

1. Create performance test script:
```bash
cat > performance_test.sh << 'EOF'
#!/bin/bash

BASELINE_FUNCTION="[your-username]-baseline-function"
OPTIMIZED_FUNCTION="[your-username]-optimized-function"

echo "Performance Comparison Test"
echo "=========================="

# Test baseline function
echo "Testing Baseline Function..."
for i in {1..5}; do
    echo "Test $i:"
    aws lambda invoke --function-name $BASELINE_FUNCTION \
        --payload '{"body": "{\"operation\": \"heavy\"}"}' \
        baseline_test_$i.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration\|Billed Duration\|Memory Size"
done

echo ""
echo "Testing Optimized Function..."
for i in {1..5}; do
    echo "Test $i:"
    aws lambda invoke --function-name $OPTIMIZED_FUNCTION \
        --payload '{"body": "{\"operation\": \"heavy\"}"}' \
        optimized_test_$i.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration\|Billed Duration\|Memory Size"
done
EOF

chmod +x performance_test.sh
```

2. Run performance tests:
```bash
./performance_test.sh
```

### Step 7.2: Cold Start Analysis

1. Test cold start performance:
```bash
# Delete function to ensure cold start
aws lambda delete-function --function-name [your-username]-baseline-function

# Recreate and test immediately
aws lambda create-function \
  --function-name [your-username]-baseline-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler baseline_function.lambda_handler \
  --zip-file fileb://baseline-function.zip \
  --timeout 30 \
  --memory-size 128

# Test cold start
aws lambda invoke \
  --function-name [your-username]-baseline-function \
  --payload '{"body": "{\"operation\": \"default\"}"}' \
  coldstart-baseline.json --log-type Tail

# Compare with warm optimized function
aws lambda invoke \
  --function-name [your-username]-optimized-function:prod \
  --payload '{"body": "{\"operation\": \"default\"}"}' \
  warmstart-optimized.json --log-type Tail
```

---

## Task 8: Monitor and Analyze Performance

### Step 8.1: Create CloudWatch Dashboard

1. Create CloudWatch dashboard for monitoring:
```bash
cat > dashboard.json << 'EOF'
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
                    [ "AWS/Lambda", "Duration", "FunctionName", "[your-username]-baseline-function" ],
                    [ ".", ".", ".", "[your-username]-optimized-function" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Function Duration Comparison"
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
                    [ "AWS/Lambda", "Invocations", "FunctionName", "[your-username]-baseline-function" ],
                    [ ".", ".", ".", "[your-username]-optimized-function" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Function Invocations"
            }
        }
    ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name "[your-username]-lambda-optimization" \
  --dashboard-body file://dashboard.json
```

### Step 8.2: Analyze Metrics

1. Get performance metrics:
```bash
# Get baseline function metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=[your-username]-baseline-function \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Get optimized function metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=[your-username]-optimized-function \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created baseline and optimized Lambda functions
- [ ] Implemented Lambda layers for dependency management
- [ ] Created function versions and aliases for deployment management
- [ ] Configured concurrency settings and memory optimization
- [ ] Implemented comprehensive error handling patterns
- [ ] Performed performance testing and comparison
- [ ] Created CloudWatch monitoring dashboard
- [ ] Applied username prefixing to all resources

### Expected Results

Your optimized Lambda functions should demonstrate:
1. Improved performance through connection reuse and optimization
2. Better error handling with retry logic and proper exception management
3. Efficient dependency management using layers
4. Version control and deployment management with aliases
5. Appropriate concurrency configuration for workload requirements
6. Comprehensive monitoring and observability

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Layer not found or import errors
- **Solution:** Verify layer ARN is correct and layer is published
- Check layer compatibility with runtime version
- Ensure proper directory structure in layer

**Issue:** Function timeouts during testing
- **Solution:** Increase timeout settings
- Optimize function code for performance
- Check for blocking operations

**Issue:** Concurrency limits exceeded
- **Solution:** Adjust reserved concurrency settings
- Monitor account-level concurrency limits
- Implement appropriate scaling patterns

**Issue:** Version/alias management errors
- **Solution:** Verify function versions exist before creating aliases
- Check permissions for version publishing
- Ensure proper alias naming conventions

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete functions
aws lambda delete-function --function-name [your-username]-baseline-function
aws lambda delete-function --function-name [your-username]-optimized-function
aws lambda delete-function --function-name [your-username]-error-handling-function

# Delete layers
aws lambda delete-layer-version --layer-name [your-username]-shared-dependencies --version-number 1
aws lambda delete-layer-version --layer-name [your-username]-lambda-utils --version-number 1

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-lambda-optimization
```

---

## Key Takeaways

From this lab, you should understand:
1. **Performance Optimization:** Connection reuse, memory management, and efficient algorithms
2. **Dependency Management:** Lambda layers for code reuse and smaller deployment packages
3. **Version Control:** Function versions and aliases for deployment management
4. **Error Handling:** Retry patterns, exception handling, and graceful degradation
5. **Concurrency Management:** Reserved and provisioned concurrency for predictable performance
6. **Monitoring:** CloudWatch metrics and dashboards for performance analysis

---

## Next Steps

In the next lab, you will explore AWS Step Functions for workflow orchestration, building on the optimized Lambda functions you've created.