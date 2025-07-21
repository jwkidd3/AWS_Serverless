# Developing Serverless Solutions on AWS - Lab 3
## Message Fan-Out with Amazon EventBridge

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will build an event-driven serverless architecture using Amazon EventBridge to implement a message fan-out pattern. You'll create custom event buses, define routing rules, and build multiple Lambda functions that respond to different events, demonstrating how to decouple components in a serverless application.

## Lab Objectives

By the end of this lab, you will be able to:
- Create and configure custom Amazon EventBridge event buses
- Define event routing rules with pattern matching
- Implement event producers and multiple event consumers
- Build a decoupled, event-driven serverless architecture
- Configure event filtering and transformation
- Monitor and troubleshoot event flow through CloudWatch
- Apply username prefixing to event-driven resources

## Prerequisites

- Completion of Labs 1 and 2
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Basic understanding of event-driven architecture concepts

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Events
**IMPORTANT:** All EventBridge resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- Event bus: `user3-ecommerce-events`
- Rules: `user3-order-processing-rule`
- Lambda functions: `user3-order-processor`, `user3-inventory-updater`

---

## Task 1: Create Custom Event Bus and Producer

### Step 1.1: Create Custom Event Bus (Console)

1. Navigate to **Amazon EventBridge** in the AWS Console
2. Click **Event buses** in the left navigation
3. Click **Create event bus**
4. Configure the event bus:
   - **Name**: `[your-username]-ecommerce-events`
   - **Description**: `Event bus for ecommerce application events`
   - **Event source name**: Leave blank (custom events)
   - **KMS encryption**: Disabled for this lab
5. Click **Create**
6. **Note the Event bus ARN** from the details page for later use

### Step 1.2: Verify Event Bus Creation (CLI)

1. In your Cloud9 terminal, verify the event bus was created:
```bash
aws events list-event-buses \
  --query 'EventBuses[?contains(Name, `[your-username]`)].{Name:Name, Arn:Arn}'
```

### Step 1.3: Create Event Producer Lambda Function (Cloud9)

1. Create a new directory for the event producer:
```bash
mkdir ~/environment/[your-username]-event-producer
cd ~/environment/[your-username]-event-producer
```

2. Create `event_producer.py`:

```python
import json
import boto3
import datetime
from botocore.exceptions import ClientError

# Initialize EventBridge client
eventbridge = boto3.client('events')

def lambda_handler(event, context):
    """
    Event producer that publishes ecommerce events to custom EventBridge bus
    """
    
    try:
        # Extract event type from the incoming request
        body = json.loads(event.get('body', '{}'))
        event_type = body.get('eventType', 'OrderPlaced')
        
        # Generate sample event data based on type
        if event_type == 'OrderPlaced':
            event_detail = {
                'orderId': f"ORD-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}",
                'customerId': body.get('customerId', 'CUST-001'),
                'amount': body.get('amount', 99.99),
                'items': body.get('items', [{'productId': 'PROD-001', 'quantity': 1}]),
                'timestamp': datetime.datetime.now().isoformat()
            }
            detail_type = 'Order Placed'
            source = 'ecommerce.orders'
            
        elif event_type == 'InventoryUpdate':
            event_detail = {
                'productId': body.get('productId', 'PROD-001'),
                'previousStock': body.get('previousStock', 100),
                'currentStock': body.get('currentStock', 95),
                'threshold': body.get('threshold', 10),
                'timestamp': datetime.datetime.now().isoformat()
            }
            detail_type = 'Inventory Updated'
            source = 'ecommerce.inventory'
            
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Unsupported event type: {event_type}'})
            }
        
        # Publish event to custom EventBridge bus
        response = eventbridge.put_events(
            Entries=[
                {
                    'Source': source,
                    'DetailType': detail_type,
                    'Detail': json.dumps(event_detail),
                    'EventBusName': '[your-username]-ecommerce-events'
                }
            ]
        )
        
        print(f"Published event: {json.dumps(event_detail, indent=2)}")
        print(f"EventBridge response: {json.dumps(response, indent=2)}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Event published successfully',
                'eventType': event_type,
                'eventId': response['Entries'][0].get('EventId'),
                'detail': event_detail
            })
        }
        
    except ClientError as e:
        print(f"Error publishing event: {e}")
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

3. Create IAM role for the event producer:
```bash
cat > event-producer-policy.json << 'EOF'
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
                "events:PutEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-role \
  --role-name [your-username]-event-producer-role \
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
  --role-name [your-username]-event-producer-role \
  --policy-name EventProducerPolicy \
  --policy-document file://event-producer-policy.json
```

4. Deploy the event producer function:
```bash
# Replace [your-username] in the Python file
sed -i "s/\[your-username\]/[your-username]/g" event_producer.py

zip event-producer.zip event_producer.py

aws lambda create-function \
  --function-name [your-username]-event-producer \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-event-producer-role \
  --handler event_producer.lambda_handler \
  --zip-file fileb://event-producer.zip \
  --timeout 30 \
  --description "EventBridge event producer for ecommerce events"
```

### Step 1.4: Create API Gateway for Event Producer (Console)

1. Navigate to **API Gateway** in the AWS Console
2. Click **Create API**
3. Choose **REST API** and click **Build**
4. Configure the API:
   - **API name**: `[your-username]-event-api`
   - **Description**: `API for publishing events to EventBridge`
   - **Endpoint Type**: Regional
5. Click **Create API**

6. Create a resource:
   - Click **Actions** → **Create Resource**
   - **Resource Name**: `events`
   - **Resource Path**: `/events`
   - **Enable API Gateway CORS**: Checked
   - Click **Create Resource**

7. Create a POST method:
   - Select the `/events` resource
   - Click **Actions** → **Create Method**
   - Select **POST** and click the checkmark
   - **Integration type**: Lambda Function
   - **Use Lambda Proxy integration**: Checked
   - **Lambda Region**: us-east-1
   - **Lambda Function**: `[your-username]-event-producer`
   - Click **Save**
   - Click **OK** to grant permission

8. Deploy the API:
   - Click **Actions** → **Deploy API**
   - **Deployment stage**: New Stage
   - **Stage name**: `prod`
   - Click **Deploy**
   - **Note the Invoke URL** for testing

---

## Task 2: Create Event Consumer Lambda Functions

### Step 2.1: Create Order Processor (Cloud9)

1. Create directory for order processor:
```bash
mkdir ~/environment/[your-username]-order-processor
cd ~/environment/[your-username]-order-processor
```

2. Create `order_processor.py`:

```python
import json
import boto3

def lambda_handler(event, context):
    """
    Processes OrderPlaced events
    """
    
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    # Process each record (EventBridge sends records in batches)
    for record in event.get('Records', [event]):
        # Extract event details
        if 'detail' in record:
            # Direct EventBridge event
            event_detail = record['detail']
            event_source = record.get('source', 'unknown')
            detail_type = record.get('detail-type', 'unknown')
        else:
            # This is the event itself
            event_detail = event.get('detail', {})
            event_source = event.get('source', 'unknown')
            detail_type = event.get('detail-type', 'unknown')
        
        print(f"Processing {detail_type} from {event_source}")
        print(f"Order details: {json.dumps(event_detail, indent=2)}")
        
        # Simulate order processing
        order_id = event_detail.get('orderId', 'unknown')
        customer_id = event_detail.get('customerId', 'unknown')
        amount = event_detail.get('amount', 0)
        
        # Log processing steps
        print(f"✅ Validated order {order_id} for customer {customer_id}")
        print(f"✅ Calculated tax and shipping for ${amount}")
        print(f"✅ Reserved inventory for order {order_id}")
        print(f"✅ Order {order_id} processing complete")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Order processing completed successfully')
    }
```

3. Deploy order processor:
```bash
zip order-processor.zip order_processor.py

aws lambda create-function \
  --function-name [your-username]-order-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-event-producer-role \
  --handler order_processor.lambda_handler \
  --zip-file fileb://order-processor.zip \
  --timeout 30
```

### Step 2.2: Create Inventory Updater (Cloud9)

1. Create directory for inventory updater:
```bash
mkdir ~/environment/[your-username]-inventory-updater
cd ~/environment/[your-username]-inventory-updater
```

2. Create `inventory_updater.py`:

```python
import json
import boto3

def lambda_handler(event, context):
    """
    Processes InventoryUpdate events and OrderPlaced events
    """
    
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    # Process the event
    event_detail = event.get('detail', {})
    event_source = event.get('source', 'unknown')
    detail_type = event.get('detail-type', 'unknown')
    
    print(f"Processing {detail_type} from {event_source}")
    
    if detail_type == 'Order Placed':
        # Process order for inventory updates
        order_id = event_detail.get('orderId', 'unknown')
        items = event_detail.get('items', [])
        
        print(f"📦 Processing inventory updates for order {order_id}")
        
        for item in items:
            product_id = item.get('productId', 'unknown')
            quantity = item.get('quantity', 0)
            
            print(f"  - Reducing inventory for {product_id} by {quantity} units")
            print(f"  - Checking reorder thresholds for {product_id}")
        
        print(f"✅ Inventory updates completed for order {order_id}")
        
    elif detail_type == 'Inventory Updated':
        # Process inventory level changes
        product_id = event_detail.get('productId', 'unknown')
        current_stock = event_detail.get('currentStock', 0)
        threshold = event_detail.get('threshold', 10)
        
        print(f"📊 Processing inventory update for product {product_id}")
        print(f"  - Current stock: {current_stock}")
        print(f"  - Reorder threshold: {threshold}")
        
        if current_stock <= threshold:
            print(f"⚠️  LOW STOCK ALERT: Product {product_id} needs reordering!")
            print(f"  - Triggering purchase order for {product_id}")
        
        print(f"✅ Inventory monitoring completed for {product_id}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Inventory processing completed successfully')
    }
```

3. Deploy inventory updater:
```bash
zip inventory-updater.zip inventory_updater.py

aws lambda create-function \
  --function-name [your-username]-inventory-updater \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-event-producer-role \
  --handler inventory_updater.lambda_handler \
  --zip-file fileb://inventory-updater.zip \
  --timeout 30
```

### Step 2.3: Create Notification Service (Cloud9)

1. Create directory for notification service:
```bash
mkdir ~/environment/[your-username]-notification-service
cd ~/environment/[your-username]-notification-service
```

2. Create `notification_service.py`:

```python
import json
import boto3

def lambda_handler(event, context):
    """
    Processes all events and sends notifications
    """
    
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    # Process the event
    event_detail = event.get('detail', {})
    event_source = event.get('source', 'unknown')
    detail_type = event.get('detail-type', 'unknown')
    
    print(f"Processing {detail_type} from {event_source}")
    
    if detail_type == 'Order Placed':
        # Send order confirmation
        order_id = event_detail.get('orderId', 'unknown')
        customer_id = event_detail.get('customerId', 'unknown')
        amount = event_detail.get('amount', 0)
        
        print(f"📧 Sending order confirmation email")
        print(f"  - To: Customer {customer_id}")
        print(f"  - Subject: Order Confirmation - {order_id}")
        print(f"  - Amount: ${amount}")
        print(f"✅ Order confirmation sent for {order_id}")
        
    elif detail_type == 'Inventory Updated':
        # Send inventory alerts if needed
        product_id = event_detail.get('productId', 'unknown')
        current_stock = event_detail.get('currentStock', 0)
        threshold = event_detail.get('threshold', 10)
        
        if current_stock <= threshold:
            print(f"📱 Sending low stock SMS alert")
            print(f"  - Product: {product_id}")
            print(f"  - Current Stock: {current_stock}")
            print(f"  - To: Warehouse Manager")
            print(f"✅ Low stock alert sent for {product_id}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Notification processing completed successfully')
    }
```

3. Deploy notification service:
```bash
zip notification-service.zip notification_service.py

aws lambda create-function \
  --function-name [your-username]-notification-service \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-event-producer-role \
  --handler notification_service.lambda_handler \
  --zip-file fileb://notification-service.zip \
  --timeout 30
```

---

## Task 3: Configure Event Rules and Targets (Console)

### Step 3.1: Create Order Processing Rule

1. Navigate to **Amazon EventBridge** in the AWS Console
2. Click **Rules** in the left navigation
3. Click **Create rule**
4. Configure the rule:
   - **Name**: `[your-username]-order-processing-rule`
   - **Description**: `Routes order placed events to processing functions`
   - **Event bus**: Select `[your-username]-ecommerce-events`
   - **Rule type**: Rule with an event pattern

5. Configure event pattern:
   - **Event source**: Custom
   - **Event pattern**: Click **Edit pattern** and enter:
   ```json
   {
     "source": ["ecommerce.orders"],
     "detail-type": ["Order Placed"]
   }
   ```
   - Click **Save**

6. Configure targets:
   - Click **Add target**
   - **Target type**: AWS service
   - **Service**: Lambda function
   - **Function**: `[your-username]-order-processor`
   - Click **Add another target**
   - **Target type**: AWS service  
   - **Service**: Lambda function
   - **Function**: `[your-username]-inventory-updater`
   - Click **Add another target**
   - **Target type**: AWS service
   - **Service**: Lambda function
   - **Function**: `[your-username]-notification-service`

7. Click **Create rule**

### Step 3.2: Create Inventory Processing Rule

1. Click **Create rule**
2. Configure the rule:
   - **Name**: `[your-username]-inventory-processing-rule`
   - **Description**: `Routes inventory update events to processing functions`
   - **Event bus**: Select `[your-username]-ecommerce-events`
   - **Rule type**: Rule with an event pattern

3. Configure event pattern:
   - **Event source**: Custom
   - **Event pattern**: Click **Edit pattern** and enter:
   ```json
   {
     "source": ["ecommerce.inventory"],
     "detail-type": ["Inventory Updated"]
   }
   ```
   - Click **Save**

4. Configure targets:
   - Click **Add target**
   - **Target type**: AWS service
   - **Service**: Lambda function
   - **Function**: `[your-username]-inventory-updater`
   - Click **Add another target**
   - **Target type**: AWS service
   - **Service**: Lambda function
   - **Function**: `[your-username]-notification-service`

5. Click **Create rule**

### Step 3.3: Verify Rule Configuration (Console)

1. In the EventBridge console, click **Rules**
2. Select your event bus: `[your-username]-ecommerce-events`
3. Verify both rules are listed and **Enabled**
4. Click on each rule to review:
   - Event pattern is correct
   - All targets are configured
   - Target permissions are granted

---

## Task 4: Test Event Flow

### Step 4.1: Test Order Placed Event

1. Test order placed event using your API:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "OrderPlaced",
    "customerId": "CUST-12345",
    "amount": 129.99,
    "items": [
      {"productId": "LAPTOP-001", "quantity": 1},
      {"productId": "MOUSE-002", "quantity": 2}
    ]
  }'
```

### Step 4.2: Test Inventory Update Event

1. Test inventory update event:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "InventoryUpdate",
    "productId": "LAPTOP-001",
    "previousStock": 50,
    "currentStock": 8,
    "threshold": 10
  }'
```

### Step 4.3: Monitor Event Processing (Console)

1. Navigate to **CloudWatch** in the AWS Console
2. Click **Log groups** in the left navigation
3. Find and click on each Lambda function's log group:
   - `/aws/lambda/[your-username]-order-processor`
   - `/aws/lambda/[your-username]-inventory-updater`
   - `/aws/lambda/[your-username]-notification-service`

4. Click on the most recent log stream for each function
5. Verify the events were processed correctly by reviewing the log entries

6. Navigate back to **EventBridge** → **Rules**
7. Click on each rule and then click the **Metrics** tab
8. Verify that:
   - **Invocations** shows successful executions
   - **Matches** shows events that matched the pattern
   - **Failed invocations** should be 0

---

## Task 5: Create CloudWatch Dashboard (Console)

### Step 5.1: Create Event Monitoring Dashboard

1. Navigate to **CloudWatch** in the AWS Console
2. Click **Dashboards** in the left navigation
3. Click **Create dashboard**
4. **Dashboard name**: `[your-username]-eventbridge-monitoring`
5. Click **Create dashboard**

### Step 5.2: Add EventBridge Metrics

1. Click **Add widget**
2. Select **Line** chart type and click **Configure**
3. **Metrics** tab:
   - **Namespace**: AWS/Events
   - **Metric name**: SuccessfulInvocations
   - **RuleName**: Select both of your rules
4. **Graphed metrics** tab:
   - Set **Period** to 1 minute
   - Set **Statistic** to Sum
5. Click **Create widget**

### Step 5.3: Add Lambda Function Metrics

1. Click **Add widget**
2. Select **Number** widget type and click **Configure**
3. **Metrics** tab:
   - **Namespace**: AWS/Lambda
   - **Metric name**: Invocations
   - **FunctionName**: Select all three of your Lambda functions
4. **Graphed metrics** tab:
   - Set **Period** to 5 minutes
   - Set **Statistic** to Sum
5. Click **Create widget**

### Step 5.4: Add Error Monitoring

1. Click **Add widget**
2. Select **Line** chart type and click **Configure**
3. **Metrics** tab:
   - **Namespace**: AWS/Lambda
   - **Metric name**: Errors
   - **FunctionName**: Select all three of your Lambda functions
4. **Graphed metrics** tab:
   - Set **Period** to 1 minute
   - Set **Statistic** to Sum
5. Click **Create widget**

6. Click **Save dashboard**

---

## Task 6: Advanced Event Filtering (Console)

### Step 6.1: Create High-Value Order Rule

1. Navigate back to **EventBridge** → **Rules**
2. Click **Create rule**
3. Configure the rule:
   - **Name**: `[your-username]-high-value-orders`
   - **Description**: `Special processing for high-value orders`
   - **Event bus**: Select `[your-username]-ecommerce-events`
   - **Rule type**: Rule with an event pattern

4. Configure advanced event pattern:
   - **Event pattern**: Click **Edit pattern** and enter:
   ```json
   {
     "source": ["ecommerce.orders"],
     "detail-type": ["Order Placed"],
     "detail": {
       "amount": [{"numeric": [">=", 100]}]
     }
   }
   ```
   - Click **Save**

5. Configure target:
   - **Target type**: AWS service
   - **Service**: Lambda function
   - **Function**: `[your-username]-notification-service`
   - **Configure input**: Constant (JSON text)
   - **JSON text**:
   ```json
   {
     "alertType": "HIGH_VALUE_ORDER",
     "priority": "urgent"
   }
   ```

6. Click **Create rule**

### Step 6.2: Test Advanced Filtering

1. Test with a high-value order:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "OrderPlaced",
    "customerId": "CUST-VIP-001",
    "amount": 1299.99,
    "items": [
      {"productId": "WORKSTATION-001", "quantity": 1}
    ]
  }'
```

2. Test with a regular order:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "OrderPlaced",
    "customerId": "CUST-002",
    "amount": 29.99,
    "items": [
      {"productId": "ACCESSORY-001", "quantity": 1}
    ]
  }'
```

3. Monitor the CloudWatch logs to verify that:
   - High-value orders trigger the special rule
   - Regular orders only trigger the standard processing rules

---

## Task 7: Event Replay and Debugging (Console)

### Step 7.1: Enable Event Replay

1. Navigate to **EventBridge** → **Replays**
2. Click **Create replay**
3. Configure replay:
   - **Name**: `[your-username]-order-replay`
   - **Description**: `Replay order events for debugging`
   - **Source**: `[your-username]-ecommerce-events`
   - **Replay start time**: 1 hour ago
   - **Replay end time**: Now
   - **Destination**: `[your-username]-ecommerce-events`

4. **Event pattern** (optional):
   ```json
   {
     "source": ["ecommerce.orders"]
   }
   ```

5. Click **Create replay**

### Step 7.2: Monitor Event Flow in Console

1. Navigate to **EventBridge** → **Rules**
2. Click on one of your rules
3. Click the **Monitoring** tab to view:
   - Successful invocations
   - Failed invocations  
   - Event pattern matches

4. Navigate to **CloudWatch** → **Insights**
5. **Log groups**: Select all your Lambda function log groups
6. Run this query to analyze event processing:
   ```
   fields @timestamp, @message
   | filter @message like /Processing/
   | sort @timestamp desc
   | limit 20
   ```

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Events not reaching Lambda functions
- **Console Check:** Verify rules are enabled in EventBridge Rules console
- **Console Check:** Check target permissions in rule configuration
- **Solution:** Re-add Lambda targets through the console to auto-configure permissions

**Issue:** Event pattern not matching
- **Console Debug:** Use EventBridge test pattern feature
- Navigate to your rule → **Test pattern** tab
- Paste a sample event to verify pattern matching
- **Solution:** Adjust pattern syntax in rule configuration

**Issue:** Lambda functions not processing events correctly
- **Console Monitor:** Check CloudWatch Logs for each function
- **Console Check:** Verify function execution role permissions
- **Solution:** Review function code and add error handling

**Issue:** High error rates
- **Console Monitor:** Use CloudWatch dashboard to identify patterns
- **Console Debug:** Check X-Ray traces if enabled
- **Solution:** Implement retry logic and dead letter queues

---

## Clean Up (Optional)

To clean up resources after the lab:

### Via Console:
1. **EventBridge**: Delete rules, then delete custom event bus
2. **Lambda**: Delete all three functions
3. **API Gateway**: Delete the REST API
4. **CloudWatch**: Delete the custom dashboard
5. **IAM**: Delete the custom role

### Via CLI:
```bash
# Delete EventBridge rules and bus
aws events delete-rule --name [your-username]-order-processing-rule --event-bus-name [your-username]-ecommerce-events
aws events delete-rule --name [your-username]-inventory-processing-rule --event-bus-name [your-username]-ecommerce-events
aws events delete-rule --name [your-username]-high-value-orders --event-bus-name [your-username]-ecommerce-events
aws events delete-event-bus --name [your-username]-ecommerce-events

# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-event-producer
aws lambda delete-function --function-name [your-username]-order-processor
aws lambda delete-function --function-name [your-username]-inventory-updater
aws lambda delete-function --function-name [your-username]-notification-service

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id [your-api-id]

# Delete IAM role
aws iam delete-role-policy --role-name [your-username]-event-producer-role --policy-name EventProducerPolicy
aws iam delete-role --role-name [your-username]-event-producer-role
```

---

## Key Takeaways

From this lab, you should understand:

1. **Event-Driven Architecture**: How to design loosely-coupled systems using EventBridge
2. **Event Routing**: Creating rules and patterns to route events to appropriate consumers
3. **Fan-Out Pattern**: How one event can trigger multiple processing workflows
4. **Event Filtering**: Using advanced patterns to process only relevant events
5. **Monitoring and Debugging**: Using CloudWatch and EventBridge console tools for observability
6. **Console vs CLI**: When to use AWS Console for visual configuration and monitoring
7. **Production Considerations**: Error handling, replay capabilities, and monitoring strategies

### Next Steps

In the next lab, you will explore queue and stream processing patterns, implementing reliable event processing with Amazon SQS and Amazon Kinesis for high-throughput scenarios.