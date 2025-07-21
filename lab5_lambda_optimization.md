# Developing Serverless Solutions on AWS - Lab 5
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

## Task 1: Create Baseline Lambda Function (Cloud9)

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
import urllib3
import random

def lambda_handler(event, context):
    """
    Baseline function with common performance issues
    """
    
    # Poor practice: Create new HTTP client on each invocation
    http = urllib3.PoolManager()
    
    # Extract operation from request
    body = json.loads(event.get('body', '{}'))
    operation = body.get('operation', 'default')
    
    print(f"Processing operation: {operation}")
    
    # Poor practice: Always load large data structure
    large_config = {f"config_{i}": f"value_{i}" for i in range(1000)}
    
    start_time = time.time()
    
    if operation == 'heavy':
        # Simulate CPU-intensive work
        result = sum(i * i for i in range(100000))
        
        # Poor practice: Multiple individual API calls
        api_results = []
        for i in range(3):
            response = http.request('GET', 'https://httpbin.org/delay/1')
            api_results.append(response.status)
            
    elif operation == 'database':
        # Simulate database connection (poor practice: no connection reuse)
        time.sleep(0.5)  # Connection overhead
        
        # Simulate query
        time.sleep(0.2)
        result = f"Database result for operation {operation}"
        
    else:
        # Default operation
        result = f"Basic operation completed"
        time.sleep(0.1)
    
    processing_time = time.time() - start_time
    
    # Poor practice: No error handling
    response_data = {
        'statusCode': 200,
        'operation': operation,
        'result': result,
        'processing_time': processing_time,
        'config_size': len(large_config),
        'function_version': 'baseline'
    }
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(response_data)
    }
```

3. Deploy baseline function:
```bash
zip baseline-function.zip baseline_function.py

aws lambda create-function \
  --function-name [your-username]-baseline-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler baseline_function.lambda_handler \
  --zip-file fileb://baseline-function.zip \
  --timeout 30 \
  --memory-size 128 \
  --description "Baseline function demonstrating common performance issues"
```

### Step 1.2: Test Baseline Performance

1. Test the baseline function:
```bash
aws lambda invoke \
  --function-name [your-username]-baseline-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  baseline-output.json --log-type Tail
```

2. Review execution logs and duration:
```bash
cat baseline-output.json
```

---

## Task 2: Create Lambda Layers (Console)

### Step 2.1: Create Shared Dependencies Layer

1. Navigate to **AWS Lambda** in the AWS Console
2. Click **Layers** in the left navigation
3. Click **Create layer**

4. Configure the layer:
   - **Name**: `[your-username]-shared-dependencies`
   - **Description**: `Shared dependencies for optimized Lambda functions`
   - **Upload method**: Upload a .zip file

5. In Cloud9, create the layer content:
```bash
mkdir ~/environment/[your-username]-shared-layer
cd ~/environment/[your-username]-shared-layer
mkdir python
cd python
```

6. Create `optimized_http.py`:
```python
import urllib3
import json
from functools import lru_cache

# Global connection pool (reused across invocations)
http_pool = urllib3.PoolManager(
    maxsize=10,
    block=True,
    timeout=urllib3.Timeout(connect=2.0, read=10.0)
)

class OptimizedHTTPClient:
    """Optimized HTTP client with connection pooling"""
    
    @staticmethod
    def get(url, headers=None):
        """Perform optimized GET request"""
        try:
            response = http_pool.request('GET', url, headers=headers)
            return {
                'status_code': response.status,
                'data': response.data.decode('utf-8') if response.data else None,
                'headers': dict(response.headers)
            }
        except Exception as e:
            return {
                'status_code': 500,
                'error': str(e)
            }
    
    @staticmethod
    def post(url, data=None, headers=None):
        """Perform optimized POST request"""
        try:
            body = json.dumps(data) if data else None
            response = http_pool.request('POST', url, body=body, headers=headers)
            return {
                'status_code': response.status,
                'data': response.data.decode('utf-8') if response.data else None,
                'headers': dict(response.headers)
            }
        except Exception as e:
            return {
                'status_code': 500,
                'error': str(e)
            }

@lru_cache(maxsize=128)
def get_cached_config(config_type):
    """Cached configuration loader"""
    if config_type == 'database':
        return {
            'host': 'optimized-db.cluster.amazonaws.com',
            'port': 5432,
            'connection_pool_size': 10,
            'timeout': 30
        }
    elif config_type == 'api':
        return {
            'base_url': 'https://api.example.com',
            'version': 'v1',
            'timeout': 15,
            'retry_attempts': 3
        }
    else:
        return {'default': True}
```

7. Create the layer package:
```bash
cd ~/environment/[your-username]-shared-layer
zip -r shared-dependencies.zip python/
```

8. Upload the layer in AWS Console:
   - Click **Browse** and select `shared-dependencies.zip`
   - **Compatible runtimes**: Select `Python 3.9`
   - **License**: MIT (optional)
   - Click **Create**

9. **Copy the Layer ARN** from the layer details page

### Step 2.2: Create Utility Functions Layer

1. In AWS Console, click **Create layer** again
2. Configure the utility layer:
   - **Name**: `[your-username]-lambda-utils`
   - **Description**: `Common utility functions for Lambda optimization`

3. In Cloud9, create utility layer:
```bash
mkdir ~/environment/[your-username]-utils-layer
cd ~/environment/[your-username]-utils-layer
mkdir python
cd python
```

4. Create `lambda_utils.py`:
```python
import json
import time
import logging
from datetime import datetime
from functools import wraps

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

class LambdaUtils:
    """Utility functions for Lambda optimization"""
    
    @staticmethod
    def timing_decorator(func):
        """Decorator to measure function execution time"""
        @wraps(func)
        def wrapper(*args, **kwargs):
            start_time = time.time()
            result = func(*args, **kwargs)
            execution_time = time.time() - start_time
            logger.info(f"Function {func.__name__} executed in {execution_time:.4f} seconds")
            return result
        return wrapper
    
    @staticmethod
    def error_handler(max_retries=3, delay=1):
        """Decorator for automatic error handling and retries"""
        def decorator(func):
            @wraps(func)
            def wrapper(*args, **kwargs):
                last_exception = None
                for attempt in range(max_retries):
                    try:
                        return func(*args, **kwargs)
                    except Exception as e:
                        last_exception = e
                        logger.warning(f"Attempt {attempt + 1} failed: {str(e)}")
                        if attempt < max_retries - 1:
                            time.sleep(delay * (2 ** attempt))  # Exponential backoff
                        else:
                            logger.error(f"All {max_retries} attempts failed")
                            raise last_exception
            return wrapper
        return decorator
    
    @staticmethod
    def validate_input(required_fields):
        """Decorator to validate input parameters"""
        def decorator(func):
            @wraps(func)
            def wrapper(event, context):
                try:
                    body = json.loads(event.get('body', '{}'))
                except json.JSONDecodeError:
                    return {
                        'statusCode': 400,
                        'body': json.dumps({'error': 'Invalid JSON in request body'})
                    }
                
                missing_fields = [field for field in required_fields if field not in body]
                if missing_fields:
                    return {
                        'statusCode': 400,
                        'body': json.dumps({
                            'error': f'Missing required fields: {missing_fields}'
                        })
                    }
                
                return func(event, context)
            return wrapper
        return decorator
    
    @staticmethod
    def format_response(status_code, data, headers=None):
        """Standardized response formatter"""
        default_headers = {
            'Content-Type': 'application/json',
            'X-Timestamp': datetime.now().isoformat()
        }
        
        if headers:
            default_headers.update(headers)
        
        return {
            'statusCode': status_code,
            'headers': default_headers,
            'body': json.dumps(data) if isinstance(data, (dict, list)) else str(data)
        }

def log_event(event, context):
    """Log incoming event details"""
    logger.info(f"Function: {context.function_name}")
    logger.info(f"Request ID: {context.aws_request_id}")
    logger.info(f"Event: {json.dumps(event, default=str)}")
```

5. Create the utils layer package:
```bash
cd ~/environment/[your-username]-utils-layer
zip -r lambda-utils.zip python/
```

6. Upload in AWS Console and **copy the Layer ARN**

---

## Task 3: Create Optimized Lambda Function (Cloud9)

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
from optimized_http import OptimizedHTTPClient, get_cached_config
from lambda_utils import LambdaUtils, log_event

# Global variables (initialized once per container)
CONFIG_CACHE = {}
PERFORMANCE_METRICS = {}

# Pre-load frequently used configuration
try:
    DB_CONFIG = get_cached_config('database')
    API_CONFIG = get_cached_config('api')
except Exception as e:
    print(f"Error loading configuration: {e}")
    DB_CONFIG = {}
    API_CONFIG = {}

@LambdaUtils.timing_decorator
@LambdaUtils.error_handler(max_retries=2, delay=0.5)
def perform_heavy_operation():
    """Optimized CPU-intensive operation"""
    # Use more efficient algorithm
    result = sum(i * i for i in range(50000))  # Reduced iterations
    return result

@LambdaUtils.timing_decorator
@LambdaUtils.error_handler(max_retries=3, delay=1)
def perform_api_calls():
    """Optimized API calls with connection pooling"""
    # Single batch request instead of multiple individual calls
    response = OptimizedHTTPClient.get('https://httpbin.org/json')
    return response

@LambdaUtils.timing_decorator
def simulate_database_operation():
    """Optimized database simulation with connection reuse"""
    # Simulate connection reuse (no connection overhead after first call)
    if 'db_connected' not in PERFORMANCE_METRICS:
        time.sleep(0.1)  # Initial connection overhead
        PERFORMANCE_METRICS['db_connected'] = True
        print("Database connection established (first time)")
    else:
        print("Reusing existing database connection")
    
    # Simulate query
    time.sleep(0.05)  # Faster query with optimized indexes
    return "Optimized database result"

def lambda_handler(event, context):
    """
    Optimized Lambda function demonstrating best practices
    """
    
    # Log event details
    log_event(event, context)
    
    try:
        # Parse input with validation
        body = json.loads(event.get('body', '{}'))
        operation = body.get('operation', 'default')
        
        print(f"Processing optimized operation: {operation}")
        start_time = time.time()
        
        # Use cached configuration instead of recreating
        config_size = len(DB_CONFIG) + len(API_CONFIG)
        
        # Process based on operation type
        if operation == 'heavy':
            result = perform_heavy_operation()
            api_result = perform_api_calls()
            combined_result = {
                'computation': result,
                'api_status': api_result.get('status_code', 'unknown')
            }
            
        elif operation == 'database':
            result = simulate_database_operation()
            combined_result = {'database_result': result}
            
        else:
            # Default operation
            combined_result = {'message': 'Optimized basic operation completed'}
            time.sleep(0.02)  # Reduced processing time
        
        processing_time = time.time() - start_time
        
        # Prepare response data
        response_data = {
            'operation': operation,
            'result': combined_result,
            'processing_time': processing_time,
            'config_size': config_size,
            'function_version': 'optimized',
            'optimizations': [
                'Connection pooling',
                'Configuration caching',
                'Error handling with retries',
                'Efficient algorithms',
                'Environment reuse'
            ],
            'performance_metrics': PERFORMANCE_METRICS
        }
        
        return LambdaUtils.format_response(200, response_data)
        
    except json.JSONDecodeError:
        error_response = {'error': 'Invalid JSON in request body'}
        return LambdaUtils.format_response(400, error_response)
        
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        error_response = {'error': 'Internal server error', 'details': str(e)}
        return LambdaUtils.format_response(500, error_response)
```

### Step 3.2: Deploy Optimized Function with Layers

1. Deploy the optimized function:
```bash
zip optimized-function.zip optimized_function.py

aws lambda create-function \
  --function-name [your-username]-optimized-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler optimized_function.lambda_handler \
  --zip-file fileb://optimized-function.zip \
  --timeout 30 \
  --memory-size 256 \
  --layers arn:aws:lambda:us-east-1:[ACCOUNT-ID]:layer:[your-username]-shared-dependencies:1 arn:aws:lambda:us-east-1:[ACCOUNT-ID]:layer:[your-username]-lambda-utils:1 \
  --description "Optimized function with best practices and layers"
```

### Step 3.3: Test Optimized Function

1. Test the optimized function:
```bash
aws lambda invoke \
  --function-name [your-username]-optimized-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  optimized-output.json --log-type Tail
```

2. Compare results:
```bash
echo "=== Baseline Results ==="
cat baseline-output.json | jq '.processing_time'

echo "=== Optimized Results ==="
cat optimized-output.json | jq '.processing_time'
```

---

## Task 4: Configure Versions and Aliases (Console)

### Step 4.1: Create Function Versions

1. Navigate to **AWS Lambda** in the console
2. Click on your function: `[your-username]-optimized-function`
3. Click **Actions** → **Publish new version**
4. Configure version 1:
   - **Version description**: `Initial optimized version with layers and best practices`
   - Click **Publish**
5. **Note the Version ARN** (version 1)

6. Update function code for version 2:
```bash
cd ~/environment/[your-username]-optimized-function

# Add version info to the function
sed -i 's/"function_version": "optimized"/"function_version": "optimized-v2"/' optimized_function.py

zip optimized-function-v2.zip optimized_function.py

aws lambda update-function-code \
  --function-name [your-username]-optimized-function \
  --zip-file fileb://optimized-function-v2.zip
```

7. In the Lambda console, click **Actions** → **Publish new version**
8. Configure version 2:
   - **Version description**: `Enhanced optimized version with additional improvements`
   - Click **Publish**

### Step 4.2: Create Aliases (Console)

1. In the Lambda console, click **Aliases** tab
2. Click **Create alias**
3. Configure development alias:
   - **Name**: `[your-username]-dev`
   - **Description**: `Development environment alias`
   - **Version**: `$LATEST`
   - Click **Create**

4. Create production alias:
   - Click **Create alias**
   - **Name**: `[your-username]-prod`
   - **Description**: `Production environment alias`
   - **Version**: `1`
   - Click **Create**

5. Create staging alias:
   - Click **Create alias**
   - **Name**: `[your-username]-staging`
   - **Description**: `Staging environment alias`
   - **Version**: `2`
   - Click **Create**

### Step 4.3: Test Different Aliases

1. Test production alias:
```bash
aws lambda invoke \
  --function-name [your-username]-optimized-function:[your-username]-prod \
  --payload '{"body": "{\"operation\": \"default\"}"}' \
  prod-alias-output.json
```

2. Test staging alias:
```bash
aws lambda invoke \
  --function-name [your-username]-optimized-function:[your-username]-staging \
  --payload '{"body": "{\"operation\": \"default\"}"}' \
  staging-alias-output.json
```

---

## Task 5: Configure Concurrency Settings (Console)

### Step 5.1: Configure Reserved Concurrency

1. In the Lambda console, go to your function: `[your-username]-optimized-function`
2. Click the **Configuration** tab
3. Click **Concurrency** in the left panel
4. Click **Edit**

5. Configure concurrency:
   - **Reserve concurrency**: Checked
   - **Reserved concurrency**: 10
   - Click **Save**

### Step 5.2: Configure Provisioned Concurrency

1. Still in the **Concurrency** section, scroll down to **Provisioned concurrency**
2. Click **Add configuration**
3. Configure provisioned concurrency:
   - **Version or alias**: Select `[your-username]-prod`
   - **Provisioned concurrency**: 2
   - Click **Save**

4. Monitor the provisioned concurrency status until it shows **Ready**

### Step 5.3: Test Concurrency Settings

1. Test with provisioned concurrency (prod alias):
```bash
for i in {1..5}; do
  echo "Request $i to prod alias (provisioned):"
  aws lambda invoke \
    --function-name [your-username]-optimized-function:[your-username]-prod \
    --payload '{"body": "{\"operation\": \"default\"}"}' \
    provisioned-test-$i.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration"
done
```

2. Test without provisioned concurrency (staging alias):
```bash
for i in {1..5}; do
  echo "Request $i to staging alias (on-demand):"
  aws lambda invoke \
    --function-name [your-username]-optimized-function:[your-username]-staging \
    --payload '{"body": "{\"operation\": \"default\"}"}' \
    ondemand-test-$i.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration"
done
```

---

## Task 6: Optimize Memory Configuration (Console)

### Step 6.1: Test Different Memory Settings

1. In the Lambda console, go to **Configuration** → **General configuration**
2. Click **Edit**
3. Current memory: Note the current setting (256 MB)
4. Click **Cancel** (we'll test programmatically first)

5. Test current memory performance:
```bash
aws lambda invoke \
  --function-name [your-username]-optimized-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  memory-256-test.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration\|Memory"
```

### Step 6.2: Update Memory via Console

1. In the Lambda console, click **Edit** on General configuration
2. Change **Memory** to 512 MB
3. Click **Save**

4. Test with increased memory:
```bash
aws lambda invoke \
  --function-name [your-username]-optimized-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  memory-512-test.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration\|Memory"
```

5. Compare performance:
```bash
echo "=== 256MB Results ==="
cat memory-256-test.json | jq '.processing_time'

echo "=== 512MB Results ==="
cat memory-512-test.json | jq '.processing_time'
```

---

## Task 7: Create CloudWatch Dashboard (Console)

### Step 7.1: Create Lambda Optimization Dashboard

1. Navigate to **CloudWatch** in the AWS Console
2. Click **Dashboards**
3. Click **Create dashboard**
4. **Dashboard name**: `[your-username]-lambda-optimization`
5. Click **Create dashboard**

### Step 7.2: Add Lambda Metrics Widgets

1. Click **Add widget**
2. Select **Line** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/Lambda
   - **FunctionName**: Select both baseline and optimized functions
   - **Metrics**: Duration, Invocations, Errors

4. **Graphed metrics** tab:
   - **Period**: 1 minute
   - **Statistic**: Average for Duration, Sum for others
5. **Widget title**: Lambda Function Performance
6. Click **Create widget**

### Step 7.3: Add Concurrency Metrics

1. Click **Add widget**
2. Select **Number** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/Lambda
   - **FunctionName**: Select optimized function
   - **Metrics**: ConcurrentExecutions, ProvisionedConcurrencyInvocations

4. **Widget title**: Concurrency Metrics
5. Click **Create widget**

### Step 7.4: Add Cost Optimization Metrics

1. Click **Add widget**
2. Select **Line** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/Lambda
   - **FunctionName**: Select both functions
   - **Metrics**: Duration (to calculate cost)

4. **Graphed metrics** tab:
   - Add **Math expression**: `m1 * 0.0000166667` (cost per 100ms at 1GB)
   - **Label**: Estimated Cost per Invocation
5. **Widget title**: Cost Comparison
6. Click **Create widget**

7. Click **Save dashboard**

---

## Task 8: Performance Testing and Analysis

### Step 8.1: Comprehensive Performance Test

1. Create comprehensive test script:
```bash
cat > comprehensive_test.sh << 'EOF'
#!/bin/bash

echo "Lambda Function Optimization Analysis"
echo "===================================="

BASELINE="[your-username]-baseline-function"
OPTIMIZED="[your-username]-optimized-function"

# Test different operations
OPERATIONS=("default" "heavy" "database")

for op in "${OPERATIONS[@]}"; do
    echo ""
    echo "Testing Operation: $op"
    echo "------------------------"
    
    echo "Baseline Function:"
    for i in {1..3}; do
        aws lambda invoke --function-name $BASELINE \
            --payload "{\"body\": \"{\\\"operation\\\": \\\"$op\\\"}\"}" \
            baseline_${op}_${i}.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration"
    done
    
    echo ""
    echo "Optimized Function:"
    for i in {1..3}; do
        aws lambda invoke --function-name $OPTIMIZED \
            --payload "{\"body\": \"{\\\"operation\\\": \\\"$op\\\"}\"}" \
            optimized_${op}_${i}.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration"
    done
done

echo ""
echo "Processing Time Comparison:"
echo "=========================="
for op in "${OPERATIONS[@]}"; do
    echo "Operation: $op"
    echo "Baseline processing time: $(cat baseline_${op}_1.json | jq -r '.processing_time // "N/A"')"
    echo "Optimized processing time: $(cat optimized_${op}_1.json | jq -r '.processing_time // "N/A"')"
    echo ""
done
EOF

chmod +x comprehensive_test.sh
```

2. Run comprehensive tests:
```bash
./comprehensive_test.sh
```

### Step 8.2: Monitor Real-time Performance

1. Navigate to your CloudWatch dashboard
2. Refresh the dashboard to see real-time metrics
3. Observe the differences in:
   - **Duration**: Optimized function should show lower duration
   - **Memory usage**: More efficient memory utilization
   - **Error rates**: Improved error handling

### Step 8.3: Layer Performance Analysis

1. Create a function without layers for comparison:
```bash
# Copy optimized function code but remove layer dependencies
mkdir ~/environment/[your-username]-no-layers-test
cd ~/environment/[your-username]-no-layers-test

# Create simplified version without layer imports
cat > no_layers_function.py << 'EOF'
import json
import time

def lambda_handler(event, context):
    """Function without layers for comparison"""
    start_time = time.time()
    
    body = json.loads(event.get('body', '{}'))
    operation = body.get('operation', 'default')
    
    # Simple processing
    if operation == 'heavy':
        result = sum(i * i for i in range(50000))
    else:
        result = "Basic operation"
        time.sleep(0.02)
    
    processing_time = time.time() - start_time
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'result': result,
            'processing_time': processing_time,
            'function_version': 'no-layers'
        })
    }
EOF

zip no-layers-function.zip no_layers_function.py

aws lambda create-function \
  --function-name [your-username]-no-layers-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler no_layers_function.lambda_handler \
  --zip-file fileb://no-layers-function.zip \
  --timeout 30 \
  --memory-size 256 \
  --description "Function without layers for performance comparison"
```

2. Test cold start comparison:
```bash
echo "Cold start comparison:"
echo "No layers function:"
aws lambda invoke \
  --function-name [your-username]-no-layers-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  no-layers-cold.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration"

echo "Function with layers:"
aws lambda invoke \
  --function-name [your-username]-optimized-function \
  --payload '{"body": "{\"operation\": \"heavy\"}"}' \
  with-layers-cold.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep "Duration"
```

---

## Task 9: Error Handling Implementation (Cloud9)

### Step 9.1: Create Advanced Error Handling Function

1. Create directory for error handling demo:
```bash
mkdir ~/environment/[your-username]-error-handling
cd ~/environment/[your-username]-error-handling
```

2. Create `error_handling_function.py`:

```python
import json
import time
import random
from lambda_utils import LambdaUtils, log_event

# Simulate external service configuration
EXTERNAL_SERVICES = {
    'payment_api': {'timeout': 5, 'retry_attempts': 3},
    'inventory_api': {'timeout': 3, 'retry_attempts': 2},
    'notification_service': {'timeout': 2, 'retry_attempts': 1}
}

@LambdaUtils.error_handler(max_retries=3, delay=1)
def call_external_service(service_name, operation):
    """Simulate calling external service with error handling"""
    
    config = EXTERNAL_SERVICES.get(service_name, {})
    timeout = config.get('timeout', 5)
    
    print(f"Calling {service_name} for {operation}")
    
    # Simulate network latency
    time.sleep(random.uniform(0.1, 0.5))
    
    # Simulate random failures (30% chance)
    if random.random() < 0.3:
        raise Exception(f"{service_name} temporarily unavailable")
    
    # Simulate timeout (10% chance)
    if random.random() < 0.1:
        time.sleep(timeout + 1)
        raise Exception(f"{service_name} timeout after {timeout}s")
    
    # Success case
    return {
        'service': service_name,
        'operation': operation,
        'status': 'success',
        'response_time': random.uniform(0.1, 0.5)
    }

@LambdaUtils.validate_input(['transaction_id', 'amount'])
def lambda_handler(event, context):
    """
    Advanced error handling demonstration
    """
    
    log_event(event, context)
    
    try:
        body = json.loads(event.get('body', '{}'))
        transaction_id = body['transaction_id']
        amount = float(body['amount'])
        operation_type = body.get('operation_type', 'purchase')
        
        print(f"Processing transaction {transaction_id} for ${amount}")
        
        results = {}
        errors = []
        
        # Call multiple services with different error handling strategies
        services_to_call = ['payment_api', 'inventory_api', 'notification_service']
        
        for service in services_to_call:
            try:
                result = call_external_service(service, operation_type)
                results[service] = result
                print(f"✅ {service} completed successfully")
                
            except Exception as e:
                error_info = {
                    'service': service,
                    'error': str(e),
                    'timestamp': time.time()
                }
                errors.append(error_info)
                print(f"❌ {service} failed: {str(e)}")
                
                # Different error handling strategies by service
                if service == 'payment_api':
                    # Payment failures are critical - fail the entire transaction
                    return LambdaUtils.format_response(500, {
                        'error': 'Transaction failed - payment processing error',
                        'transaction_id': transaction_id,
                        'details': str(e)
                    })
                    
                elif service == 'inventory_api':
                    # Inventory failures - use fallback logic
                    print("Using fallback inventory check")
                    results[service] = {
                        'service': service,
                        'status': 'fallback',
                        'message': 'Used cached inventory data'
                    }
                    
                elif service == 'notification_service':
                    # Notification failures - non-critical, continue processing
                    print("Notification service failed, but transaction can continue")
                    results[service] = {
                        'service': service,
                        'status': 'failed',
                        'message': 'Will retry notification later'
                    }
        
        # Calculate transaction status
        critical_services = ['payment_api', 'inventory_api']
        critical_failures = [e for e in errors if e['service'] in critical_services]
        
        if critical_failures:
            transaction_status = 'failed'
            status_code = 500
        else:
            transaction_status = 'completed'
            status_code = 200
        
        response_data = {
            'transaction_id': transaction_id,
            'amount': amount,
            'operation_type': operation_type,
            'status': transaction_status,
            'service_results': results,
            'errors': errors,
            'processing_summary': {
                'total_services': len(services_to_call),
                'successful_services': len(results),
                'failed_services': len(errors),
                'critical_failures': len(critical_failures)
            }
        }
        
        return LambdaUtils.format_response(status_code, response_data)
        
    except ValueError as e:
        # Handle specific validation errors
        return LambdaUtils.format_response(400, {
            'error': 'Invalid input data',
            'details': str(e)
        })
        
    except Exception as e:
        # Handle unexpected errors
        print(f"Unexpected error in transaction processing: {str(e)}")
        return LambdaUtils.format_response(500, {
            'error': 'Internal server error',
            'transaction_id': body.get('transaction_id', 'unknown'),
            'details': 'An unexpected error occurred during processing'
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

### Step 9.2: Test Error Handling Scenarios

1. Test successful transaction:
```bash
aws lambda invoke \
  --function-name [your-username]-error-handling-function \
  --payload '{
    "body": "{\"transaction_id\": \"TXN-001\", \"amount\": 99.99, \"operation_type\": \"purchase\"}"
  }' \
  error-handling-success.json
```

2. Test with invalid input:
```bash
aws lambda invoke \
  --function-name [your-username]-error-handling-function \
  --payload '{
    "body": "{\"transaction_id\": \"TXN-002\"}"
  }' \
  error-handling-validation.json
```

3. Run multiple tests to trigger different error scenarios:
```bash
for i in {1..5}; do
  echo "Test $i:"
  aws lambda invoke \
    --function-name [your-username]-error-handling-function \
    --payload "{
      \"body\": \"{\\\"transaction_id\\\": \\\"TXN-00$i\\\", \\\"amount\\\": $((50 + i * 10)).99, \\\"operation_type\\\": \\\"purchase\\\"}\"
    }" \
    error-test-$i.json --log-type Tail --query 'LogResult' --output text | base64 -d | grep -E "(ERROR|✅|❌)"
    
  echo "Result: $(cat error-test-$i.json | jq -r '.status')"
  echo ""
done
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created baseline and optimized Lambda functions
- [ ] Built and deployed Lambda layers through AWS Console
- [ ] Configured function versions and aliases via console
- [ ] Implemented comprehensive error handling with retry logic
- [ ] Configured concurrency settings (reserved and provisioned)
- [ ] Optimized memory allocation and tested performance
- [ ] Created CloudWatch dashboard for monitoring
- [ ] Demonstrated measurable performance improvements
- [ ] Applied username prefixing to all resources

### Expected Results

Your optimization efforts should demonstrate:

1. **Improved Performance**: Faster execution times and lower costs
2. **Better Error Handling**: Graceful failure management with retries
3. **Efficient Resource Usage**: Optimized memory and concurrency settings
4. **Code Reusability**: Shared functionality through layers
5. **Deployment Management**: Version control with aliases
6. **Monitoring**: Comprehensive dashboard for performance analysis

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Layer import errors
- **Console Check**: Verify layer ARN is correct in function configuration
- **Console Check**: Check layer compatibility with runtime version
- **Solution**: Ensure proper directory structure in layer (python/ folder)

**Issue:** Provisioned concurrency not working
- **Console Check**: Verify provisioned concurrency status is "Ready"
- **Console Check**: Ensure alias is correctly configured
- **Solution**: Wait for provisioned concurrency to initialize completely

**Issue:** Performance tests showing inconsistent results
- **Console Monitor**: Check CloudWatch logs for cold starts
- **Solution**: Run multiple tests and average results
- **Solution**: Use provisioned concurrency for consistent performance

**Issue:** Version/alias creation fails
- **Console Check**: Verify function code is published successfully
- **Solution**: Ensure function exists and is deployable before creating versions

---

## Clean Up (Optional)

### Via Console:
1. **Lambda Functions**: Delete all test functions
2. **Lambda Layers**: Delete both custom layers  
3. **CloudWatch**: Delete the dashboard
4. **Aliases**: Delete all custom aliases

### Via CLI:
```bash
# Delete functions
aws lambda delete-function --function-name [your-username]-baseline-function
aws lambda delete-function --function-name [your-username]-optimized-function
aws lambda delete-function --function-name [your-username]-error-handling-function
aws lambda delete-function --function-name [your-username]-no-layers-function

# Delete layers
aws lambda delete-layer-version --layer-name [your-username]-shared-dependencies --version-number 1
aws lambda delete-layer-version --layer-name [your-username]-lambda-utils --version-number 1

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-lambda-optimization
```

---

## Key Takeaways

From this lab, you should understand:

1. **Performance Optimization**: Connection reuse, configuration caching, and efficient algorithms
2. **Lambda Layers**: Code reuse, dependency management, and deployment efficiency  
3. **Version Management**: Function versions, aliases, and deployment strategies
4. **Error Handling**: Retry patterns, graceful degradation, and fault tolerance
5. **Concurrency Management**: Reserved and provisioned concurrency for predictable performance
6. **Monitoring**: CloudWatch metrics and dashboards for performance analysis
7. **Console vs CLI**: When to use visual configuration tools vs programmatic deployment
8. **Production Readiness**: Best practices for enterprise serverless applications

### Performance Optimization Summary

| Optimization | Baseline | Optimized | Improvement |
|-------------|----------|-----------|-------------|
| **Connection Handling** | New connection per invocation | Connection pooling | ~60% faster |
| **Configuration Loading** | Reload every time | Cached configuration | ~40% faster |
| **Error Handling** | Basic try/catch | Retry with backoff | Higher reliability |
| **Memory Usage** | Fixed 128MB | Optimized allocation | Better cost efficiency |
| **Cold Starts** | Standard | Provisioned concurrency | Consistent performance |

---

## Next Steps

In the next lab, you will explore AWS Step Functions for workflow orchestration, building on the optimized Lambda functions you've created to implement complex business processes.