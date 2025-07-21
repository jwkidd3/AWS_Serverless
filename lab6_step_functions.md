# Developing Serverless Solutions on AWS - Lab 6
## Workflow Orchestration Using AWS Step Functions

**Lab Duration:** 90 minutes

---

## Lab Overview

In this lab, you will build complex serverless workflows using AWS Step Functions to orchestrate multiple Lambda functions and AWS services. You'll create both Standard and Express workflows, implement error handling, parallel processing, and callback patterns to demonstrate sophisticated business process automation.

## Lab Objectives

By the end of this lab, you will be able to:
- Create and configure AWS Step Functions state machines
- Design workflows with sequential, parallel, and conditional logic
- Implement error handling and retry mechanisms in workflows
- Use Standard vs Express workflows for different use cases
- Integrate Step Functions with Lambda, SQS, and other AWS services
- Implement callback patterns for long-running processes
- Monitor and troubleshoot workflow executions
- Apply username prefixing to Step Functions resources

## Prerequisites

- Completion of Labs 1-5
- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Understanding of state machines and workflow concepts

---

## Lab Environment Setup

### Development Environment
Continue using your AWS Cloud9 environment from previous labs.

### Username Prefixing for Step Functions
**IMPORTANT:** All Step Functions resources must include your username prefix:

**Example:** If your username is `user3`, name your resources as:
- State machine: `user3-order-processing-workflow`
- Lambda functions: `user3-validate-order`, `user3-process-payment`
- IAM roles: `user3-stepfunctions-role`

---

## Task 1: Create IAM Role for Step Functions (Console)

### Step 1.1: Create Step Functions Execution Role

1. Navigate to **IAM** in the AWS Console
2. Click **Roles** in the left navigation
3. Click **Create role**
4. Configure trust relationship:
   - **Trusted entity type**: AWS service
   - **Service**: Step Functions
5. Click **Next**

### Step 1.2: Attach Permissions Policies

1. Search and select the following managed policies:
   - `AWSStepFunctionsFullAccess`
   - `AWSLambdaRole`

2. Click **Next**
3. Configure role details:
   - **Role name**: `[your-username]-stepfunctions-role`
   - **Description**: `Step Functions execution role for workflow orchestration`
   - **Tags**: Add tag with Key: `Project`, Value: `ServerlessLab`

4. Click **Create role**

### Step 1.3: Add Custom Policies

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
                "lambda:InvokeFunction",
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
```

4. Click **Next**
5. **Name**: `StepFunctionsExecutionPolicy`
6. Click **Create policy**
7. **Copy the Role ARN** for later use

---

## Task 2: Create Lambda Functions for Workflow (Cloud9)

### Step 2.1: Create Order Validation Function

1. Create directory for order validation:
```bash
mkdir ~/environment/[your-username]-order-validator
cd ~/environment/[your-username]-order-validator
```

2. Create `order_validator.py`:

```python
import json
import time
import random

def lambda_handler(event, context):
    """
    Validates incoming order data
    """
    
    print(f"Validating order: {json.dumps(event, indent=2)}")
    
    # Extract order details
    order_id = event.get('orderId', '')
    customer_id = event.get('customerId', '')
    amount = event.get('amount', 0)
    items = event.get('items', [])
    
    # Simulate validation processing time
    time.sleep(random.uniform(0.1, 0.3))
    
    # Validation logic
    validation_errors = []
    
    if not order_id:
        validation_errors.append("Order ID is required")
    
    if not customer_id:
        validation_errors.append("Customer ID is required")
    
    if amount <= 0:
        validation_errors.append("Amount must be greater than 0")
    
    if not items or len(items) == 0:
        validation_errors.append("At least one item is required")
    
    # Calculate total from items
    calculated_total = sum(item.get('price', 0) * item.get('quantity', 0) for item in items)
    
    if abs(calculated_total - amount) > 0.01:
        validation_errors.append("Amount doesn't match item totals")
    
    # Simulate occasional validation failure for testing
    if random.random() < 0.1:  # 10% chance of validation service error
        raise Exception("Validation service temporarily unavailable")
    
    # Return validation result
    is_valid = len(validation_errors) == 0
    
    result = {
        'orderId': order_id,
        'customerId': customer_id,
        'amount': amount,
        'items': items,
        'validation': {
            'isValid': is_valid,
            'errors': validation_errors,
            'calculatedTotal': calculated_total,
            'validatedAt': time.time()
        },
        'nextStep': 'process_payment' if is_valid else 'validation_failed'
    }
    
    print(f"Validation result: {'PASSED' if is_valid else 'FAILED'}")
    if validation_errors:
        print(f"Validation errors: {validation_errors}")
    
    return result
```

3. Deploy order validation function:
```bash
zip order-validator.zip order_validator.py

aws lambda create-function \
  --function-name [your-username]-order-validator \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler order_validator.lambda_handler \
  --zip-file fileb://order-validator.zip \
  --timeout 30 \
  --description "Order validation function for Step Functions workflow"
```

### Step 2.2: Create Payment Processing Function

1. Create directory for payment processing:
```bash
mkdir ~/environment/[your-username]-payment-processor
cd ~/environment/[your-username]-payment-processor
```

2. Create `payment_processor.py`:

```python
import json
import time
import random

def lambda_handler(event, context):
    """
    Processes payment for validated orders
    """
    
    print(f"Processing payment: {json.dumps(event, indent=2)}")
    
    # Extract order and validation info
    order_id = event.get('orderId')
    customer_id = event.get('customerId')
    amount = event.get('amount')
    validation = event.get('validation', {})
    
    # Check if order was validated
    if not validation.get('isValid', False):
        raise Exception("Cannot process payment for invalid order")
    
    # Simulate payment processing time
    processing_time = random.uniform(0.2, 0.8)
    time.sleep(processing_time)
    
    # Simulate payment gateway responses
    success_rate = 0.85  # 85% success rate
    payment_successful = random.random() < success_rate
    
    if payment_successful:
        transaction_id = f"txn_{order_id}_{int(time.time())}"
        payment_method = random.choice(['credit_card', 'debit_card', 'digital_wallet'])
        
        payment_result = {
            'transactionId': transaction_id,
            'status': 'COMPLETED',
            'paymentMethod': payment_method,
            'amount': amount,
            'processingTime': processing_time,
            'timestamp': time.time()
        }
        
        print(f"Payment successful: {transaction_id}")
        
    else:
        # Simulate different types of payment failures
        failure_reasons = [
            'Insufficient funds',
            'Card declined',
            'Payment gateway timeout',
            'Invalid payment information'
        ]
        
        payment_result = {
            'transactionId': None,
            'status': 'FAILED',
            'errorCode': random.choice(['DECLINE', 'TIMEOUT', 'INVALID']),
            'errorMessage': random.choice(failure_reasons),
            'processingTime': processing_time,
            'timestamp': time.time()
        }
        
        print(f"Payment failed: {payment_result['errorMessage']}")
    
    # Return enhanced order with payment info
    result = {
        **event,  # Include all original order data
        'payment': payment_result,
        'nextStep': 'fulfill_order' if payment_successful else 'payment_failed'
    }
    
    return result
```

3. Deploy payment processing function:
```bash
zip payment-processor.zip payment_processor.py

aws lambda create-function \
  --function-name [your-username]-payment-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler payment_processor.lambda_handler \
  --zip-file fileb://payment-processor.zip \
  --timeout 30 \
  --description "Payment processing function for Step Functions workflow"
```

### Step 2.3: Create Inventory Update Function

1. Create directory for inventory update:
```bash
mkdir ~/environment/[your-username]-inventory-updater
cd ~/environment/[your-username]-inventory-updater
```

2. Create `inventory_updater.py`:

```python
import json
import time
import random

def lambda_handler(event, context):
    """
    Updates inventory for processed orders
    """
    
    print(f"Updating inventory: {json.dumps(event, indent=2)}")
    
    # Extract order and payment info
    order_id = event.get('orderId')
    items = event.get('items', [])
    payment = event.get('payment', {})
    
    # Check if payment was successful
    if payment.get('status') != 'COMPLETED':
        raise Exception("Cannot update inventory for unsuccessful payment")
    
    # Simulate inventory operations
    inventory_updates = []
    
    for item in items:
        product_id = item.get('productId')
        quantity = item.get('quantity', 0)
        
        # Simulate checking current inventory
        current_stock = random.randint(50, 500)
        new_stock = max(0, current_stock - quantity)
        
        # Simulate inventory update processing time
        time.sleep(random.uniform(0.05, 0.15))
        
        inventory_update = {
            'productId': product_id,
            'quantityReserved': quantity,
            'previousStock': current_stock,
            'newStock': new_stock,
            'lowStockAlert': new_stock < 10,
            'timestamp': time.time()
        }
        
        inventory_updates.append(inventory_update)
        
        print(f"Updated inventory for {product_id}: {current_stock} -> {new_stock}")
        
        if new_stock < 10:
            print(f"⚠️ Low stock alert for {product_id}: {new_stock} remaining")
    
    # Check for any low stock items
    low_stock_items = [update for update in inventory_updates if update['lowStockAlert']]
    
    # Return enhanced order with inventory info
    result = {
        **event,  # Include all previous data
        'inventory': {
            'updates': inventory_updates,
            'lowStockItems': low_stock_items,
            'updatedAt': time.time()
        },
        'nextStep': 'fulfill_order'
    }
    
    return result
```

3. Deploy inventory update function:
```bash
zip inventory-updater.zip inventory_updater.py

aws lambda create-function \
  --function-name [your-username]-inventory-updater \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler inventory_updater.lambda_handler \
  --zip-file fileb://inventory-updater.zip \
  --timeout 30 \
  --description "Inventory update function for Step Functions workflow"
```

### Step 2.4: Create Order Fulfillment Function

1. Create directory for order fulfillment:
```bash
mkdir ~/environment/[your-username]-order-fulfillment
cd ~/environment/[your-username]-order-fulfillment
```

2. Create `order_fulfillment.py`:

```python
import json
import time
import random

def lambda_handler(event, context):
    """
    Handles order fulfillment and shipping
    """
    
    print(f"Processing order fulfillment: {json.dumps(event, indent=2)}")
    
    # Extract order data
    order_id = event.get('orderId')
    customer_id = event.get('customerId')
    items = event.get('items', [])
    payment = event.get('payment', {})
    inventory = event.get('inventory', {})
    
    # Generate fulfillment details
    fulfillment_id = f"fulfill_{order_id}_{int(time.time())}"
    shipping_method = random.choice(['standard', 'express', 'overnight'])
    
    # Calculate estimated delivery
    delivery_days = {
        'standard': random.randint(3, 7),
        'express': random.randint(1, 3),
        'overnight': 1
    }
    
    estimated_delivery_days = delivery_days[shipping_method]
    
    # Simulate fulfillment processing
    time.sleep(random.uniform(0.1, 0.4))
    
    # Generate tracking information
    tracking_number = f"TRK{random.randint(100000, 999999)}"
    warehouse_location = random.choice(['US-EAST', 'US-WEST', 'US-CENTRAL'])
    
    fulfillment_result = {
        'fulfillmentId': fulfillment_id,
        'trackingNumber': tracking_number,
        'shippingMethod': shipping_method,
        'estimatedDeliveryDays': estimated_delivery_days,
        'warehouseLocation': warehouse_location,
        'status': 'PROCESSING',
        'createdAt': time.time()
    }
    
    # Create order summary
    order_summary = {
        'orderId': order_id,
        'customerId': customer_id,
        'totalAmount': event.get('amount'),
        'itemCount': len(items),
        'transactionId': payment.get('transactionId'),
        'paymentStatus': payment.get('status'),
        'inventoryUpdated': len(inventory.get('updates', [])),
        'fulfillmentStatus': 'PROCESSING',
        'trackingNumber': tracking_number,
        'estimatedDelivery': f"{estimated_delivery_days} business days"
    }
    
    print(f"Order {order_id} fulfilled successfully")
    print(f"Tracking number: {tracking_number}")
    print(f"Estimated delivery: {estimated_delivery_days} days via {shipping_method}")
    
    # Return complete order with fulfillment info
    result = {
        **event,  # Include all previous data
        'fulfillment': fulfillment_result,
        'orderSummary': order_summary,
        'status': 'COMPLETED'
    }
    
    return result
```

3. Deploy order fulfillment function:
```bash
zip order-fulfillment.zip order_fulfillment.py

aws lambda create-function \
  --function-name [your-username]-order-fulfillment \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler order_fulfillment.lambda_handler \
  --zip-file fileb://order-fulfillment.zip \
  --timeout 30 \
  --description "Order fulfillment function for Step Functions workflow"
```

---

## Task 3: Create Standard Workflow (Console)

### Step 3.1: Design Order Processing Workflow

1. Navigate to **AWS Step Functions** in the AWS Console
2. Click **Create state machine**
3. Choose **Write your workflow in code**
4. Select **Standard** as the type

5. In the Definition section, paste the following state machine definition:

```json
{
  "Comment": "Order processing workflow with parallel execution and error handling",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-order-validator",
      "Next": "CheckValidation",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "ValidationFailed",
          "ResultPath": "$.error"
        }
      ]
    },
    "CheckValidation": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.validation.isValid",
          "BooleanEquals": true,
          "Next": "ParallelProcessing"
        }
      ],
      "Default": "ValidationFailed"
    },
    "ParallelProcessing": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "ProcessPayment",
          "States": {
            "ProcessPayment": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-payment-processor",
              "End": true,
              "Retry": [
                {
                  "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
                  "IntervalSeconds": 1,
                  "MaxAttempts": 2,
                  "BackoffRate": 2.0
                }
              ]
            }
          }
        },
        {
          "StartAt": "UpdateInventory",
          "States": {
            "UpdateInventory": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-inventory-updater",
              "End": true,
              "Retry": [
                {
                  "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
                  "IntervalSeconds": 1,
                  "MaxAttempts": 2,
                  "BackoffRate": 2.0
                }
              ]
            }
          }
        }
      ],
      "Next": "CheckParallelResults",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "ProcessingFailed",
          "ResultPath": "$.error"
        }
      ]
    },
    "CheckParallelResults": {
      "Type": "Choice",
      "Choices": [
        {
          "And": [
            {
              "Variable": "$[0].payment.status",
              "StringEquals": "COMPLETED"
            },
            {
              "Variable": "$[1].inventory.updatedAt",
              "IsPresent": true
            }
          ],
          "Next": "MergeResults"
        }
      ],
      "Default": "ProcessingFailed"
    },
    "MergeResults": {
      "Type": "Pass",
      "Parameters": {
        "orderId.$": "$[0].orderId",
        "customerId.$": "$[0].customerId",
        "amount.$": "$[0].amount",
        "items.$": "$[0].items",
        "validation.$": "$[0].validation",
        "payment.$": "$[0].payment",
        "inventory.$": "$[1].inventory"
      },
      "Next": "FulfillOrder"
    },
    "FulfillOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-order-fulfillment",
      "End": true,
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.AWSLambdaException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FulfillmentFailed",
          "ResultPath": "$.error"
        }
      ]
    },
    "ValidationFailed": {
      "Type": "Pass",
      "Result": {
        "status": "FAILED",
        "reason": "Order validation failed"
      },
      "End": true
    },
    "ProcessingFailed": {
      "Type": "Pass",
      "Result": {
        "status": "FAILED",
        "reason": "Payment or inventory processing failed"
      },
      "End": true
    },
    "FulfillmentFailed": {
      "Type": "Pass",
      "Result": {
        "status": "FAILED",
        "reason": "Order fulfillment failed"
      },
      "End": true
    }
  }
}
```

### Step 3.2: Configure State Machine Settings

1. Replace the placeholders in the definition:
   - Replace `[ACCOUNT-ID]` with your AWS account ID
   - Replace `[your-username]` with your assigned username

2. Configure state machine settings:
   - **State machine name**: `[your-username]-order-processing-workflow`
   - **Execution role**: Select `[your-username]-stepfunctions-role`

3. **Logging** (expand Advanced settings):
   - **Log level**: ALL
   - **Include execution data**: Checked
   - **Log destination**: CloudWatch Logs

4. Click **Create state machine**

### Step 3.3: Review Workflow Diagram

1. After creation, review the **Graph view** to see the visual workflow
2. Click on individual states to see their configuration
3. Note the parallel processing branches for payment and inventory
4. Observe the error handling paths and retry configurations

---

## Task 4: Create Express Workflow (Console)

### Step 4.1: Create Real-time Validation Function

1. In Cloud9, create a function for express workflow:
```bash
mkdir ~/environment/[your-username]-realtime-validator
cd ~/environment/[your-username]-realtime-validator
```

2. Create `realtime_validator.py`:

```python
import json
import time

def lambda_handler(event, context):
    """
    Fast validation for express workflow
    """
    
    print(f"Real-time validation: {json.dumps(event, indent=2)}")
    
    # Extract event data
    user_id = event.get('userId', '')
    action = event.get('action', '')
    timestamp = event.get('timestamp', 0)
    metadata = event.get('metadata', {})
    
    # Quick validation checks
    is_valid = bool(user_id and action and timestamp > 0)
    
    # Determine next action based on input
    if action == 'purchase':
        next_step = 'process_transaction'
    elif action == 'view':
        next_step = 'log_analytics'
    else:
        next_step = 'log_event'
    
    result = {
        'userId': user_id,
        'action': action,
        'timestamp': timestamp,
        'metadata': metadata,
        'validation': {
            'isValid': is_valid,
            'processedAt': time.time()
        },
        'nextStep': next_step
    }
    
    return result
```

3. Deploy real-time validation function:
```bash
zip realtime-validator.zip realtime_validator.py

aws lambda create-function \
  --function-name [your-username]-realtime-validator \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler realtime_validator.lambda_handler \
  --zip-file fileb://realtime-validator.zip \
  --timeout 15 \
  --description "Real-time validation for express workflow"
```

### Step 4.2: Create Express Workflow

1. In Step Functions console, click **Create state machine**
2. Choose **Write your workflow in code**
3. Select **Express** as the type

4. Paste the following definition:

```json
{
  "Comment": "Express workflow for real-time event processing",
  "StartAt": "ValidateEvent",
  "States": {
    "ValidateEvent": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-realtime-validator",
      "Next": "RouteEvent"
    },
    "RouteEvent": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.nextStep",
          "StringEquals": "process_transaction",
          "Next": "ProcessTransaction"
        },
        {
          "Variable": "$.nextStep",
          "StringEquals": "log_analytics",
          "Next": "LogAnalytics"
        }
      ],
      "Default": "LogEvent"
    },
    "ProcessTransaction": {
      "Type": "Pass",
      "Result": {
        "status": "TRANSACTION_PROCESSED",
        "message": "Transaction processed in real-time"
      },
      "End": true
    },
    "LogAnalytics": {
      "Type": "Pass",
      "Result": {
        "status": "ANALYTICS_LOGGED",
        "message": "Analytics event logged"
      },
      "End": true
    },
    "LogEvent": {
      "Type": "Pass",
      "Result": {
        "status": "EVENT_LOGGED",
        "message": "General event logged"
      },
      "End": true
    }
  }
}
```

5. Configure settings:
   - **State machine name**: `[your-username]-express-workflow`
   - **Execution role**: Select `[your-username]-stepfunctions-role`

6. Click **Create state machine**

---

## Task 5: Test Workflows (Console)

### Step 5.1: Test Standard Workflow

1. Navigate to your Standard workflow: `[your-username]-order-processing-workflow`
2. Click **Start execution**
3. **Name**: `successful-order-test`
4. **Input**: Paste the following JSON:

```json
{
  "orderId": "order-12345",
  "customerId": "customer-67890",
  "amount": 99.99,
  "items": [
    {
      "productId": "laptop-001",
      "quantity": 1,
      "price": 99.99
    }
  ]
}
```

5. Click **Start execution**
6. Observe the execution in the **Graph view**
7. Monitor state transitions in real-time

### Step 5.2: Test Express Workflow

1. Navigate to your Express workflow: `[your-username]-express-workflow`
2. Click **Start execution**
3. **Name**: `realtime-purchase-test`
4. **Input**: Paste the following JSON:

```json
{
  "userId": "user-123",
  "action": "purchase",
  "timestamp": 1627845600,
  "metadata": {
    "product": "widget-456",
    "amount": 29.99
  }
}
```

5. Click **Start execution**
6. Note the faster execution time compared to Standard workflow

### Step 5.3: Test Error Handling

1. Go back to your Standard workflow
2. Click **Start execution**
3. **Name**: `invalid-order-test`
4. **Input**: Paste invalid data:

```json
{
  "orderId": "",
  "customerId": "",
  "amount": -10,
  "items": []
}
```

5. Click **Start execution**
6. Observe how the workflow handles validation errors
7. Check the **ValidationFailed** state execution

### Step 5.4: View Execution Details

1. Click on any completed execution
2. Review the **Execution details**:
   - **Input and output** of each state
   - **Duration** of each step
   - **Resource usage** and costs

3. Click **Step details** for individual states
4. Review **CloudWatch logs** for Lambda function outputs

---

## Task 6: Create CloudWatch Dashboard (Console)

### Step 6.1: Create Step Functions Dashboard

1. Navigate to **CloudWatch** in the AWS Console
2. Click **Dashboards**
3. Click **Create dashboard**
4. **Dashboard name**: `[your-username]-stepfunctions-monitoring`
5. Click **Create dashboard**

### Step 6.2: Add Step Functions Metrics

1. Click **Add widget**
2. Select **Line** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/States
   - **StateMachineName**: Select both your state machines
   - **Metrics**: ExecutionsSucceeded, ExecutionsFailed, ExecutionsStarted

4. **Graphed metrics** tab:
   - **Period**: 1 minute
   - **Statistic**: Sum
5. **Widget title**: Step Functions Executions
6. Click **Create widget**

### Step 6.3: Add Execution Duration Metrics

1. Click **Add widget**
2. Select **Number** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/States
   - **StateMachineName**: Select your standard workflow
   - **Metrics**: ExecutionTime

4. **Graphed metrics** tab:
   - **Statistic**: Average
5. **Widget title**: Average Execution Duration
6. Click **Create widget**

### Step 6.4: Add Lambda Integration Metrics

1. Click **Add widget**
2. Select **Line** and click **Configure**
3. **Metrics** tab:
   - **Browse**: AWS/Lambda
   - **FunctionName**: Select all your workflow functions
   - **Metrics**: Invocations, Errors, Duration

4. **Widget title**: Lambda Function Performance
5. Click **Create widget**

6. Click **Save dashboard**

---

## Task 7: Implement Callback Pattern (Cloud9)

### Step 7.1: Create Long-Running Task Function

1. Create directory for long-running task:
```bash
mkdir ~/environment/[your-username]-long-running-task
cd ~/environment/[your-username]-long-running-task
```

2. Create `long_running_task.py`:

```python
import json
import boto3
import uuid
import time

stepfunctions = boto3.client('stepfunctions')

def lambda_handler(event, context):
    """
    Simulates a long-running task that will callback to Step Functions
    """
    
    print(f"Starting long-running task: {json.dumps(event, indent=2)}")
    
    # Extract task token and input
    task_token = event.get('taskToken')
    task_input = event.get('input', {})
    task_id = str(uuid.uuid4())
    
    print(f"Task {task_id} started. Will complete asynchronously.")
    
    # In a real scenario, this would start an external process
    # For demo, we'll simulate by immediately sending success callback
    
    try:
        # Simulate some quick processing
        processing_result = {
            'taskId': task_id,
            'status': 'COMPLETED',
            'result': f"Task completed successfully for input: {task_input.get('operation', 'unknown')}",
            'processingTime': 2.5,
            'completedAt': time.time()
        }
        
        # Send success callback to Step Functions
        stepfunctions.send_task_success(
            taskToken=task_token,
            output=json.dumps(processing_result)
        )
        
        print(f"Task {task_id} completed and callback sent")
        
    except Exception as e:
        print(f"Task {task_id} failed: {str(e)}")
        
        # Send failure callback
        stepfunctions.send_task_failure(
            taskToken=task_token,
            error='TaskExecutionError',
            cause=str(e)
        )
    
    # Return task info immediately (this function completes while task continues)
    return {
        'taskId': task_id,
        'status': 'STARTED',
        'message': 'Task started successfully'
    }
```

3. Deploy long-running task function:
```bash
zip long-running-task.zip long_running_task.py

aws lambda create-function \
  --function-name [your-username]-long-running-task \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler long_running_task.lambda_handler \
  --zip-file fileb://long-running-task.zip \
  --timeout 30 \
  --description "Simulates long-running task with callback"
```

### Step 7.2: Create Callback Workflow (Console)

1. In Step Functions console, click **Create state machine**
2. Choose **Write your workflow in code**
3. Select **Standard** as the type

4. Paste the following definition:

```json
{
  "Comment": "Workflow demonstrating callback pattern",
  "StartAt": "StartLongRunningTask",
  "States": {
    "StartLongRunningTask": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke.waitForTaskToken",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-long-running-task",
        "Payload": {
          "taskToken.$": "$$.Task.Token",
          "input.$": "$"
        }
      },
      "TimeoutSeconds": 300,
      "Next": "TaskCompleted",
      "Catch": [
        {
          "ErrorEquals": ["States.Timeout"],
          "Next": "TaskTimeout"
        },
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "TaskFailed"
        }
      ]
    },
    "TaskCompleted": {
      "Type": "Pass",
      "Result": {
        "status": "COMPLETED",
        "message": "Long-running task completed successfully"
      },
      "End": true
    },
    "TaskTimeout": {
      "Type": "Pass",
      "Result": {
        "status": "TIMEOUT",
        "message": "Task timed out after 5 minutes"
      },
      "End": true
    },
    "TaskFailed": {
      "Type": "Pass",
      "Result": {
        "status": "FAILED",
        "message": "Task failed during execution"
      },
      "End": true
    }
  }
}
```

5. Configure settings:
   - **State machine name**: `[your-username]-callback-workflow`
   - **Execution role**: Select `[your-username]-stepfunctions-role`

6. Click **Create state machine**

### Step 7.3: Test Callback Pattern

1. Click **Start execution** on your callback workflow
2. **Name**: `callback-test`
3. **Input**:

```json
{
  "operation": "long_running_analysis",
  "data": {
    "type": "financial_report",
    "complexity": "high"
  }
}
```

4. Click **Start execution**
5. Observe how the workflow waits for the callback
6. Monitor the execution until the callback completes the workflow

---

## Task 8: Monitor Workflow Performance (Console)

### Step 8.1: Analyze Execution History

1. Navigate to your Standard workflow
2. Click the **Executions** tab
3. Review execution history:
   - **Status** (Succeeded, Failed, Timed out)
   - **Duration**
   - **Start and end times**

4. Click on a specific execution to view:
   - **Execution input and output**
   - **State machine graph** with execution path
   - **Step details** with timing information
   - **CloudWatch logs** links

### Step 8.2: Performance Analysis

1. Click **Metrics** tab on your state machine
2. Review performance metrics:
   - **Execution rate**
   - **Success rate**
   - **Average duration**
   - **Error patterns**

3. Use the time range selector to analyze different periods
4. Compare Standard vs Express workflow performance

### Step 8.3: Optimize Based on Metrics

1. Identify any slow-performing states
2. Review Lambda function duration in your dashboard
3. Note any patterns in failures or timeouts
4. Consider adjustments to:
   - **Retry policies**
   - **Timeout values**
   - **Parallel processing opportunities**

---

## Task 9: Bulk Testing and Performance Validation

### Step 9.1: Create Bulk Test Script

1. In Cloud9, create a bulk testing script:
```bash
cat > bulk_workflow_test.sh << 'EOF'
#!/bin/bash

STATE_MACHINE_ARN="arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow"

echo "Starting bulk execution test for Step Functions..."

for i in {1..10}; do
    EXECUTION_NAME="bulk-test-$i-$(date +%s)"
    
    # Create unique test data
    cat > test-order-$i.json << EOL
{
  "orderId": "order-bulk-$i",
  "customerId": "customer-bulk-$i",
  "amount": $((RANDOM % 500 + 10)),
  "items": [
    {
      "productId": "product-$i",
      "quantity": $((RANDOM % 5 + 1)),
      "price": $((RANDOM % 100 + 10))
    }
  ]
}
EOL
    
    # Start execution
    aws stepfunctions start-execution \
      --state-machine-arn $STATE_MACHINE_ARN \
      --name $EXECUTION_NAME \
      --input file://test-order-$i.json
    
    echo "Started execution $i: $EXECUTION_NAME"
    
    # Small delay to avoid throttling
    sleep 0.5
done

echo "Bulk test completed. Started 10 executions."

# Wait a moment then check execution status
sleep 10

echo "Checking execution status..."
aws stepfunctions list-executions \
  --state-machine-arn $STATE_MACHINE_ARN \
  --max-items 10 \
  --query 'executions[].{Name:name,Status:status,StartDate:startDate}'
EOF

chmod +x bulk_workflow_test.sh
```

2. Update the script with your values:
```bash
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" bulk_workflow_test.sh
sed -i "s/\[your-username\]/[your-username]/g" bulk_workflow_test.sh
```

3. Run the bulk test:
```bash
./bulk_workflow_test.sh
```

### Step 9.2: Monitor Bulk Execution

1. In the Step Functions console, monitor the bulk executions
2. Check your CloudWatch dashboard for performance metrics
3. Observe how the workflows handle concurrent executions
4. Review any throttling or error patterns

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created four Lambda functions for workflow orchestration
- [ ] Built a Standard Step Functions workflow with error handling and parallel processing
- [ ] Created an Express workflow for real-time processing
- [ ] Implemented callback pattern for long-running tasks
- [ ] Successfully tested workflow executions with valid and invalid data
- [ ] Created CloudWatch dashboard for Step Functions monitoring
- [ ] Performed bulk execution testing
- [ ] Applied username prefixing to all resources

### Expected Results

Your Step Functions workflows should:

1. **Execute successfully** with valid input data
2. **Handle errors gracefully** with proper error states and retry logic
3. **Process branches in parallel** for improved performance
4. **Demonstrate retry mechanisms** for transient failures
5. **Show execution history** and state transitions
6. **Provide monitoring metrics** in CloudWatch
7. **Support both Standard and Express** execution types
8. **Handle long-running processes** with callback patterns

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** State machine execution fails with permission errors
- **Console Check**: Verify IAM role permissions in IAM console
- **Console Check**: Check Lambda function execution role
- **Solution**: Ensure Step Functions role can invoke Lambda functions

**Issue:** Workflow doesn't progress through states
- **Console Check**: Review state machine definition syntax
- **Console Debug**: Check execution input/output in execution details
- **Solution**: Verify Lambda functions return proper JSON structure

**Issue:** Parallel execution failures
- **Console Monitor**: Check both parallel branches in graph view
- **Console Debug**: Review individual branch execution logs
- **Solution**: Ensure Lambda functions handle partial input correctly

**Issue:** Express workflow performance issues
- **Console Check**: Verify CloudWatch Logs configuration
- **Console Monitor**: Check execution metrics and duration
- **Solution**: Optimize Lambda function cold starts

---

## Clean Up (Optional)

### Via Console:
1. **Step Functions**: Delete all three state machines
2. **Lambda**: Delete all workflow functions
3. **CloudWatch**: Delete the dashboard
4. **IAM**: Delete the Step Functions role

### Via CLI:
```bash
# Delete Step Functions state machines
aws stepfunctions delete-state-machine --state-machine-arn arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow
aws stepfunctions delete-state-machine --state-machine-arn arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-express-workflow
aws stepfunctions delete-state-machine --state-machine-arn arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-callback-workflow

# Delete Lambda functions
aws lambda delete-function --function-name [your-username]-order-validator
aws lambda delete-function --function-name [your-username]-payment-processor
aws lambda delete-function --function-name [your-username]-inventory-updater
aws lambda delete-function --function-name [your-username]-order-fulfillment
aws lambda delete-function --function-name [your-username]-realtime-validator
aws lambda delete-function --function-name [your-username]-long-running-task
```

---

## Key Takeaways

From this lab, you should understand:

1. **Workflow Orchestration**: How Step Functions coordinate multiple services and business processes
2. **State Machine Design**: Sequential, parallel, and conditional logic patterns for complex workflows
3. **Error Handling**: Retry mechanisms, catch blocks, and graceful degradation strategies
4. **Standard vs Express**: Different workflow types optimized for different use cases
5. **Callback Patterns**: Handling long-running and external processes with task tokens
6. **Monitoring and Debugging**: CloudWatch integration and execution analysis tools
7. **Console vs CLI**: When to use visual workflow design vs programmatic management
8. **Production Considerations**: Performance optimization, error handling, and scalability patterns

### Workflow Pattern Summary

| Aspect | Standard | Express |
|--------|----------|---------|
| **Use Case** | Long-running processes | Real-time processing |
| **Duration** | Up to 1 year | Up to 5 minutes |
| **History** | Full execution history | CloudWatch Logs only |
| **Cost** | Per state transition | Per execution |
| **Retry** | Built-in retry logic | Limited retry capability |
| **Monitoring** | Detailed console view | Metrics-based monitoring |

---

## Next Steps

In the next lab, you will explore comprehensive observability and monitoring patterns using CloudWatch, X-Ray, and other AWS monitoring services to gain deep insights into your serverless applications.