# Developing Serverless Solutions on AWS - Lab 4
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

## Task 1: Create SQS Queues (Console)

### Step 1.1: Create Dead Letter Queue

1. Navigate to **Amazon SQS** in the AWS Console
2. Click **Create queue**
3. Configure the dead letter queue:
   - **Type**: Standard
   - **Name**: `[your-username]-order-dlq`
   - **Visibility timeout**: 30 seconds (default)
   - **Message retention period**: 14 days
   - **Delivery delay**: 0 seconds
   - **Receive message wait time**: 0 seconds (default)
   - **Tags**: Add tag with Key: `Project`, Value: `ServerlessLab`
4. Click **Create queue**
5. **Copy the Queue ARN** from the Details tab for later use

### Step 1.2: Create Main Processing Queue with DLQ

1. Click **Create queue**
2. Configure the main processing queue:
   - **Type**: Standard  
   - **Name**: `[your-username]-order-processing-queue`
   - **Visibility timeout**: 300 seconds (5 minutes)
   - **Message retention period**: 14 days
   - **Delivery delay**: 0 seconds
   - **Receive message wait time**: 20 seconds (long polling)

3. Scroll down to **Dead Letter Queue** section:
   - **Enable**: Checked
   - **Choose queue**: Select `[your-username]-order-dlq`
   - **Maximum receives**: 3

4. **Access Policy** (Advanced):
   - Leave as default for this lab

5. **Tags**: Add tag with Key: `Project`, Value: `ServerlessLab`
6. Click **Create queue**
7. **Copy the Queue URL** from the Details tab for later use

### Step 1.3: Verify Queue Configuration (Console)

1. In the SQS console, click on your main queue: `[your-username]-order-processing-queue`
2. Click the **Dead Letter Queue** tab
3. Verify that your DLQ is configured with **Maximum receives: 3**
4. Click the **Monitoring** tab to see queue metrics (will be empty initially)

---

## Task 2: Create Kinesis Data Stream (Console)

### Step 2.1: Create Kinesis Stream

1. Navigate to **Amazon Kinesis** in the AWS Console
2. Click **Create data stream**
3. Configure the stream:
   - **Data stream name**: `[your-username]-analytics-stream`
   - **Capacity mode**: Provisioned
   - **Number of shards**: 2
   - **Data retention period**: 24 hours
   - **Server-side encryption**: Disabled (for lab simplicity)

4. **Tags**: Add tag with Key: `Project`, Value: `ServerlessLab`
5. Click **Create data stream**

### Step 2.2: Monitor Stream Creation

1. Wait for the stream status to change from **Creating** to **Active**
2. Click on your stream name to view details
3. Click the **Shards** tab to see the 2 shards created
4. Click the **Monitoring** tab to see stream metrics (will be empty initially)
5. **Copy the Stream ARN** from the Details tab for later use

---

## Task 3: Create IAM Role for Lambda Functions (Console)

### Step 3.1: Create Lambda Execution Role

1. Navigate to **IAM** in the AWS Console
2. Click **Roles** in the left navigation
3. Click **Create role**
4. Configure trust relationship:
   - **Trusted entity type**: AWS service
   - **Service**: Lambda
   - **Use case**: Lambda
5. Click **Next**

### Step 3.2: Attach Permissions Policies

1. Search and select the following managed policies:
   - `AWSLambdaBasicExecutionRole`
   - `AWSLambdaSQSQueueExecutionRole`
   - `AWSLambdaKinesisExecutionRole`

2. Click **Next**
3. Configure role details:
   - **Role name**: `[your-username]-messaging-lambda-role`
   - **Description**: `Lambda execution role for SQS and Kinesis processing`
   - **Tags**: Add tag with Key: `Project`, Value: `ServerlessLab`

4. Click **Create role**

### Step 3.3: Add Custom SQS Permissions

1. Click on your newly created role
2. Click **Add permissions** → **Create inline policy**
3. Click the **JSON** tab and paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:GetQueueAttributes",
                "sqs:GetQueueUrl"
            ],
            "Resource": "*"
        }
    ]
}
```

4. Click **Next**
5. **Name**: `SQSProducerPolicy`
6. Click **Create policy**

---

## Task 4: Create Lambda Functions (Cloud9)

### Step 4.1: Create SQS Message Producer

1. Create directory for SQS producer:
```bash
mkdir ~/environment/[your-username]-sqs-producer
cd ~/environment/[your-username]-sqs-producer
```

2. Create `sqs_producer.py`:

```python
import json
import boto3
import uuid
import datetime
from botocore.exceptions import ClientError

# Initialize SQS client
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    """
    SQS message producer that sends order processing messages
    """
    
    try:
        # Extract parameters from the request
        body = json.loads(event.get('body', '{}'))
        message_type = body.get('messageType', 'OrderProcessing')
        batch_size = body.get('batchSize', 5)
        simulate_failure = body.get('simulateFailure', False)
        
        queue_url = '[your-queue-url]'  # Replace with actual queue URL
        messages_sent = []
        
        for i in range(batch_size):
            # Generate order data
            order_data = {
                'orderId': f"ORD-{uuid.uuid4().hex[:8].upper()}",
                'customerId': f"CUST-{uuid.uuid4().hex[:6].upper()}",
                'amount': round(50 + (i * 25.99), 2),
                'items': [
                    {
                        'productId': f"PROD-{uuid.uuid4().hex[:4].upper()}",
                        'quantity': i + 1,
                        'price': round(25.99 + (i * 5), 2)
                    }
                ],
                'timestamp': datetime.datetime.now().isoformat(),
                'priority': 'high' if i % 3 == 0 else 'normal',
                'simulateFailure': simulate_failure and i == 0  # Only first message fails
            }
            
            # Send message to SQS
            response = sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(order_data),
                MessageAttributes={
                    'MessageType': {
                        'StringValue': message_type,
                        'DataType': 'String'
                    },
                    'Priority': {
                        'StringValue': order_data['priority'],
                        'DataType': 'String'
                    }
                }
            )
            
            messages_sent.append({
                'orderId': order_data['orderId'],
                'messageId': response['MessageId'],
                'priority': order_data['priority']
            })
            
            print(f"Sent order {order_data['orderId']} to SQS with message ID {response['MessageId']}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': f'Successfully sent {len(messages_sent)} messages to SQS',
                'messages': messages_sent,
                'queueUrl': queue_url
            })
        }
        
    except ClientError as e:
        print(f"Error sending messages to SQS: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
```

### Step 4.2: Create SQS Message Processor

1. Create directory for SQS processor:
```bash
mkdir ~/environment/[your-username]-sqs-processor
cd ~/environment/[your-username]-sqs-processor
```

2. Create `sqs_processor.py`:

```python
import json
import time
import random

def lambda_handler(event, context):
    """
    SQS message processor with retry and failure handling
    """
    
    print(f"Received SQS event with {len(event.get('Records', []))} records")
    
    batch_item_failures = []
    successfully_processed = []
    
    for record in event['Records']:
        try:
            # Extract message data
            message_id = record['messageId']
            receipt_handle = record['receiptHandle']
            message_body = json.loads(record['body'])
            message_attributes = record.get('messageAttributes', {})
            
            print(f"Processing message {message_id}")
            print(f"Order data: {json.dumps(message_body, indent=2)}")
            
            # Extract order information
            order_id = message_body.get('orderId', 'unknown')
            customer_id = message_body.get('customerId', 'unknown')
            amount = message_body.get('amount', 0)
            items = message_body.get('items', [])
            priority = message_attributes.get('Priority', {}).get('stringValue', 'normal')
            simulate_failure = message_body.get('simulateFailure', False)
            
            # Simulate processing failure for testing DLQ
            if simulate_failure:
                print(f"❌ Simulating failure for order {order_id}")
                raise Exception(f"Simulated processing failure for order {order_id}")
            
            # Simulate processing time based on priority
            processing_time = 1 if priority == 'high' else 2
            time.sleep(processing_time)
            
            # Process the order
            print(f"🔄 Processing {priority} priority order {order_id}")
            print(f"  - Customer: {customer_id}")
            print(f"  - Amount: ${amount}")
            print(f"  - Items: {len(items)} items")
            
            # Simulate order processing steps
            print(f"  ✅ Validated payment information")
            print(f"  ✅ Reserved inventory for {len(items)} items")
            print(f"  ✅ Calculated shipping and taxes")
            print(f"  ✅ Created fulfillment order")
            print(f"  ✅ Sent confirmation to customer {customer_id}")
            
            successfully_processed.append({
                'messageId': message_id,
                'orderId': order_id,
                'priority': priority
            })
            
            print(f"✅ Successfully processed order {order_id}")
            
        except Exception as e:
            print(f"❌ Error processing message {message_id}: {str(e)}")
            # Add to batch item failures for retry
            batch_item_failures.append({
                'itemIdentifier': message_id
            })
    
    print(f"Processing summary:")
    print(f"  - Successfully processed: {len(successfully_processed)}")
    print(f"  - Failed (will retry): {len(batch_item_failures)}")
    
    # Return batch item failures for SQS to retry
    response = {
        'statusCode': 200,
        'batchItemFailures': batch_item_failures
    }
    
    if batch_item_failures:
        print(f"⚠️ Returning {len(batch_item_failures)} messages for retry")
    
    return response
```

### Step 4.3: Deploy SQS Lambda Functions

1. Update the queue URL in the producer code:
```bash
cd ~/environment/[your-username]-sqs-producer
# Replace [your-queue-url] with your actual queue URL
sed -i "s|\[your-queue-url\]|https://sqs.us-east-1.amazonaws.com/[ACCOUNT-ID]/[your-username]-order-processing-queue|g" sqs_producer.py
```

2. Deploy SQS producer:
```bash
zip sqs-producer.zip sqs_producer.py

aws lambda create-function \
  --function-name [your-username]-sqs-producer \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-messaging-lambda-role \
  --handler sqs_producer.lambda_handler \
  --zip-file fileb://sqs-producer.zip \
  --timeout 60 \
  --description "SQS message producer for order processing"
```

3. Deploy SQS processor:
```bash
cd ~/environment/[your-username]-sqs-processor
zip sqs-processor.zip sqs_processor.py

aws lambda create-function \
  --function-name [your-username]-sqs-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-messaging-lambda-role \
  --handler sqs_processor.lambda_handler \
  --zip-file fileb://sqs-processor.zip \
  --timeout 60 \
  --reserved-concurrency 5 \
  --description "SQS message processor with retry handling"
```

---

## Task 5: Configure SQS Event Source Mapping (Console)

### Step 5.1: Create Event Source Mapping

1. Navigate to **AWS Lambda** in the console
2. Click on your function: `[your-username]-sqs-processor`
3. Click the **Configuration** tab
4. Click **Triggers** in the left panel
5. Click **Add trigger**

6. Configure the trigger:
   - **Source**: SQS
   - **SQS queue**: Select `[your-username]-order-processing-queue`
   - **Batch size**: 5
   - **Maximum batching window**: 5 seconds
   - **Enabled**: Checked

7. **Advanced settings**:
   - **Report batch item failures**: Checked (important for DLQ)
   - **Maximum concurrency**: 2

8. Click **Add**

### Step 5.2: Verify Event Source Mapping

1. In the Lambda function console, go to the **Configuration** → **Triggers** tab
2. Verify the SQS trigger is shown as **Enabled**
3. Click on the trigger to see detailed configuration
4. Note the **UUID** of the event source mapping for later reference

---

## Task 6: Create Kinesis Stream Components (Cloud9)

### Step 6.1: Create Kinesis Data Producer

1. Create directory for Kinesis producer:
```bash
mkdir ~/environment/[your-username]-kinesis-producer
cd ~/environment/[your-username]-kinesis-producer
```

2. Create `kinesis_producer.py`:

```python
import json
import boto3
import uuid
import datetime
import random
from botocore.exceptions import ClientError

# Initialize Kinesis client
kinesis = boto3.client('kinesis')

def lambda_handler(event, context):
    """
    Kinesis data producer for real-time analytics events
    """
    
    try:
        # Extract parameters from the request
        body = json.loads(event.get('body', '{}'))
        event_type = body.get('eventType', 'user_activity')
        event_count = body.get('eventCount', 10)
        
        stream_name = '[your-username]-analytics-stream'
        records_sent = []
        
        for i in range(event_count):
            if event_type == 'user_activity':
                event_data = {
                    'eventType': 'user_activity',
                    'userId': f"USER-{uuid.uuid4().hex[:8].upper()}",
                    'sessionId': f"SESS-{uuid.uuid4().hex[:8].upper()}",
                    'action': random.choice(['page_view', 'click', 'scroll', 'search', 'purchase']),
                    'page': random.choice(['/home', '/products', '/cart', '/checkout', '/profile']),
                    'timestamp': datetime.datetime.now().isoformat(),
                    'userAgent': 'Mozilla/5.0 (compatible; AnalyticsBot/1.0)',
                    'metadata': {
                        'device': random.choice(['desktop', 'mobile', 'tablet']),
                        'browser': random.choice(['Chrome', 'Firefox', 'Safari', 'Edge']),
                        'location': random.choice(['US', 'CA', 'UK', 'DE', 'JP'])
                    }
                }
                partition_key = event_data['userId']
                
            elif event_type == 'transaction':
                event_data = {
                    'eventType': 'transaction',
                    'transactionId': f"TXN-{uuid.uuid4().hex[:8].upper()}",
                    'customerId': f"CUST-{uuid.uuid4().hex[:6].upper()}",
                    'amount': round(random.uniform(10.0, 500.0), 2),
                    'currency': 'USD',
                    'paymentMethod': random.choice(['credit_card', 'debit_card', 'paypal', 'apple_pay']),
                    'status': random.choice(['completed', 'pending', 'failed']),
                    'timestamp': datetime.datetime.now().isoformat(),
                    'merchantId': f"MERCH-{random.randint(1000, 9999)}",
                    'metadata': {
                        'channel': random.choice(['web', 'mobile', 'pos']),
                        'category': random.choice(['electronics', 'clothing', 'food', 'books']),
                        'region': random.choice(['north', 'south', 'east', 'west'])
                    }
                }
                partition_key = event_data['customerId']
                
            elif event_type == 'system_metric':
                event_data = {
                    'eventType': 'system_metric',
                    'metricName': random.choice(['cpu_usage', 'memory_usage', 'disk_io', 'network_latency']),
                    'value': round(random.uniform(0.1, 100.0), 2),
                    'unit': random.choice(['percent', 'ms', 'bytes', 'count']),
                    'hostname': f"server-{random.randint(1, 10):02d}",
                    'timestamp': datetime.datetime.now().isoformat(),
                    'environment': random.choice(['production', 'staging', 'development']),
                    'metadata': {
                        'datacenter': random.choice(['us-east-1', 'us-west-2', 'eu-west-1']),
                        'instance_type': random.choice(['t3.micro', 't3.small', 'm5.large']),
                        'availability_zone': random.choice(['a', 'b', 'c'])
                    }
                }
                partition_key = event_data['hostname']
            
            else:
                raise ValueError(f"Unsupported event type: {event_type}")
            
            # Send record to Kinesis
            response = kinesis.put_record(
                StreamName=stream_name,
                Data=json.dumps(event_data),
                PartitionKey=partition_key
            )
            
            records_sent.append({
                'eventType': event_type,
                'partitionKey': partition_key,
                'shardId': response['ShardId'],
                'sequenceNumber': response['SequenceNumber']
            })
            
            print(f"Sent {event_type} event to shard {response['ShardId']}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': f'Successfully sent {len(records_sent)} records to Kinesis',
                'streamName': stream_name,
                'eventType': event_type,
                'records': records_sent
            })
        }
        
    except ClientError as e:
        print(f"Error sending records to Kinesis: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
```

### Step 6.2: Create Kinesis Stream Processor

1. Create directory for Kinesis processor:
```bash
mkdir ~/environment/[your-username]-kinesis-processor
cd ~/environment/[your-username]-kinesis-processor
```

2. Create `kinesis_processor.py`:

```python
import json
import base64
import datetime
from collections import defaultdict

def lambda_handler(event, context):
    """
    Kinesis stream processor for real-time analytics
    """
    
    print(f"Received Kinesis event with {len(event.get('Records', []))} records")
    
    # Analytics aggregations
    event_counts = defaultdict(int)
    user_activities = defaultdict(list)
    transaction_stats = {
        'total_amount': 0,
        'completed_count': 0,
        'failed_count': 0,
        'pending_count': 0
    }
    system_metrics = defaultdict(list)
    
    successfully_processed = 0
    processing_errors = 0
    
    for record in event['Records']:
        try:
            # Decode the Kinesis record
            encoded_data = record['kinesis']['data']
            decoded_data = base64.b64decode(encoded_data).decode('utf-8')
            event_data = json.loads(decoded_data)
            
            event_type = event_data.get('eventType', 'unknown')
            partition_key = record['kinesis']['partitionKey']
            sequence_number = record['kinesis']['sequenceNumber']
            
            print(f"Processing {event_type} event from partition {partition_key}")
            
            # Count events by type
            event_counts[event_type] += 1
            
            # Process different event types
            if event_type == 'user_activity':
                user_id = event_data.get('userId')
                action = event_data.get('action')
                page = event_data.get('page')
                device = event_data.get('metadata', {}).get('device')
                
                user_activities[user_id].append({
                    'action': action,
                    'page': page,
                    'device': device,
                    'timestamp': event_data.get('timestamp')
                })
                
                print(f"  📱 User {user_id} performed {action} on {page} via {device}")
                
            elif event_type == 'transaction':
                amount = event_data.get('amount', 0)
                status = event_data.get('status', 'unknown')
                payment_method = event_data.get('paymentMethod')
                customer_id = event_data.get('customerId')
                
                transaction_stats['total_amount'] += amount
                if status == 'completed':
                    transaction_stats['completed_count'] += 1
                elif status == 'failed':
                    transaction_stats['failed_count'] += 1
                elif status == 'pending':
                    transaction_stats['pending_count'] += 1
                
                print(f"  💳 Transaction {event_data.get('transactionId')} for ${amount} - {status}")
                print(f"     Customer: {customer_id}, Payment: {payment_method}")
                
            elif event_type == 'system_metric':
                metric_name = event_data.get('metricName')
                value = event_data.get('value')
                hostname = event_data.get('hostname')
                environment = event_data.get('environment')
                
                system_metrics[metric_name].append({
                    'value': value,
                    'hostname': hostname,
                    'environment': environment,
                    'timestamp': event_data.get('timestamp')
                })
                
                print(f"  📊 {hostname} ({environment}): {metric_name} = {value}")
                
                # Alert on high values (simulated)
                if metric_name == 'cpu_usage' and value > 80:
                    print(f"  🚨 HIGH CPU ALERT: {hostname} CPU usage at {value}%")
                elif metric_name == 'memory_usage' and value > 90:
                    print(f"  🚨 HIGH MEMORY ALERT: {hostname} memory usage at {value}%")
            
            successfully_processed += 1
            
        except Exception as e:
            print(f"❌ Error processing record {record.get('kinesis', {}).get('sequenceNumber', 'unknown')}: {str(e)}")
            processing_errors += 1
            # Continue processing other records (Kinesis doesn't support partial batch failures)
    
    # Generate analytics summary
    print(f"\n📈 Real-time Analytics Summary:")
    print(f"  - Records processed: {successfully_processed}")
    print(f"  - Processing errors: {processing_errors}")
    print(f"  - Event type distribution: {dict(event_counts)}")
    
    if user_activities:
        print(f"  - Unique users active: {len(user_activities)}")
        most_active_user = max(user_activities.keys(), key=lambda k: len(user_activities[k]))
        print(f"  - Most active user: {most_active_user} ({len(user_activities[most_active_user])} actions)")
    
    if transaction_stats['total_amount'] > 0:
        print(f"  - Transaction volume: ${transaction_stats['total_amount']:.2f}")
        print(f"  - Completed: {transaction_stats['completed_count']}, Failed: {transaction_stats['failed_count']}, Pending: {transaction_stats['pending_count']}")
        
        if transaction_stats['completed_count'] > 0:
            avg_transaction = transaction_stats['total_amount'] / (transaction_stats['completed_count'] + transaction_stats['pending_count'])
            print(f"  - Average transaction: ${avg_transaction:.2f}")
    
    if system_metrics:
        print(f"  - System metrics collected: {len(system_metrics)} types")
        for metric_name, values in system_metrics.items():
            if values:
                avg_value = sum(v['value'] for v in values) / len(values)
                max_value = max(v['value'] for v in values)
                print(f"    - {metric_name}: avg={avg_value:.2f}, max={max_value:.2f}")
    
    return {
        'statusCode': 200,
        'recordsProcessed': successfully_processed,
        'errors': processing_errors,
        'analytics': {
            'eventCounts': dict(event_counts),
            'userActivities': len(user_activities),
            'transactionStats': transaction_stats,
            'systemMetrics': len(system_metrics)
        }
    }
```

### Step 6.3: Deploy Kinesis Lambda Functions

1. Update stream name in producer:
```bash
cd ~/environment/[your-username]-kinesis-producer
sed -i "s/\[your-username\]/[your-username]/g" kinesis_producer.py
```

2. Deploy Kinesis producer:
```bash
zip kinesis-producer.zip kinesis_producer.py

aws lambda create-function \
  --function-name [your-username]-kinesis-producer \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-messaging-lambda-role \
  --handler kinesis_producer.lambda_handler \
  --zip-file fileb://kinesis-producer.zip \
  --timeout 60 \
  --description "Kinesis data producer for analytics events"
```

3. Deploy Kinesis processor:
```bash
cd ~/environment/[your-username]-kinesis-processor
zip kinesis-processor.zip kinesis_processor.py

aws lambda create-function \
  --function-name [your-username]-kinesis-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-messaging-lambda-role \
  --handler kinesis_processor.lambda_handler \
  --zip-file fileb://kinesis-processor.zip \
  --timeout 300 \
  --description "Kinesis stream processor for real-time analytics"
```

---

## Task 7: Configure Kinesis Event Source Mapping (Console)

### Step 7.1: Create Kinesis Trigger

1. Navigate to **AWS Lambda** in the console
2. Click on your function: `[your-username]-kinesis-processor`
3. Click the **Configuration** tab
4. Click **Triggers** in the left panel
5. Click **Add trigger**

6. Configure the trigger:
   - **Source**: Kinesis
   - **Kinesis stream**: Select `[your-username]-analytics-stream`
   - **Starting position**: Latest
   - **Batch size**: 10
   - **Maximum batching window**: 5 seconds
   - **Enabled**: Checked

7. **Advanced settings**:
   - **Parallelization factor**: 1
   - **Maximum record age**: 3600 seconds (1 hour)
   - **Retry attempts**: 3
   - **Split batch on error**: Disabled

8. Click **Add**

### Step 7.2: Verify Kinesis Configuration

1. In the Lambda function console, go to **Configuration** → **Triggers**
2. Verify the Kinesis trigger is shown as **Enabled**
3. Note the **Starting position** is set to **Latest**

---

## Task 8: Create API Gateways for Producers (Console)

### Step 8.1: Create SQS Producer API

1. Navigate to **API Gateway** in the AWS Console
2. Click **Create API**
3. Choose **REST API** and click **Build**
4. Configure:
   - **API name**: `[your-username]-sqs-api`
   - **Description**: `API for SQS message production`
   - **Endpoint Type**: Regional
5. Click **Create API**

6. Create resource and method:
   - Click **Actions** → **Create Resource**
   - **Resource Name**: `messages`
   - **Resource Path**: `/messages`
   - **Enable API Gateway CORS**: Checked
   - Click **Create Resource**

7. Create POST method:
   - Select `/messages` resource
   - Click **Actions** → **Create Method**
   - Select **POST** and click checkmark
   - **Integration type**: Lambda Function
   - **Use Lambda Proxy integration**: Checked
   - **Lambda Function**: `[your-username]-sqs-producer`
   - Click **Save** and **OK**

8. Deploy API:
   - Click **Actions** → **Deploy API**
   - **Stage name**: `prod`
   - Click **Deploy**
   - **Copy the Invoke URL**

### Step 8.2: Create Kinesis Producer API

1. Repeat the same process for Kinesis:
   - **API name**: `[your-username]-kinesis-api`
   - **Resource**: `/events`
   - **Lambda Function**: `[your-username]-kinesis-producer`
   - **Copy the Invoke URL**

---

## Task 9: Test Queue and Stream Processing

### Step 9.1: Test SQS Processing

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

2. Test failure handling and DLQ:
```bash
curl -X POST "https://[your-sqs-api-id].execute-api.us-east-1.amazonaws.com/prod/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "messageType": "OrderProcessing",
    "batchSize": 2,
    "simulateFailure": true
  }'
```

### Step 9.2: Monitor SQS Processing (Console)

1. Navigate to **SQS** console
2. Click on your main queue: `[your-username]-order-processing-queue`
3. Click **Send and receive messages**
4. Click **Poll for messages** to see any messages in flight
5. Click the **Monitoring** tab to see:
   - **Messages Sent**
   - **Messages Received**
   - **Messages Deleted**

6. Check your DLQ: `[your-username]-order-dlq`
7. Click **Send and receive messages**
8. Click **Poll for messages** to see failed messages

### Step 9.3: Test Kinesis Stream Processing

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

3. Test system metrics:
```bash
curl -X POST "https://[your-kinesis-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "system_metric",
    "eventCount": 12
  }'
```

### Step 9.4: Monitor Kinesis Processing (Console)

1. Navigate to **Kinesis** console
2. Click on your stream: `[your-username]-analytics-stream`
3. Click the **Monitoring** tab to see:
   - **Incoming records**
   - **Outgoing records**
   - **Iterator age**

4. Click the **Shards** tab
5. Click on **Shard-level metrics** to see per-shard statistics

---

## Task 10: Create CloudWatch Dashboard (Console)

### Step 10.1: Create Messaging Dashboard

1. Navigate to **CloudWatch** in the AWS Console
2. Click **Dashboards**
3. Click **Create dashboard**
4. **Dashboard name**: `[your-username]-messaging-dashboard`
5. Click **Create dashboard**

### Step 10.2: Add SQS Metrics Widget

1. Click **Add widget**
2. Select **Line** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/SQS
   - **QueueName**: Select your queues
   - **Metrics**: NumberOfMessagesSent, NumberOfMessagesReceived, ApproximateNumberOfVisibleMessages

4. **Graphed metrics** tab:
   - **Period**: 1 minute
   - **Statistic**: Sum for sent/received, Average for visible
5. **Widget title**: SQS Queue Metrics
6. Click **Create widget**

### Step 10.3: Add Kinesis Metrics Widget

1. Click **Add widget**
2. Select **Line** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/Kinesis
   - **StreamName**: Select your stream
   - **Metrics**: IncomingRecords, OutgoingRecords

4. **Graphed metrics** tab:
   - **Period**: 1 minute
   - **Statistic**: Sum
5. **Widget title**: Kinesis Stream Metrics
6. Click **Create widget**

### Step 10.4: Add Lambda Metrics Widget

1. Click **Add widget**
2. Select **Number** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/Lambda
   - **FunctionName**: Select all your functions
   - **Metrics**: Invocations, Errors, Duration

4. **Widget title**: Lambda Function Metrics
5. Click **Create widget**

6. Click **Save dashboard**

---

## Task 11: Compare Processing Patterns (Console Analysis)

### Step 11.1: Analyze Processing Differences

1. Navigate to **CloudWatch** → **Log groups**
2. Compare processing patterns by examining logs:
   - **SQS processor**: Batch processing, retry behavior
   - **Kinesis processor**: Stream processing, real-time analytics

### Step 11.2: Performance Comparison

1. Send high-volume messages to both systems:
```bash
# 50 SQS messages
curl -X POST "https://[your-sqs-api-id].execute-api.us-east-1.amazonaws.com/prod/messages" \
  -H "Content-Type: application/json" \
  -d '{"messageType": "OrderProcessing", "batchSize": 50}'

# 50 Kinesis records
curl -X POST "https://[your-kinesis-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{"eventType": "user_activity", "eventCount": 50}'
```

2. Monitor in your CloudWatch dashboard:
   - **SQS**: Batch processing with retries
   - **Kinesis**: Real-time processing with analytics

### Step 11.3: Error Handling Analysis

1. Test SQS error handling:
```bash
curl -X POST "https://[your-sqs-api-id].execute-api.us-east-1.amazonaws.com/prod/messages" \
  -H "Content-Type: application/json" \
  -d '{"messageType": "OrderProcessing", "batchSize": 5, "simulateFailure": true}'
```

2. In SQS console, monitor:
   - Main queue message flow
   - DLQ accumulation after retries
   - Message visibility and retry behavior

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** SQS messages not being processed
- **Console Check**: Verify event source mapping in Lambda triggers
- **Console Check**: Check SQS queue visibility timeout vs Lambda timeout
- **Solution**: Increase Lambda timeout or reduce SQS visibility timeout

**Issue:** Messages ending up in DLQ immediately
- **Console Check**: Verify DLQ configuration in SQS queue settings
- **Console Check**: Check Lambda function error logs in CloudWatch
- **Solution**: Fix Lambda function code or increase retry count

**Issue:** Kinesis records not being processed
- **Console Check**: Verify stream is ACTIVE in Kinesis console
- **Console Check**: Check event source mapping configuration
- **Solution**: Ensure proper IAM permissions and starting position

**Issue:** High Lambda errors
- **Console Monitor**: Use CloudWatch dashboard to identify patterns
- **Console Debug**: Check detailed error logs in each function's log group
- **Solution**: Add error handling and increase timeout values

---

## Clean Up (Optional)

### Via Console:
1. **Lambda**: Delete all 4 functions
2. **SQS**: Delete both queues (main queue and DLQ)
3. **Kinesis**: Delete the data stream
4. **API Gateway**: Delete both REST APIs
5. **CloudWatch**: Delete the dashboard
6. **IAM**: Delete the role and policies

### Via CLI:
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
```

---

## Key Takeaways

From this lab, you should understand:

1. **Queue vs Stream Processing**: Different use cases and processing patterns
2. **Reliability Patterns**: Retry mechanisms, dead letter queues, and error handling
3. **Scalability Considerations**: Batch processing vs. real-time streaming
4. **Ordering Guarantees**: How SQS and Kinesis handle message ordering
5. **Event Source Mappings**: Configuration and tuning for different workloads
6. **Monitoring and Observability**: CloudWatch metrics for queue and stream processing
7. **Console vs CLI**: When to use visual tools for configuration and monitoring
8. **Production Patterns**: Error handling, retry logic, and monitoring strategies

### Processing Pattern Summary

| Aspect | SQS | Kinesis |
|--------|-----|---------|
| **Use Case** | Reliable message processing | Real-time data streaming |
| **Ordering** | FIFO optional | Partition-based ordering |
| **Retention** | Up to 14 days | Up to 365 days |
| **Error Handling** | Retry + DLQ | Continue processing |
| **Scaling** | Automatic | Manual shard management |
| **Processing** | Batch with retries | Real-time analytics |

---

## Next Steps

This completes Day 1 of the course. In Day 2, you will explore Lambda function optimization, workflow orchestration with Step Functions, and comprehensive monitoring and observability patterns.