# Developing Serverless Solutions on AWS - Day 1 - Lab 4
## Queue and Stream Processing

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will implement reliable message processing patterns using Amazon SQS queues and Amazon Kinesis Data Streams. You'll build systems that handle message ordering, retry logic, dead letter queues, and real-time stream processing, demonstrating different approaches to event processing in serverless architectures.

## Lab Objectives

By the end of this lab, you will be able to:
- Configure Amazon SQS queues with dead letter queues for reliable message processing
- Implement Amazon Kinesis Data Streams for real-time data processing
- Understand the differences between queue and stream processing patterns
- Configure Lambda functions to process messages from both SQS and Kinesis
- Implement error handling and retry mechanisms
- Monitor queue and stream processing metrics
- Apply username prefixing to messaging resources

## Prerequisites

- Completion of Labs 1, 2, and 3
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of message processing concepts

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Messaging
**IMPORTANT:** All messaging resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- SQS queue: `user3-order-processing-queue`
- Dead letter queue: `user3-order-dlq`
- Kinesis stream: `user3-analytics-stream`
- Lambda functions: `user3-queue-processor`, `user3-stream-processor`

---

## Task 1: Implement SQS Queue Processing

### Step 1.1: Create SQS Queues

1. Create the main processing queue:
```bash
aws sqs create-queue \
  --queue-name "[your-username]-order-processing-queue" \
  --attributes '{
    "VisibilityTimeoutSeconds": "300",
    "MessageRetentionPeriod": "1209600",
    "DelaySeconds": "0",
    "ReceiveMessageWaitTimeSeconds": "20"
  }'
```

2. Create dead letter queue:
```bash
aws sqs create-queue \
  --queue-name "[your-username]-order-dlq" \
  --attributes '{
    "MessageRetentionPeriod": "1209600"
  }'
```

3. Get queue URLs and ARNs:
```bash
# Get main queue details
aws sqs get-queue-attributes \
  --queue-url "https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-processing-queue" \
  --attribute-names All

# Get DLQ details
aws sqs get-queue-attributes \
  --queue-url "https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-dlq" \
  --attribute-names All
```

4. Configure dead letter queue policy on main queue:
```bash
aws sqs set-queue-attributes \
  --queue-url "https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-processing-queue" \
  --attributes '{
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:us-east-1:[ACCOUNT-ID]:[your-username]-order-dlq\",\"maxReceiveCount\":3}"
  }'
```

### Step 1.2: Create SQS Message Producer

1. Create directory for SQS producer:
```bash
mkdir ~/environment/[your-username]-sqs-producer
cd ~/environment/[your-username]-sqs-producer
```

2. Create `sqs_producer.py`:

```python
import json
import boto3
import datetime
import uuid
import os

# Initialize SQS client
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    """
    Produces messages to SQS queue for processing
    """
    
    # Extract request parameters
    body = json.loads(event.get('body', '{}'))
    message_type = body.get('messageType', 'OrderProcessing')
    batch_size = body.get('batchSize', 1)
    simulate_failure = body.get('simulateFailure', False)
    
    queue_url = os.environ['QUEUE_URL']
    messages_sent = []
    
    try:
        for i in range(batch_size):
            # Create message payload
            message_payload = {
                'messageId': str(uuid.uuid4()),
                'messageType': message_type,
                'timestamp': datetime.datetime.now().isoformat(),
                'batchIndex': i + 1,
                'totalBatch': batch_size,
                'simulateFailure': simulate_failure and (i == 0),  # First message fails if requested
                'orderData': {
                    'orderId': f'order-{uuid.uuid4().hex[:8]}',
                    'customerId': f'customer-{uuid.uuid4().hex[:8]}',
                    'amount': round(10.99 + (i * 10.50), 2),
                    'items': [
                        {
                            'productId': f'product-{uuid.uuid4().hex[:6]}',
                            'quantity': (i % 3) + 1,
                            'price': round(5.99 + (i * 2.25), 2)
                        }
                    ]
                }
            }
            
            # Send message to SQS
            response = sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(message_payload),
                MessageAttributes={
                    'MessageType': {
                        'StringValue': message_type,
                        'DataType': 'String'
                    },
                    'BatchIndex': {
                        'StringValue': str(i + 1),
                        'DataType': 'String'
                    }
                }
            )
            
            messages_sent.append({
                'messageId': response['MessageId'],
                'payload': message_payload
            })
            
            print(f"Sent message {i + 1}/{batch_size}: {response['MessageId']}")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': f'Successfully sent {len(messages_sent)} messages to queue',
                'messagesSent': len(messages_sent),
                'queueUrl': queue_url,
                'messages': messages_sent
            }, indent=2)
        }
        
    except Exception as e:
        print(f"Error sending messages: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Failed to send messages: {str(e)}'})
        }
```

### Step 1.3: Create SQS Message Processor

1. Create directory for SQS processor:
```bash
mkdir ~/environment/[your-username]-sqs-processor
cd ~/environment/[your-username]-sqs-processor
```

2. Create `sqs_processor.py`:

```python
import json
import boto3
import time
import random

def lambda_handler(event, context):
    """
    Processes messages from SQS queue with error handling
    """
    
    print(f"Processing {len(event['Records'])} messages from SQS")
    
    processed_messages = []
    failed_messages = []
    
    for record in event['Records']:
        try:
            # Extract message details
            message_id = record['messageId']
            receipt_handle = record['receiptHandle']
            message_body = json.loads(record['body'])
            
            print(f"Processing message: {message_id}")
            print(f"Message body: {json.dumps(message_body, indent=2)}")
            
            # Check if this message should simulate failure
            if message_body.get('simulateFailure', False):
                print(f"🚨 Simulating failure for message {message_id}")
                raise Exception("Simulated processing failure")
            
            # Extract order data
            order_data = message_body.get('orderData', {})
            order_id = order_data.get('orderId', 'unknown')
            customer_id = order_data.get('customerId', 'unknown')
            amount = order_data.get('amount', 0)
            
            # Simulate processing time
            processing_time = random.uniform(0.1, 0.5)
            time.sleep(processing_time)
            
            # Process the order
            print(f"📦 Processing order {order_id}")
            print(f"👤 Customer: {customer_id}")
            print(f"💰 Amount: ${amount}")
            print(f"⏱️ Processing time: {processing_time:.2f}s")
            
            # Simulate business logic
            if amount > 100:
                print(f"🔥 High-value order detected: ${amount}")
                print(f"🎁 Applying premium processing for order {order_id}")
            
            print(f"✅ Successfully processed order {order_id}")
            
            processed_messages.append({
                'messageId': message_id,
                'orderId': order_id,
                'status': 'processed',
                'processingTime': processing_time
            })
            
        except Exception as e:
            print(f"❌ Error processing message {message_id}: {str(e)}")
            
            # Record failed message details
            failed_messages.append({
                'messageId': message_id,
                'error': str(e),
                'body': record['body']
            })
            
            # Re-raise exception to trigger SQS retry mechanism
            raise e
    
    # Log processing summary
    print(f"📊 Processing Summary:")
    print(f"   ✅ Processed: {len(processed_messages)}")
    print(f"   ❌ Failed: {len(failed_messages)}")
    
    if failed_messages:
        print(f"⚠️ {len(failed_messages)} messages will be retried or sent to DLQ")
    
    return {
        'batchItemFailures': [
            {'itemIdentifier': msg['messageId']} for msg in failed_messages
        ]
    }
```

### Step 1.4: Deploy SQS Components

1. Create IAM policy for SQS access:
```bash
cat > sqs-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes"
            ],
            "Resource": "*"
        }
    ]
}
EOF
```

2. Create IAM role:
```bash
aws iam create-role \
  --role-name [your-username]-sqs-lambda-role \
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

aws iam attach-role-policy \
  --role-name [your-username]-sqs-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
  --role-name [your-username]-sqs-lambda-role \
  --policy-name SQSAccess \
  --policy-document file://sqs-policy.json
```

3. Deploy SQS producer:
```bash
cd ~/environment/[your-username]-sqs-producer
zip sqs-producer.zip sqs_producer.py

aws lambda create-function \
  --function-name [your-username]-sqs-producer \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-sqs-lambda-role \
  --handler sqs_producer.lambda_handler \
  --zip-file fileb://sqs-producer.zip \
  --environment Variables='{QUEUE_URL="https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-processing-queue"}' \
  --timeout 60
```

4. Deploy SQS processor:
```bash
cd ~/environment/[your-username]-sqs-processor
zip sqs-processor.zip sqs_processor.py

aws lambda create-function \
  --function-name [your-username]-sqs-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-sqs-lambda-role \
  --handler sqs_processor.lambda_handler \
  --zip-file fileb://sqs-processor.zip \
  --timeout 60 \
  --reserved-concurrency 5
```

### Step 1.5: Configure SQS Event Source Mapping

1. Create event source mapping:
```bash
aws lambda create-event-source-mapping \
  --function-name [your-username]-sqs-processor \
  --event-source-arn arn:aws:sqs:us-east-1:[ACCOUNT-ID]:[your-username]-order-processing-queue \
  --batch-size 5 \
  --maximum-batching-window-in-seconds 5 \
  --function-response-types ReportBatchItemFailures
```

### Step 1.6: Create API Gateway for SQS Producer

1. Create REST API for SQS producer:
```bash
aws apigateway create-rest-api \
  --name "[your-username]-sqs-producer-api" \
  --description "API for sending messages to SQS"
```

2. Follow similar steps from previous labs to create resources, methods, and deploy the API (use same pattern as Lab 3).

---

## Task 2: Implement Kinesis Stream Processing

### Step 2.1: Create Kinesis Data Stream

1. Create Kinesis stream:
```bash
aws kinesis create-stream \
  --stream-name "[your-username]-analytics-stream" \
  --shard-count 2
```

2. Wait for stream to become active:
```bash
aws kinesis describe-stream \
  --stream-name "[your-username]-analytics-stream"
```

### Step 2.2: Create Kinesis Data Producer

1. Create directory for Kinesis producer:
```bash
mkdir ~/environment/[your-username]-kinesis-producer
cd ~/environment/[your-username]-kinesis-producer
```

2. Create `kinesis_producer.py`:

```python
import json
import boto3
import datetime
import uuid
import os
import random

# Initialize Kinesis client
kinesis = boto3.client('kinesis')

def lambda_handler(event, context):
    """
    Produces streaming data to Kinesis for real-time analytics
    """
    
    # Extract request parameters
    body = json.loads(event.get('body', '{}'))
    event_count = body.get('eventCount', 10)
    event_type = body.get('eventType', 'user_activity')
    
    stream_name = os.environ['STREAM_NAME']
    records_sent = []
    
    try:
        # Generate multiple events for stream processing
        for i in range(event_count):
            # Create different types of analytics events
            if event_type == 'user_activity':
                event_data = {
                    'eventId': str(uuid.uuid4()),
                    'eventType': 'user_activity',
                    'userId': f'user-{random.randint(1000, 9999)}',
                    'sessionId': f'session-{uuid.uuid4().hex[:8]}',
                    'action': random.choice(['page_view', 'click', 'search', 'purchase', 'add_to_cart']),
                    'page': random.choice(['/home', '/products', '/cart', '/checkout', '/profile']),
                    'timestamp': datetime.datetime.now().isoformat(),
                    'metadata': {
                        'userAgent': 'Mozilla/5.0 (compatible analytics)',
                        'ip': f'192.168.{random.randint(1, 255)}.{random.randint(1, 255)}',
                        'country': random.choice(['US', 'CA', 'UK', 'DE', 'FR']),
                        'device': random.choice(['desktop', 'mobile', 'tablet'])
                    }
                }
            elif event_type == 'transaction':
                event_data = {
                    'eventId': str(uuid.uuid4()),
                    'eventType': 'transaction',
                    'transactionId': f'txn-{uuid.uuid4().hex[:8]}',
                    'customerId': f'customer-{random.randint(1000, 9999)}',
                    'amount': round(random.uniform(10.0, 500.0), 2),
                    'currency': 'USD',
                    'status': random.choice(['completed', 'pending', 'failed']),
                    'timestamp': datetime.datetime.now().isoformat(),
                    'paymentMethod': random.choice(['credit_card', 'paypal', 'bank_transfer'])
                }
            else:
                event_data = {
                    'eventId': str(uuid.uuid4()),
                    'eventType': 'system_metric',
                    'metricName': random.choice(['cpu_usage', 'memory_usage', 'disk_io', 'network_io']),
                    'value': round(random.uniform(0.1, 100.0), 2),
                    'unit': random.choice(['percent', 'bytes', 'count']),
                    'source': f'server-{random.randint(1, 10)}',
                    'timestamp': datetime.datetime.now().isoformat()
                }
            
            # Send record to Kinesis
            response = kinesis.put_record(
                StreamName=stream_name,
                Data=json.dumps(event_data),
                PartitionKey=event_data.get('userId', event_data.get('customerId', str(uuid.uuid4())))
            )
            
            records_sent.append({
                'sequenceNumber': response['SequenceNumber'],
                'shardId': response['ShardId'],
                'eventData': event_data
            })
            
            print(f"Sent record {i + 1}/{event_count} to shard {response['ShardId']}")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': f'Successfully sent {len(records_sent)} records to Kinesis stream',
                'recordsSent': len(records_sent),
                'streamName': stream_name,
                'records': records_sent[:5]  # Show first 5 for brevity
            }, indent=2)
        }
        
    except Exception as e:
        print(f"Error sending records: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Failed to send records: {str(e)}'})
        }
```

### Step 2.3: Create Kinesis Stream Processor

1. Create directory for Kinesis processor:
```bash
mkdir ~/environment/[your-username]-kinesis-processor
cd ~/environment/[your-username]-kinesis-processor
```

2. Create `kinesis_processor.py`:

```python
import json
import base64
import boto3
from collections import defaultdict
import datetime

def lambda_handler(event, context):
    """
    Processes streaming data from Kinesis for real-time analytics
    """
    
    print(f"Processing {len(event['Records'])} records from Kinesis stream")
    
    # Analytics aggregations
    analytics = {
        'user_activities': defaultdict(int),
        'transactions': {
            'total_amount': 0,
            'transaction_count': 0,
            'status_counts': defaultdict(int),
            'payment_methods': defaultdict(int)
        },
        'system_metrics': defaultdict(list),
        'countries': defaultdict(int),
        'devices': defaultdict(int)
    }
    
    processed_records = []
    
    for record in event['Records']:
        try:
            # Decode Kinesis record
            payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
            data = json.loads(payload)
            
            event_type = data.get('eventType', 'unknown')
            
            print(f"Processing {event_type} event: {data.get('eventId', 'unknown')}")
            
            # Process based on event type
            if event_type == 'user_activity':
                action = data.get('action', 'unknown')
                analytics['user_activities'][action] += 1
                
                # Track country and device analytics
                country = data.get('metadata', {}).get('country', 'unknown')
                device = data.get('metadata', {}).get('device', 'unknown')
                analytics['countries'][country] += 1
                analytics['devices'][device] += 1
                
                print(f"📊 User activity: {action} from {country} on {device}")
                
            elif event_type == 'transaction':
                amount = data.get('amount', 0)
                status = data.get('status', 'unknown')
                payment_method = data.get('paymentMethod', 'unknown')
                
                analytics['transactions']['total_amount'] += amount
                analytics['transactions']['transaction_count'] += 1
                analytics['transactions']['status_counts'][status] += 1
                analytics['transactions']['payment_methods'][payment_method] += 1
                
                print(f"💳 Transaction: ${amount} via {payment_method} - {status}")
                
            elif event_type == 'system_metric':
                metric_name = data.get('metricName', 'unknown')
                value = data.get('value', 0)
                source = data.get('source', 'unknown')
                
                analytics['system_metrics'][metric_name].append({
                    'value': value,
                    'source': source,
                    'timestamp': data.get('timestamp')
                })
                
                print(f"📈 System metric: {metric_name} = {value} from {source}")
            
            processed_records.append({
                'eventId': data.get('eventId'),
                'eventType': event_type,
                'sequenceNumber': record['kinesis']['sequenceNumber'],
                'partitionKey': record['kinesis']['partitionKey']
            })
            
        except Exception as e:
            print(f"❌ Error processing record: {str(e)}")
            print(f"   Record data: {record}")
            continue
    
    # Generate real-time analytics summary
    print("\n📊 REAL-TIME ANALYTICS SUMMARY:")
    print("=" * 50)
    
    if analytics['user_activities']:
        print("🔍 User Activities:")
        for action, count in analytics['user_activities'].items():
            print(f"   {action}: {count}")
    
    if analytics['transactions']['transaction_count'] > 0:
        trans = analytics['transactions']
        avg_amount = trans['total_amount'] / trans['transaction_count']
        print(f"\n💰 Transactions:")
        print(f"   Total: {trans['transaction_count']}")
        print(f"   Total Amount: ${trans['total_amount']:.2f}")
        print(f"   Average: ${avg_amount:.2f}")
        print(f"   By Status: {dict(trans['status_counts'])}")
    
    if analytics['countries']:
        print(f"\n🌍 Top Countries: {dict(analytics['countries'])}")
    
    if analytics['devices']:
        print(f"📱 Device Types: {dict(analytics['devices'])}")
    
    if analytics['system_metrics']:
        print(f"\n📈 System Metrics Received:")
        for metric, values in analytics['system_metrics'].items():
            avg_value = sum(v['value'] for v in values) / len(values)
            print(f"   {metric}: {len(values)} samples, avg = {avg_value:.2f}")
    
    print("=" * 50)
    print(f"✅ Processed {len(processed_records)} records successfully")
    
    return {
        'records': [
            {
                'recordId': record['kinesis']['sequenceNumber'],
                'result': 'Ok'
            } for record in event['Records']
        ]
    }
```

### Step 2.4: Deploy Kinesis Components

1. Create IAM policy for Kinesis access:
```bash
cat > kinesis-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:PutRecord",
                "kinesis:PutRecords",
                "kinesis:GetRecords",
                "kinesis:GetShardIterator",
                "kinesis:DescribeStream",
                "kinesis:ListStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOF
```

2. Update IAM role with Kinesis permissions:
```bash
aws iam put-role-policy \
  --role-name [your-username]-sqs-lambda-role \
  --policy-name KinesisAccess \
  --policy-document file://kinesis-policy.json
```

3. Deploy Kinesis producer:
```bash
cd ~/environment/[your-username]-kinesis-producer
zip kinesis-producer.zip kinesis_producer.py

aws lambda create-function \
  --function-name [your-username]-kinesis-producer \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-sqs-lambda-role \
  --handler kinesis_producer.lambda_handler \
  --zip-file fileb://kinesis-producer.zip \
  --environment Variables='{STREAM_NAME="[your-username]-analytics-stream"}' \
  --timeout 60
```

4. Deploy Kinesis processor:
```bash
cd ~/environment/[your-username]-kinesis-processor
zip kinesis-processor.zip kinesis_processor.py

aws lambda create-function \
  --function-name [your-username]-kinesis-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-sqs-lambda-role \
  --handler kinesis_processor.lambda_handler \
  --zip-file fileb://kinesis-processor.zip \
  --timeout 300
```

### Step 2.5: Configure Kinesis Event Source Mapping

1. Create event source mapping for Kinesis:
```bash
aws lambda create-event-source-mapping \
  --function-name [your-username]-kinesis-processor \
  --event-source-arn arn:aws:kinesis:us-east-1:[ACCOUNT-ID]:stream/[your-username]-analytics-stream \
  --starting-position LATEST \
  --batch-size 10 \
  --maximum-batching-window-in-seconds 5
```

---

## Task 3: Test Queue and Stream Processing

### Step 3.1: Test SQS Processing

1. Test successful message processing:
```bash
curl -X POST "https://[your-sqs-api-id].execute-api.us-east-1.amazonaws.com/prod/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "messageType": "OrderProcessing",
    "batchSize": 3,
    "simulateFailure": false
  }'
```

2. Test message failure and DLQ:
```bash
curl -X POST "https://[your-sqs-api-id].execute-api.us-east-1.amazonaws.com/prod/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "messageType": "OrderProcessing",
    "batchSize": 2,
    "simulateFailure": true
  }'
```

3. Check DLQ for failed messages:
```bash
aws sqs receive-message \
  --queue-url "https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-dlq" \
  --max-number-of-messages 10
```

### Step 3.2: Test Kinesis Stream Processing

1. Test user activity stream:
```bash
curl -X POST "https://[your-kinesis-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "user_activity",
    "eventCount": 15
  }'
```

2. Test transaction stream:
```bash
curl -X POST "https://[your-kinesis-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "transaction",
    "eventCount": 8
  }'
```

3. Test system metrics stream:
```bash
curl -X POST "https://[your-kinesis-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "system_metric",
    "eventCount": 12
  }'
```

### Step 3.3: Monitor Processing Metrics

1. Check SQS metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS \
  --metric-name NumberOfMessagesSent \
  --dimensions Name=QueueName,Value=[your-username]-order-processing-queue \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

2. Check Kinesis metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis \
  --metric-name IncomingRecords \
  --dimensions Name=StreamName,Value=[your-username]-analytics-stream \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

3. Check Lambda function logs:
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/[your-username]
```

---

## Task 4: Compare Queue vs Stream Processing

### Step 4.1: Performance Comparison

1. Send high-volume messages to both systems and compare:
```bash
# Send 50 messages to SQS
curl -X POST "https://[your-sqs-api-id].execute-api.us-east-1.amazonaws.com/prod/messages" \
  -H "Content-Type: application/json" \
  -d '{"messageType": "OrderProcessing", "batchSize": 50}'

# Send 50 records to Kinesis
curl -X POST "https://[your-kinesis-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{"eventType": "user_activity", "eventCount": 50}'
```

2. Observe processing patterns in CloudWatch logs.

### Step 4.2: Error Handling Comparison

1. Test SQS retry behavior:
```bash
curl -X POST "https://[your-sqs-api-id].execute-api.us-east-1.amazonaws.com/prod/messages" \
  -H "Content-Type: application/json" \
  -d '{"messageType": "OrderProcessing", "batchSize": 5, "simulateFailure": true}'
```

2. Monitor retry attempts and DLQ behavior.

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created SQS queues with dead letter queue configuration
- [ ] Deployed SQS producer and processor Lambda functions
- [ ] Configured SQS event source mapping with batch item failures
- [ ] Created Kinesis Data Stream with multiple shards
- [ ] Deployed Kinesis producer and processor Lambda functions
- [ ] Configured Kinesis event source mapping for real-time processing
- [ ] Successfully tested both queue and stream processing patterns
- [ ] Observed retry mechanisms and error handling differences
- [ ] Monitored processing metrics in CloudWatch

### Expected Results

Your queue and stream processing systems should:
1. Process SQS messages reliably with retry and DLQ handling
2. Process Kinesis streams in real-time with aggregated analytics
3. Handle failures differently (retry vs. continue processing)
4. Show different processing patterns (batch vs. streaming)
5. Demonstrate ordering guarantees (SQS FIFO vs. Kinesis partition-based)
6. Provide monitoring and observability through CloudWatch

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** SQS messages not being processed
- **Solution:** Check event source mapping configuration
- Verify Lambda function permissions for SQS
- Check visibility timeout settings

**Issue:** Kinesis records not being processed
- **Solution:** Verify stream is active and has data
- Check shard-level metrics for throughput
- Ensure event source mapping is correctly configured

**Issue:** DLQ not receiving failed messages
- **Solution:** Verify redrive policy configuration
- Check maxReceiveCount setting
- Ensure DLQ exists and is accessible

**Issue:** Lambda timeouts during processing
- **Solution:** Increase Lambda timeout settings
- Reduce batch size for processing
- Optimize processing logic for efficiency

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-sqs-producer
aws lambda delete-function --function-name [your-username]-sqs-processor
aws lambda delete-function --function-name [your-username]-kinesis-producer
aws lambda delete-function --function-name [your-username]-kinesis-processor

# Delete SQS queues
aws sqs delete-queue --queue-url "https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-processing-queue"
aws sqs delete-queue --queue-url "https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-dlq"

# Delete Kinesis stream
aws kinesis delete-stream --stream-name [your-username]-analytics-stream

# Delete IAM role and policies
aws iam delete-role-policy --role-name [your-username]-sqs-lambda-role --policy-name SQSAccess
aws iam delete-role-policy --role-name [your-username]-sqs-lambda-role --policy-name KinesisAccess
aws iam detach-role-policy --role-name [your-username]-sqs-lambda-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name [your-username]-sqs-lambda-role
```

---

## Key Takeaways

From this lab, you should understand:
1. **Queue vs Stream Processing:** Different use cases and processing patterns
2. **Reliability Patterns:** Retry mechanisms, dead letter queues, and error handling
3. **Scalability Considerations:** Batch processing vs. real-time streaming
4. **Ordering Guarantees:** How SQS and Kinesis handle message ordering
5. **Event Source Mappings:** Configuration and tuning for different workloads
6. **Monitoring and Observability:** CloudWatch metrics for queue and stream processing

---

## Next Steps

This completes Day 1 of the course. In Day 2, you will explore Lambda function optimization, workflow orchestration with Step Functions, and comprehensive monitoring and observability patterns.