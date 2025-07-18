# Developing Serverless Solutions on AWS - Day 1 - Lab 3
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

### Step 1.1: Create Custom Event Bus

1. In your Cloud9 terminal, create a custom event bus:
```bash
aws events create-event-bus \
  --name "[your-username]-ecommerce-events"
```

2. Verify the event bus was created:
```bash
aws events list-event-buses \
  --query 'EventBuses[?contains(Name, `[your-username]`)].{Name:Name, Arn:Arn}'
```

### Step 1.2: Create Event Producer Lambda Function

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
import uuid
import os

# Initialize EventBridge client
eventbridge = boto3.client('events')

def lambda_handler(event, context):
    """
    Event producer that publishes ecommerce events
    """
    
    # Extract request parameters
    body = json.loads(event.get('body', '{}'))
    event_type = body.get('eventType', 'OrderPlaced')
    customer_id = body.get('customerId', f'customer-{uuid.uuid4().hex[:8]}')
    
    # Create event payload based on type
    if event_type == 'OrderPlaced':
        event_detail = {
            'orderId': f'order-{uuid.uuid4().hex[:8]}',
            'customerId': customer_id,
            'amount': body.get('amount', 99.99),
            'items': body.get('items', [
                {'productId': 'prod-123', 'quantity': 2, 'price': 49.99}
            ]),
            'timestamp': datetime.datetime.now().isoformat()
        }
    elif event_type == 'PaymentProcessed':
        event_detail = {
            'paymentId': f'payment-{uuid.uuid4().hex[:8]}',
            'orderId': body.get('orderId', f'order-{uuid.uuid4().hex[:8]}'),
            'amount': body.get('amount', 99.99),
            'status': 'SUCCESS',
            'timestamp': datetime.datetime.now().isoformat()
        }
    elif event_type == 'InventoryUpdated':
        event_detail = {
            'productId': body.get('productId', 'prod-123'),
            'quantityChange': body.get('quantityChange', -2),
            'newQuantity': body.get('newQuantity', 98),
            'timestamp': datetime.datetime.now().isoformat()
        }
    else:
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Unknown event type: {event_type}'})
        }
    
    # Publish event to EventBridge
    try:
        response = eventbridge.put_events(
            Entries=[
                {
                    'Source': 'ecommerce.application',
                    'DetailType': event_type,
                    'Detail': json.dumps(event_detail),
                    'EventBusName': os.environ['EVENT_BUS_NAME']
                }
            ]
        )
        
        print(f"Published event: {event_type}")
        print(f"Event detail: {json.dumps(event_detail, indent=2)}")
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': f'Event {event_type} published successfully',
                'eventId': response['Entries'][0].get('EventId'),
                'eventDetail': event_detail
            }, indent=2)
        }
        
    except Exception as e:
        print(f"Error publishing event: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Failed to publish event: {str(e)}'})
        }
```

### Step 1.3: Deploy Event Producer

1. Create IAM policy for EventBridge access:
```bash
cat > event-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
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
```

2. Create IAM role for the producer:
```bash
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
```

3. Attach policies to the role:
```bash
aws iam attach-role-policy \
  --role-name [your-username]-event-producer-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam put-role-policy \
  --role-name [your-username]-event-producer-role \
  --policy-name EventBridgeAccess \
  --policy-document file://event-policy.json
```

4. Package and deploy the function:
```bash
zip event-producer.zip event_producer.py

aws lambda create-function \
  --function-name [your-username]-event-producer \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-event-producer-role \
  --handler event_producer.lambda_handler \
  --zip-file fileb://event-producer.zip \
  --environment Variables='{EVENT_BUS_NAME="[your-username]-ecommerce-events"}' \
  --timeout 30
```

### Step 1.4: Create API Gateway for Event Producer

1. Create REST API:
```bash
aws apigateway create-rest-api \
  --name "[your-username]-event-producer-api" \
  --description "API for publishing events"
```

2. Get the API ID and root resource ID:
```bash
# Note the api-id from the previous command
aws apigateway get-resources \
  --rest-api-id [your-api-id]
```

3. Create a resource for events:
```bash
aws apigateway create-resource \
  --rest-api-id [your-api-id] \
  --parent-id [root-resource-id] \
  --path-part events
```

4. Create POST method:
```bash
aws apigateway put-method \
  --rest-api-id [your-api-id] \
  --resource-id [events-resource-id] \
  --http-method POST \
  --authorization-type NONE
```

5. Integrate with Lambda:
```bash
aws apigateway put-integration \
  --rest-api-id [your-api-id] \
  --resource-id [events-resource-id] \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-event-producer/invocations
```

6. Grant API Gateway permission to invoke Lambda:
```bash
aws lambda add-permission \
  --function-name [your-username]-event-producer \
  --statement-id apigateway-invoke-producer \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:[ACCOUNT-ID]:[your-api-id]/*/*"
```

7. Deploy the API:
```bash
aws apigateway create-deployment \
  --rest-api-id [your-api-id] \
  --stage-name prod
```

---

## Task 2: Create Event Consumer Lambda Functions

### Step 2.1: Create Order Processor

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

### Step 2.2: Create Inventory Updater

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
    Updates inventory based on OrderPlaced and InventoryUpdated events
    """
    
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    # Process each record
    for record in event.get('Records', [event]):
        # Extract event details
        if 'detail' in record:
            event_detail = record['detail']
            detail_type = record.get('detail-type', 'unknown')
        else:
            event_detail = event.get('detail', {})
            detail_type = event.get('detail-type', 'unknown')
        
        print(f"Processing {detail_type} for inventory update")
        
        if detail_type == 'OrderPlaced':
            # Process order items for inventory reduction
            items = event_detail.get('items', [])
            order_id = event_detail.get('orderId', 'unknown')
            
            for item in items:
                product_id = item.get('productId', 'unknown')
                quantity = item.get('quantity', 0)
                
                print(f"📦 Reducing inventory for product {product_id} by {quantity} units")
                print(f"📦 Updated inventory tracking for order {order_id}")
        
        elif detail_type == 'InventoryUpdated':
            # Process direct inventory updates
            product_id = event_detail.get('productId', 'unknown')
            quantity_change = event_detail.get('quantityChange', 0)
            new_quantity = event_detail.get('newQuantity', 0)
            
            print(f"📦 Direct inventory update for product {product_id}")
            print(f"📦 Quantity change: {quantity_change}, New quantity: {new_quantity}")
            
            # Check for low stock alerts
            if new_quantity < 10:
                print(f"⚠️ LOW STOCK ALERT: Product {product_id} has only {new_quantity} units remaining")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Inventory update completed successfully')
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

### Step 2.3: Create Payment Processor

1. Create directory for payment processor:
```bash
mkdir ~/environment/[your-username]-payment-processor
cd ~/environment/[your-username]-payment-processor
```

2. Create `payment_processor.py`:

```python
import json
import boto3

def lambda_handler(event, context):
    """
    Processes PaymentProcessed events
    """
    
    print(f"Received event: {json.dumps(event, indent=2)}")
    
    # Process each record
    for record in event.get('Records', [event]):
        # Extract event details
        if 'detail' in record:
            event_detail = record['detail']
            detail_type = record.get('detail-type', 'unknown')
        else:
            event_detail = event.get('detail', {})
            detail_type = event.get('detail-type', 'unknown')
        
        print(f"Processing {detail_type}")
        
        payment_id = event_detail.get('paymentId', 'unknown')
        order_id = event_detail.get('orderId', 'unknown')
        amount = event_detail.get('amount', 0)
        status = event_detail.get('status', 'unknown')
        
        print(f"💳 Processing payment {payment_id} for order {order_id}")
        print(f"💳 Payment amount: ${amount}")
        print(f"💳 Payment status: {status}")
        
        if status == 'SUCCESS':
            print(f"✅ Payment {payment_id} processed successfully")
            print(f"✅ Order {order_id} can proceed to fulfillment")
        else:
            print(f"❌ Payment {payment_id} failed - order {order_id} requires attention")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Payment processing completed successfully')
    }
```

3. Deploy payment processor:
```bash
zip payment-processor.zip payment_processor.py

aws lambda create-function \
  --function-name [your-username]-payment-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-event-producer-role \
  --handler payment_processor.lambda_handler \
  --zip-file fileb://payment-processor.zip \
  --timeout 30
```

---

## Task 3: Create EventBridge Rules and Targets

### Step 3.1: Create Rule for Order Processing

1. Create event pattern for OrderPlaced events:
```bash
cat > order-pattern.json << 'EOF'
{
  "source": ["ecommerce.application"],
  "detail-type": ["OrderPlaced"]
}
EOF
```

2. Create the rule:
```bash
aws events put-rule \
  --name "[your-username]-order-processing-rule" \
  --event-pattern file://order-pattern.json \
  --event-bus-name "[your-username]-ecommerce-events" \
  --description "Routes OrderPlaced events to order processor"
```

3. Add Lambda target to the rule:
```bash
aws events put-targets \
  --rule "[your-username]-order-processing-rule" \
  --event-bus-name "[your-username]-ecommerce-events" \
  --targets Id=1,Arn=arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-order-processor
```

4. Grant EventBridge permission to invoke the Lambda:
```bash
aws lambda add-permission \
  --function-name [your-username]-order-processor \
  --statement-id eventbridge-invoke-order \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:[ACCOUNT-ID]:rule/[your-username]-ecommerce-events/[your-username]-order-processing-rule
```

### Step 3.2: Create Rule for Inventory Updates

1. Create event pattern for inventory-related events:
```bash
cat > inventory-pattern.json << 'EOF'
{
  "source": ["ecommerce.application"],
  "detail-type": ["OrderPlaced", "InventoryUpdated"]
}
EOF
```

2. Create the rule:
```bash
aws events put-rule \
  --name "[your-username]-inventory-update-rule" \
  --event-pattern file://inventory-pattern.json \
  --event-bus-name "[your-username]-ecommerce-events" \
  --description "Routes order and inventory events to inventory updater"
```

3. Add Lambda target:
```bash
aws events put-targets \
  --rule "[your-username]-inventory-update-rule" \
  --event-bus-name "[your-username]-ecommerce-events" \
  --targets Id=1,Arn=arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-inventory-updater
```

4. Grant permission:
```bash
aws lambda add-permission \
  --function-name [your-username]-inventory-updater \
  --statement-id eventbridge-invoke-inventory \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:[ACCOUNT-ID]:rule/[your-username]-ecommerce-events/[your-username]-inventory-update-rule
```

### Step 3.3: Create Rule for Payment Processing

1. Create event pattern for payment events:
```bash
cat > payment-pattern.json << 'EOF'
{
  "source": ["ecommerce.application"],
  "detail-type": ["PaymentProcessed"]
}
EOF
```

2. Create the rule:
```bash
aws events put-rule \
  --name "[your-username]-payment-processing-rule" \
  --event-pattern file://payment-pattern.json \
  --event-bus-name "[your-username]-ecommerce-events" \
  --description "Routes PaymentProcessed events to payment processor"
```

3. Add Lambda target:
```bash
aws events put-targets \
  --rule "[your-username]-payment-processing-rule" \
  --event-bus-name "[your-username]-ecommerce-events" \
  --targets Id=1,Arn=arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-payment-processor
```

4. Grant permission:
```bash
aws lambda add-permission \
  --function-name [your-username]-payment-processor \
  --statement-id eventbridge-invoke-payment \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:[ACCOUNT-ID]:rule/[your-username]-ecommerce-events/[your-username]-payment-processing-rule
```

---

## Task 4: Test the Event-Driven Architecture

### Step 4.1: Test Order Placement

1. Get your event producer API endpoint:
```bash
echo "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events"
```

2. Test OrderPlaced event:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "OrderPlaced",
    "customerId": "customer-12345",
    "amount": 149.99,
    "items": [
      {"productId": "laptop-001", "quantity": 1, "price": 149.99}
    ]
  }'
```

3. Check CloudWatch logs for both order processor and inventory updater functions to see the event processing.

### Step 4.2: Test Payment Processing

1. Test PaymentProcessed event:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "PaymentProcessed",
    "orderId": "order-67890",
    "amount": 149.99
  }'
```

### Step 4.3: Test Inventory Update

1. Test InventoryUpdated event:
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "InventoryUpdated",
    "productId": "laptop-001",
    "quantityChange": -5,
    "newQuantity": 8
  }'
```

### Step 4.4: Monitor Event Flow

1. Check EventBridge metrics in CloudWatch:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Events \
  --metric-name SuccessfulInvocations \
  --dimensions Name=EventBusName,Value=[your-username]-ecommerce-events \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

2. View Lambda function logs:
```bash
# Check logs for each function
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/[your-username]
```

---

## Task 5: Advanced Event Filtering

### Step 5.1: Create Filtered Rule for High-Value Orders

1. Create pattern for high-value orders:
```bash
cat > high-value-pattern.json << 'EOF'
{
  "source": ["ecommerce.application"],
  "detail-type": ["OrderPlaced"],
  "detail": {
    "amount": [{"numeric": [">=", 100]}]
  }
}
EOF
```

2. Create high-value order processor:
```bash
mkdir ~/environment/[your-username]-high-value-processor
cd ~/environment/[your-username]-high-value-processor

cat > high_value_processor.py << 'EOF'
import json

def lambda_handler(event, context):
    """
    Special processing for high-value orders
    """
    
    print(f"🔥 HIGH VALUE ORDER DETECTED: {json.dumps(event, indent=2)}")
    
    event_detail = event.get('detail', {})
    order_id = event_detail.get('orderId', 'unknown')
    amount = event_detail.get('amount', 0)
    customer_id = event_detail.get('customerId', 'unknown')
    
    print(f"💰 High-value order {order_id} for ${amount}")
    print(f"👤 Customer: {customer_id}")
    print(f"🚨 Flagging for manual review and premium processing")
    print(f"📧 Sending notification to sales team")
    print(f"🎁 Applying VIP customer benefits")
    
    return {
        'statusCode': 200,
        'body': json.dumps('High-value order processing completed')
    }
EOF

zip high-value-processor.zip high_value_processor.py

aws lambda create-function \
  --function-name [your-username]-high-value-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-event-producer-role \
  --handler high_value_processor.lambda_handler \
  --zip-file fileb://high-value-processor.zip \
  --timeout 30
```

3. Create and configure the rule:
```bash
aws events put-rule \
  --name "[your-username]-high-value-order-rule" \
  --event-pattern file://high-value-pattern.json \
  --event-bus-name "[your-username]-ecommerce-events" \
  --description "Routes high-value orders for special processing"

aws events put-targets \
  --rule "[your-username]-high-value-order-rule" \
  --event-bus-name "[your-username]-ecommerce-events" \
  --targets Id=1,Arn=arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-high-value-processor

aws lambda add-permission \
  --function-name [your-username]-high-value-processor \
  --statement-id eventbridge-invoke-high-value \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:[ACCOUNT-ID]:rule/[your-username]-ecommerce-events/[your-username]-high-value-order-rule
```

### Step 5.2: Test Filtered Events

1. Test with high-value order (should trigger both processors):
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "OrderPlaced",
    "customerId": "vip-customer-001",
    "amount": 299.99,
    "items": [
      {"productId": "premium-laptop", "quantity": 1, "price": 299.99}
    ]
  }'
```

2. Test with low-value order (should only trigger regular processor):
```bash
curl -X POST "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/events" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "OrderPlaced",
    "customerId": "regular-customer-002",
    "amount": 29.99,
    "items": [
      {"productId": "basic-accessory", "quantity": 1, "price": 29.99}
    ]
  }'
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created a custom EventBridge event bus with username prefix
- [ ] Deployed an event producer Lambda function and API Gateway
- [ ] Created three event consumer Lambda functions (order, inventory, payment processors)
- [ ] Configured EventBridge rules with proper event pattern matching
- [ ] Successfully tested event publishing and consumption
- [ ] Implemented advanced filtering for high-value orders
- [ ] Monitored event flow through CloudWatch logs
- [ ] Understood event-driven decoupling concepts

### Expected Results

Your event-driven architecture should:
1. Accept events via API Gateway and publish them to EventBridge
2. Route events to appropriate Lambda functions based on patterns
3. Process events independently in each consumer function
4. Handle multiple event types (OrderPlaced, PaymentProcessed, InventoryUpdated)
5. Filter high-value orders for special processing
6. Log all processing activities to CloudWatch

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Events are published but not received by Lambda functions
- **Solution:** Check EventBridge rule patterns and ensure they match event structure
- Verify Lambda permissions for EventBridge invocation
- Check event bus name consistency

**Issue:** Lambda functions not triggering
- **Solution:** Verify rule targets are correctly configured
- Check IAM permissions for EventBridge to invoke Lambda
- Ensure event source ARN matches rule ARN

**Issue:** API Gateway returns errors
- **Solution:** Check Lambda function permissions for API Gateway
- Verify request payload format
- Check CloudWatch logs for specific error messages

**Issue:** Events don't match patterns
- **Solution:** Review event structure and pattern syntax
- Use CloudWatch Events console to test patterns
- Check for case sensitivity in event fields

---

## Clean Up (Optional)

To clean up resources after the lab:

```bash
# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-event-producer
aws lambda delete-function --function-name [your-username]-order-processor
aws lambda delete-function --function-name [your-username]-inventory-updater
aws lambda delete-function --function-name [your-username]-payment-processor
aws lambda delete-function --function-name [your-username]-high-value-processor

# Delete EventBridge rules
aws events remove-targets --rule [your-username]-order-processing-rule --event-bus-name [your-username]-ecommerce-events --ids 1
aws events delete-rule --name [your-username]-order-processing-rule --event-bus-name [your-username]-ecommerce-events

# Repeat for other rules...

# Delete event bus
aws events delete-event-bus --name [your-username]-ecommerce-events

# Delete API Gateway
aws apigateway delete-rest-api --rest-api-id [your-api-id]

# Delete IAM role
aws iam detach-role-policy --role-name [your-username]-event-producer-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role-policy --role-name [your-username]-event-producer-role --policy-name EventBridgeAccess
aws iam delete-role --role-name [your-username]-event-producer-role
```

---

## Key Takeaways

From this lab, you should understand:
1. **Event-Driven Architecture:** How to build loosely coupled, scalable systems
2. **EventBridge Capabilities:** Custom buses, routing rules, and pattern matching
3. **Fan-Out Pattern:** How single events can trigger multiple processing workflows
4. **Event Filtering:** Advanced pattern matching for selective event processing
5. **Decoupling Benefits:** How events enable independent service development and scaling
6. **Monitoring:** Using CloudWatch to track event flow and processing

---

## Next Steps

In the next lab, you will explore queue and stream processing patterns to handle event ordering, retry logic, and batch processing scenarios.