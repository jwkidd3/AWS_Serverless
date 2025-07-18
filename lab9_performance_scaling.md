# Developing Serverless Solutions on AWS - Day 3 - Lab 9
## Performance and Scaling Optimization

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will implement performance optimization and scaling strategies for serverless applications. You'll configure Lambda concurrency management, optimize API Gateway performance, implement caching strategies, and design applications to handle high-scale production workloads efficiently.

## Lab Objectives

By the end of this lab, you will be able to:
- Configure Lambda concurrency settings for optimal performance
- Implement API Gateway caching and throttling strategies
- Design auto-scaling patterns for serverless applications
- Optimize cold start performance and memory allocation
- Implement connection pooling and resource optimization
- Configure event source scaling for high-throughput scenarios
- Monitor and analyze performance metrics for scaling decisions
- Apply username prefixing to scaling resources

## Prerequisites

- Completion of Labs 1-8
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of Lambda performance characteristics

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Scaling Resources
**IMPORTANT:** All scaling resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- Lambda functions: `user3-high-performance-function`
- API Gateway: `user3-optimized-api`
- CloudWatch dashboards: `user3-performance-dashboard`

---

## Task 1: Create High-Performance Lambda Function

### Step 1.1: Create Optimized Function with Connection Pooling

1. Create directory for performance function:
```bash
mkdir ~/environment/[your-username]-performance-function
cd ~/environment/[your-username]-performance-function
```

2. Create `performance_function.py`:

```python
import json
import time
import os
import asyncio
import concurrent.futures
from datetime import datetime
import boto3
from botocore.config import Config

# Configure boto3 with connection pooling
config = Config(
    region_name='us-east-1',
    retries={
        'max_attempts': 3,
        'mode': 'adaptive'
    },
    max_pool_connections=50
)

# Initialize clients outside handler for reuse
dynamodb = boto3.resource('dynamodb', config=config)
s3_client = boto3.client('s3', config=config)
cloudwatch = boto3.client('cloudwatch', config=config)

# Global connection pool for external services
connection_pool = {}

def get_connection_pool():
    """Get or create connection pool for external services"""
    if 'http_session' not in connection_pool:
        import requests
        session = requests.Session()
        session.headers.update({'User-Agent': 'HighPerformanceLambda/1.0'})
        
        # Configure connection pooling
        adapter = requests.adapters.HTTPAdapter(
            pool_connections=20,
            pool_maxsize=20,
            max_retries=3
        )
        session.mount('http://', adapter)
        session.mount('https://', adapter)
        
        connection_pool['http_session'] = session
    
    return connection_pool['http_session']

def put_custom_metric(metric_name, value, unit='Count', dimensions=None):
    """Publish custom metrics for performance monitoring"""
    if dimensions is None:
        dimensions = {}
    
    # Use EMF format for zero-latency metrics
    emf_log = {
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": "HighPerformance",
                    "Dimensions": [list(dimensions.keys())] if dimensions else [[]],
                    "Metrics": [{"Name": metric_name, "Unit": unit}]
                }
            ]
        },
        metric_name: value
    }
    emf_log.update(dimensions)
    print(json.dumps(emf_log))

def lambda_handler(event, context):
    """
    High-performance Lambda function with optimizations
    """
    
    start_time = time.time()
    
    # Mark cold start
    is_cold_start = not hasattr(lambda_handler, 'initialized')
    if is_cold_start:
        lambda_handler.initialized = True
        put_custom_metric('ColdStarts', 1, 'Count', {
            'FunctionName': context.function_name
        })
    
    try:
        # Extract request parameters
        body = event.get('body', '{}')
        if isinstance(body, str):
            body = json.loads(body)
        
        operation = body.get('operation', 'default')
        concurrency_level = body.get('concurrency', 1)
        data_size = body.get('dataSize', 'small')
        
        # Performance monitoring dimensions
        dimensions = {
            'FunctionName': context.function_name,
            'Operation': operation,
            'ColdStart': str(is_cold_start),
            'MemorySize': str(context.memory_limit_in_mb)
        }
        
        # Route to appropriate handler based on operation
        if operation == 'concurrent_processing':
            result = handle_concurrent_processing(concurrency_level, dimensions)
        elif operation == 'database_batch':
            result = handle_database_batch_operations(data_size, dimensions)
        elif operation == 'stream_processing':
            result = handle_stream_processing(body.get('records', []), dimensions)
        elif operation == 'cpu_intensive':
            result = handle_cpu_intensive_task(body.get('iterations', 1000), dimensions)
        elif operation == 'memory_test':
            result = handle_memory_optimization_test(data_size, dimensions)
        else:
            result = handle_default_operation(dimensions)
        
        # Calculate execution metrics
        execution_time = (time.time() - start_time) * 1000
        remaining_time = context.get_remaining_time_in_millis()
        
        # Publish performance metrics
        put_custom_metric('ExecutionTime', execution_time, 'Milliseconds', dimensions)
        put_custom_metric('RemainingTime', remaining_time, 'Milliseconds', dimensions)
        put_custom_metric('MemoryUtilization', get_memory_usage(), 'Percent', dimensions)
        
        response = {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'result': result,
                'performance': {
                    'execution_time_ms': execution_time,
                    'remaining_time_ms': remaining_time,
                    'cold_start': is_cold_start,
                    'memory_limit_mb': context.memory_limit_in_mb
                }
            })
        }
        
        # Log success metric
        put_custom_metric('SuccessfulInvocations', 1, 'Count', dimensions)
        
        return response
        
    except Exception as e:
        # Log error metrics
        error_dimensions = dimensions.copy()
        error_dimensions['ErrorType'] = type(e).__name__
        put_custom_metric('Errors', 1, 'Count', error_dimensions)
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': str(e),
                'execution_time_ms': (time.time() - start_time) * 1000
            })
        }

def handle_concurrent_processing(concurrency_level, dimensions):
    """Handle concurrent processing with thread pool"""
    
    start_time = time.time()
    
    def worker_task(task_id):
        """Simulate concurrent work"""
        time.sleep(0.1)  # Simulate I/O operation
        return {
            'task_id': task_id,
            'result': f'Task {task_id} completed',
            'worker_time': time.time()
        }
    
    # Use ThreadPoolExecutor for concurrent processing
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(concurrency_level, 10)) as executor:
        futures = [executor.submit(worker_task, i) for i in range(concurrency_level)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    
    processing_time = (time.time() - start_time) * 1000
    put_custom_metric('ConcurrentProcessingTime', processing_time, 'Milliseconds', dimensions)
    
    return {
        'operation': 'concurrent_processing',
        'concurrency_level': concurrency_level,
        'tasks_completed': len(results),
        'processing_time_ms': processing_time,
        'results': results[:3]  # Return first 3 for brevity
    }

def handle_database_batch_operations(data_size, dimensions):
    """Handle batch database operations"""
    
    start_time = time.time()
    
    # Simulate batch sizes based on data_size parameter
    batch_sizes = {
        'small': 10,
        'medium': 100,
        'large': 1000
    }
    
    batch_size = batch_sizes.get(data_size, 10)
    
    # Simulate batch processing
    batch_results = []
    for batch_num in range(3):  # Process 3 batches
        batch_start = time.time()
        
        # Simulate batch database operation
        time.sleep(0.05 * batch_size / 100)  # Scale sleep with batch size
        
        batch_time = (time.time() - batch_start) * 1000
        batch_results.append({
            'batch_id': batch_num,
            'records_processed': batch_size,
            'batch_time_ms': batch_time
        })
    
    total_time = (time.time() - start_time) * 1000
    put_custom_metric('BatchProcessingTime', total_time, 'Milliseconds', dimensions)
    put_custom_metric('RecordsProcessed', batch_size * 3, 'Count', dimensions)
    
    return {
        'operation': 'database_batch',
        'data_size': data_size,
        'total_records': batch_size * 3,
        'total_time_ms': total_time,
        'batches': batch_results
    }

def handle_stream_processing(records, dimensions):
    """Handle stream processing with optimizations"""
    
    start_time = time.time()
    
    # Process records in chunks for efficiency
    chunk_size = 50
    processed_chunks = []
    
    for i in range(0, len(records), chunk_size):
        chunk = records[i:i + chunk_size]
        chunk_start = time.time()
        
        # Simulate processing each record in the chunk
        processed_records = []
        for record in chunk:
            processed_records.append({
                'record_id': record.get('id', f'record-{i}'),
                'processed_at': time.time(),
                'status': 'processed'
            })
        
        chunk_time = (time.time() - chunk_start) * 1000
        processed_chunks.append({
            'chunk_index': len(processed_chunks),
            'records_in_chunk': len(chunk),
            'processing_time_ms': chunk_time
        })
    
    total_time = (time.time() - start_time) * 1000
    put_custom_metric('StreamProcessingTime', total_time, 'Milliseconds', dimensions)
    put_custom_metric('StreamRecordsProcessed', len(records), 'Count', dimensions)
    
    return {
        'operation': 'stream_processing',
        'total_records': len(records),
        'chunks_processed': len(processed_chunks),
        'total_time_ms': total_time,
        'throughput_records_per_sec': len(records) / (total_time / 1000) if total_time > 0 else 0
    }

def handle_cpu_intensive_task(iterations, dimensions):
    """Handle CPU-intensive operations"""
    
    start_time = time.time()
    
    # CPU-intensive calculation
    result = 0
    for i in range(iterations):
        result += i * i
    
    cpu_time = (time.time() - start_time) * 1000
    put_custom_metric('CPUIntensiveTime', cpu_time, 'Milliseconds', dimensions)
    
    return {
        'operation': 'cpu_intensive',
        'iterations': iterations,
        'result': result,
        'cpu_time_ms': cpu_time,
        'operations_per_second': iterations / (cpu_time / 1000) if cpu_time > 0 else 0
    }

def handle_memory_optimization_test(data_size, dimensions):
    """Test memory usage patterns"""
    
    start_time = time.time()
    
    # Memory allocation based on data size
    memory_allocations = {
        'small': 1000,
        'medium': 10000,
        'large': 100000
    }
    
    allocation_size = memory_allocations.get(data_size, 1000)
    
    # Allocate and process data
    data_list = [i for i in range(allocation_size)]
    processed_data = [x * 2 for x in data_list if x % 2 == 0]
    
    # Clean up explicitly
    del data_list
    
    processing_time = (time.time() - start_time) * 1000
    put_custom_metric('MemoryTestTime', processing_time, 'Milliseconds', dimensions)
    
    return {
        'operation': 'memory_test',
        'data_size': data_size,
        'items_allocated': allocation_size,
        'items_processed': len(processed_data),
        'processing_time_ms': processing_time
    }

def handle_default_operation(dimensions):
    """Handle default lightweight operation"""
    
    start_time = time.time()
    
    # Lightweight operation
    session = get_connection_pool()
    
    # Simulate external API call
    try:
        response = session.get('https://httpbin.org/uuid', timeout=2)
        external_data = response.json() if response.status_code == 200 else {'uuid': 'fallback'}
    except:
        external_data = {'uuid': 'fallback'}
    
    processing_time = (time.time() - start_time) * 1000
    put_custom_metric('DefaultOperationTime', processing_time, 'Milliseconds', dimensions)
    
    return {
        'operation': 'default',
        'external_data': external_data,
        'processing_time_ms': processing_time
    }

def get_memory_usage():
    """Get approximate memory usage percentage"""
    try:
        import psutil
        return psutil.virtual_memory().percent
    except:
        # Fallback calculation
        import os
        import resource
        memory_usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        # Convert to approximate percentage (rough estimation)
        return min(100, (memory_usage / 1024 / 1024) * 10)  # Very rough estimate
```

3. Create requirements.txt:
```bash
cat > requirements.txt << 'EOF'
requests==2.28.1
psutil==5.9.4
EOF
```

4. Install dependencies and deploy:
```bash
pip install -r requirements.txt -t .
zip -r performance-function.zip .

aws lambda create-function \
  --function-name [your-username]-performance-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler performance_function.lambda_handler \
  --zip-file fileb://performance-function.zip \
  --timeout 300 \
  --memory-size 1024 \
  --description "High-performance function with scaling optimizations"
```

---

## Task 2: Configure Lambda Concurrency Settings

### Step 2.1: Set Reserved and Provisioned Concurrency

1. Configure reserved concurrency:
```bash
aws lambda put-reserved-concurrency \
  --function-name [your-username]-performance-function \
  --reserved-concurrent-executions 50
```

2. Publish a version for provisioned concurrency:
```bash
aws lambda publish-version \
  --function-name [your-username]-performance-function \
  --description "Performance optimized version"
```

3. Create alias for production:
```bash
aws lambda create-alias \
  --function-name [your-username]-performance-function \
  --name prod \
  --function-version 1 \
  --description "Production alias for performance function"
```

4. Configure provisioned concurrency:
```bash
aws lambda put-provisioned-concurrency-config \
  --function-name [your-username]-performance-function \
  --qualifier prod \
  --provisioned-concurrency-config ProvisionedConcurrencyExecutions=10
```

### Step 2.2: Create Load Testing Function

1. Create directory for load testing:
```bash
mkdir ~/environment/[your-username]-load-tester
cd ~/environment/[your-username]-load-tester
```

2. Create `load_tester.py`:

```python
import json
import time
import concurrent.futures
import boto3
from datetime import datetime

lambda_client = boto3.client('lambda')

def lambda_handler(event, context):
    """
    Function to generate load for testing performance
    """
    
    body = json.loads(event.get('body', '{}'))
    
    # Load testing parameters
    concurrent_requests = body.get('concurrentRequests', 10)
    total_requests = body.get('totalRequests', 100)
    target_function = body.get('targetFunction', '[your-username]-performance-function')
    test_payload = body.get('testPayload', {'operation': 'default'})
    
    start_time = time.time()
    results = []
    errors = []
    
    def invoke_function(request_id):
        """Invoke target function and measure performance"""
        try:
            invoke_start = time.time()
            
            response = lambda_client.invoke(
                FunctionName=target_function,
                InvocationType='RequestResponse',
                Payload=json.dumps({
                    'body': json.dumps(test_payload)
                })
            )
            
            invoke_time = (time.time() - invoke_start) * 1000
            
            return {
                'request_id': request_id,
                'status_code': response['StatusCode'],
                'execution_time_ms': invoke_time,
                'success': True
            }
            
        except Exception as e:
            return {
                'request_id': request_id,
                'error': str(e),
                'success': False
            }
    
    # Execute load test with controlled concurrency
    completed_requests = 0
    
    while completed_requests < total_requests:
        batch_size = min(concurrent_requests, total_requests - completed_requests)
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=batch_size) as executor:
            futures = [
                executor.submit(invoke_function, completed_requests + i) 
                for i in range(batch_size)
            ]
            
            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if result['success']:
                    results.append(result)
                else:
                    errors.append(result)
        
        completed_requests += batch_size
        
        # Small delay between batches to avoid overwhelming
        time.sleep(0.1)
    
    total_test_time = (time.time() - start_time) * 1000
    
    # Calculate statistics
    successful_requests = len(results)
    failed_requests = len(errors)
    
    if successful_requests > 0:
        execution_times = [r['execution_time_ms'] for r in results]
        avg_execution_time = sum(execution_times) / len(execution_times)
        min_execution_time = min(execution_times)
        max_execution_time = max(execution_times)
        p95_execution_time = sorted(execution_times)[int(len(execution_times) * 0.95)]
    else:
        avg_execution_time = min_execution_time = max_execution_time = p95_execution_time = 0
    
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'load_test_results': {
                'total_requests': total_requests,
                'successful_requests': successful_requests,
                'failed_requests': failed_requests,
                'success_rate': (successful_requests / total_requests) * 100,
                'total_test_time_ms': total_test_time,
                'requests_per_second': total_requests / (total_test_time / 1000),
                'performance_metrics': {
                    'avg_execution_time_ms': avg_execution_time,
                    'min_execution_time_ms': min_execution_time,
                    'max_execution_time_ms': max_execution_time,
                    'p95_execution_time_ms': p95_execution_time
                },
                'errors': errors[:5]  # Show first 5 errors
            }
        })
    }
```

3. Deploy load testing function:
```bash
zip load-tester.zip load_tester.py

aws lambda create-function \
  --function-name [your-username]-load-tester \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler load_tester.lambda_handler \
  --zip-file fileb://load-tester.zip \
  --timeout 900 \
  --memory-size 512 \
  --description "Load testing function for performance analysis"
```

---

## Task 3: Create Optimized API Gateway

### Step 3.1: Create API Gateway with Caching

1. Create API Gateway:
```bash
aws apigateway create-rest-api \
  --name "[your-username]-optimized-api" \
  --description "High-performance API with caching and throttling"
```

2. Get root resource and create performance resource:
```bash
aws apigateway get-resources --rest-api-id [your-api-id]

aws apigateway create-resource \
  --rest-api-id [your-api-id] \
  --parent-id [root-resource-id] \
  --path-part performance
```

3. Create POST method:
```bash
aws apigateway put-method \
  --rest-api-id [your-api-id] \
  --resource-id [performance-resource-id] \
  --http-method POST \
  --authorization-type NONE \
  --request-parameters method.request.header.X-Request-ID=false
```

4. Configure Lambda integration:
```bash
aws apigateway put-integration \
  --rest-api-id [your-api-id] \
  --resource-id [performance-resource-id] \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-performance-function:prod/invocations
```

5. Grant API Gateway permission:
```bash
aws lambda add-permission \
  --function-name [your-username]-performance-function:prod \
  --statement-id api-gateway-invoke-prod \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:[ACCOUNT-ID]:[your-api-id]/*/*"
```

6. Deploy API with caching enabled:
```bash
aws apigateway create-deployment \
  --rest-api-id [your-api-id] \
  --stage-name prod \
  --cache-cluster-enabled \
  --cache-cluster-size "0.5"
```

### Step 3.2: Configure API Gateway Throttling

1. Create usage plan with throttling:
```bash
aws apigateway create-usage-plan \
  --name "[your-username]-performance-plan" \
  --description "High-performance usage plan with throttling" \
  --throttle BurstLimit=1000,RateLimit=500 \
  --quota Limit=10000,Period=DAY \
  --api-stages apiId=[your-api-id],stage=prod
```

2. Create API key:
```bash
aws apigateway create-api-key \
  --name "[your-username]-performance-key" \
  --description "API key for performance testing" \
  --enabled
```

3. Associate API key with usage plan:
```bash
aws apigateway create-usage-plan-key \
  --usage-plan-id [usage-plan-id] \
  --key-id [api-key-id] \
  --key-type API_KEY
```

---

## Task 4: Performance Testing and Analysis

### Step 4.1: Run Performance Tests

1. Test default operation performance:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/performance" \
  -H "Content-Type: application/json" \
  -d '{"operation": "default"}' \
  | jq '.performance'
```

2. Test concurrent processing:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/performance" \
  -H "Content-Type: application/json" \
  -d '{"operation": "concurrent_processing", "concurrency": 10}' \
  | jq '.result'
```

3. Test database batch operations:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/performance" \
  -H "Content-Type: application/json" \
  -d '{"operation": "database_batch", "dataSize": "large"}' \
  | jq '.result'
```

4. Test CPU-intensive operations:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/performance" \
  -H "Content-Type: application/json" \
  -d '{"operation": "cpu_intensive", "iterations": 10000}' \
  | jq '.result'
```

### Step 4.2: Run Load Tests

1. Execute load test using the load tester function:
```bash
aws lambda invoke \
  --function-name [your-username]-load-tester \
  --payload '{
    "body": "{
      \"concurrentRequests\": 20,
      \"totalRequests\": 100,
      \"targetFunction\": \"[your-username]-performance-function:prod\",
      \"testPayload\": {\"operation\": \"default\"}
    }"
  }' \
  load-test-results.json

cat load-test-results.json | jq '.body | fromjson | .load_test_results'
```

2. Test with different memory configurations:
```bash
# Update memory to 512MB
aws lambda update-function-configuration \
  --function-name [your-username]-performance-function \
  --memory-size 512

# Run load test
aws lambda invoke \
  --function-name [your-username]-load-tester \
  --payload '{
    "body": "{
      \"concurrentRequests\": 10,
      \"totalRequests\": 50,
      \"targetFunction\": \"[your-username]-performance-function\",
      \"testPayload\": {\"operation\": \"cpu_intensive\", \"iterations\": 5000}
    }"
  }' \
  memory-512-results.json

# Update memory to 2048MB
aws lambda update-function-configuration \
  --function-name [your-username]-performance-function \
  --memory-size 2048

# Run load test again
aws lambda invoke \
  --function-name [your-username]-load-tester \
  --payload '{
    "body": "{
      \"concurrentRequests\": 10,
      \"totalRequests\": 50,
      \"targetFunction\": \"[your-username]-performance-function\",
      \"testPayload\": {\"operation\": \"cpu_intensive\", \"iterations\": 5000}
    }"
  }' \
  memory-2048-results.json

# Compare results
echo "512MB Results:"
cat memory-512-results.json | jq '.body | fromjson | .load_test_results.performance_metrics'
echo "2048MB Results:"
cat memory-2048-results.json | jq '.body | fromjson | .load_test_results.performance_metrics'
```

---

## Task 5: Event Source Scaling Configuration

### Step 5.1: Create High-Throughput SQS Queue

1. Create high-performance SQS queue:
```bash
aws sqs create-queue \
  --queue-name "[your-username]-high-throughput-queue" \
  --attributes '{
    "VisibilityTimeoutSeconds": "30",
    "MessageRetentionPeriod": "1209600",
    "ReceiveMessageWaitTimeSeconds": "0",
    "MaxReceiveCount": "3"
  }'
```

2. Create SQS processing function:
```bash
mkdir ~/environment/[your-username]-sqs-scaler
cd ~/environment/[your-username]-sqs-scaler

cat > sqs_scaler.py << 'EOF'
import json
import time
import boto3

def lambda_handler(event, context):
    """
    High-throughput SQS message processor
    """
    
    start_time = time.time()
    processed_count = 0
    
    for record in event['Records']:
        # Process each message
        message_body = json.loads(record['body'])
        
        # Simulate processing
        time.sleep(0.01)  # 10ms processing time per message
        processed_count += 1
        
        print(f"Processed message: {message_body.get('id', 'unknown')}")
    
    processing_time = (time.time() - start_time) * 1000
    
    return {
        'batchItemFailures': [],  # No failures for this demo
        'statistics': {
            'messages_processed': processed_count,
            'processing_time_ms': processing_time,
            'messages_per_second': processed_count / (processing_time / 1000) if processing_time > 0 else 0
        }
    }
EOF

zip sqs-scaler.zip sqs_scaler.py

aws lambda create-function \
  --function-name [your-username]-sqs-scaler \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler sqs_scaler.lambda_handler \
  --zip-file fileb://sqs-scaler.zip \
  --timeout 60 \
  --memory-size 256 \
  --reserved-concurrency 100 \
  --description "High-throughput SQS message processor"
```

3. Configure event source mapping with optimized settings:
```bash
aws lambda create-event-source-mapping \
  --function-name [your-username]-sqs-scaler \
  --event-source-arn arn:aws:sqs:us-east-1:[ACCOUNT-ID]:[your-username]-high-throughput-queue \
  --batch-size 10 \
  --maximum-batching-window-in-seconds 1 \
  --function-response-types ReportBatchItemFailures
```

### Step 5.2: Test SQS Scaling

1. Create message generator script:
```bash
cat > generate_sqs_load.sh << 'EOF'
#!/bin/bash

QUEUE_URL="https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-high-throughput-queue"
MESSAGE_COUNT=${1:-100}

echo "Sending $MESSAGE_COUNT messages to SQS queue..."

for i in $(seq 1 $MESSAGE_COUNT); do
    MESSAGE_BODY="{\"id\": \"msg-$i\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\", \"data\": \"Sample data for message $i\"}"
    
    aws sqs send-message \
      --queue-url "$QUEUE_URL" \
      --message-body "$MESSAGE_BODY" > /dev/null
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "Sent $i messages..."
    fi
done

echo "Completed sending $MESSAGE_COUNT messages"
EOF

chmod +x generate_sqs_load.sh
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" generate_sqs_load.sh
sed -i "s/\[your-username\]/[your-username]/g" generate_sqs_load.sh
```

2. Generate load and monitor scaling:
```bash
./generate_sqs_load.sh 500
```

---

## Task 6: Create Performance Dashboard

### Step 6.1: Build Comprehensive Performance Dashboard

1. Create performance dashboard:
```bash
cat > performance-dashboard.json << 'EOF'
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
                    [ "AWS/Lambda", "Duration", "FunctionName", "[your-username]-performance-function" ],
                    [ ".", ".", ".", "[your-username]-sqs-scaler" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Average Function Duration"
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
                    [ "AWS/Lambda", "ConcurrentExecutions", "FunctionName", "[your-username]-performance-function" ],
                    [ ".", ".", ".", "[your-username]-sqs-scaler" ]
                ],
                "period": 300,
                "stat": "Maximum",
                "region": "us-east-1",
                "title": "Concurrent Executions"
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
                    [ "AWS/Lambda", "Throttles", "FunctionName", "[your-username]-performance-function" ],
                    [ ".", "Errors", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Throttles and Errors"
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
                    [ "HighPerformance", "ExecutionTime", "FunctionName", "[your-username]-performance-function" ],
                    [ ".", "ColdStarts", ".", "." ],
                    [ ".", "SuccessfulInvocations", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Custom Performance Metrics"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 12,
            "width": 24,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApiGateway", "Count", "ApiName", "[your-username]-optimized-api" ],
                    [ ".", "Latency", ".", "." ],
                    [ ".", "4XXError", ".", "." ],
                    [ ".", "5XXError", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "API Gateway Performance Metrics"
            }
        }
    ]
}
EOF

sed -i "s/\[your-username\]/[your-username]/g" performance-dashboard.json

aws cloudwatch put-dashboard \
  --dashboard-name "[your-username]-performance-dashboard" \
  --dashboard-body file://performance-dashboard.json
```

---

## Task 7: Analyze Performance Results

### Step 7.1: Generate Performance Report

1. Create performance analysis script:
```bash
cat > analyze_performance.py << 'EOF'
import boto3
import json
from datetime import datetime, timedelta

cloudwatch = boto3.client('cloudwatch')

def get_metric_statistics(namespace, metric_name, dimensions, start_time, end_time):
    """Get CloudWatch metric statistics"""
    try:
        response = cloudwatch.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=dimensions,
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average', 'Maximum', 'Minimum']
        )
        return response['Datapoints']
    except Exception as e:
        print(f"Error getting metrics: {str(e)}")
        return []

def analyze_function_performance(function_name):
    """Analyze Lambda function performance"""
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=1)
    
    # Get Lambda metrics
    duration_data = get_metric_statistics(
        'AWS/Lambda', 'Duration',
        [{'Name': 'FunctionName', 'Value': function_name}],
        start_time, end_time
    )
    
    concurrent_executions = get_metric_statistics(
        'AWS/Lambda', 'ConcurrentExecutions',
        [{'Name': 'FunctionName', 'Value': function_name}],
        start_time, end_time
    )
    
    errors = get_metric_statistics(
        'AWS/Lambda', 'Errors',
        [{'Name': 'FunctionName', 'Value': function_name}],
        start_time, end_time
    )
    
    # Calculate statistics
    if duration_data:
        avg_duration = sum(dp['Average'] for dp in duration_data) / len(duration_data)
        max_duration = max(dp['Maximum'] for dp in duration_data)
        min_duration = min(dp['Minimum'] for dp in duration_data)
    else:
        avg_duration = max_duration = min_duration = 0
    
    max_concurrency = max(dp['Maximum'] for dp in concurrent_executions) if concurrent_executions else 0
    total_errors = sum(dp['Sum'] for dp in errors) if errors else 0
    
    return {
        'function_name': function_name,
        'avg_duration_ms': avg_duration,
        'max_duration_ms': max_duration,
        'min_duration_ms': min_duration,
        'max_concurrency': max_concurrency,
        'total_errors': total_errors,
        'analysis_period': '1 hour'
    }

if __name__ == "__main__":
    functions = [
        '[your-username]-performance-function',
        '[your-username]-sqs-scaler'
    ]
    
    print("Performance Analysis Report")
    print("=" * 50)
    
    for function in functions:
        analysis = analyze_function_performance(function)
        print(f"\nFunction: {analysis['function_name']}")
        print(f"Average Duration: {analysis['avg_duration_ms']:.2f} ms")
        print(f"Max Duration: {analysis['max_duration_ms']:.2f} ms")
        print(f"Min Duration: {analysis['min_duration_ms']:.2f} ms")
        print(f"Max Concurrency: {analysis['max_concurrency']}")
        print(f"Total Errors: {analysis['total_errors']}")
EOF

sed -i "s/\[your-username\]/[your-username]/g" analyze_performance.py

python3 analyze_performance.py
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created high-performance Lambda function with connection pooling
- [ ] Configured reserved and provisioned concurrency
- [ ] Created load testing function for performance analysis
- [ ] Built optimized API Gateway with caching and throttling
- [ ] Configured event source scaling for high-throughput processing
- [ ] Generated and analyzed performance test results
- [ ] Created comprehensive performance monitoring dashboard
- [ ] Applied username prefixing to all performance resources

### Expected Results

Your performance-optimized serverless application should:
1. Demonstrate improved response times with connection pooling
2. Handle concurrent requests efficiently with proper concurrency settings
3. Scale automatically based on demand
4. Provide detailed performance metrics and monitoring
5. Show measurable improvements in throughput and latency
6. Handle high-throughput event processing reliably

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** High cold start times
- **Solution:** Implement provisioned concurrency for predictable performance
- Optimize function initialization code
- Use appropriate memory allocation

**Issue:** Concurrent execution limits exceeded
- **Solution:** Configure reserved concurrency appropriately
- Monitor account-level concurrency limits
- Implement backpressure handling

**Issue:** API Gateway throttling
- **Solution:** Adjust usage plan limits and throttling settings
- Implement proper error handling for throttled requests
- Consider request batching strategies

**Issue:** Event source scaling issues
- **Solution:** Optimize batch size and polling configurations
- Monitor dead letter queues for failed messages
- Adjust function timeout and memory settings

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-performance-function
aws lambda delete-function --function-name [your-username]-load-tester
aws lambda delete-function --function-name [your-username]-sqs-scaler

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id [your-api-id]

# Delete SQS queue
aws sqs delete-queue --queue-url "https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-high-throughput-queue"

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-performance-dashboard
```

---

## Key Takeaways

From this lab, you should understand:
1. **Performance Optimization:** Connection pooling, memory management, and efficient algorithms
2. **Concurrency Management:** Reserved and provisioned concurrency for predictable performance
3. **API Optimization:** Caching, throttling, and usage plans for high-performance APIs
4. **Event Source Scaling:** Configuration strategies for high-throughput processing
5. **Performance Monitoring:** Metrics, dashboards, and analysis for optimization decisions
6. **Load Testing:** Strategies for validating performance under realistic conditions

---

## Next Steps

In the next lab, you will explore automated deployment pipelines and CI/CD best practices for serverless applications.