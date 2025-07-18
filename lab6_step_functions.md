# Developing Serverless Solutions on AWS - Day 2 - Lab 6
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

## Task 1: Create Lambda Functions for Workflow

### Step 1.1: Create Order Validation Function

1. Create directory for order validation:
```bash
mkdir ~/environment/[your-username]-order-validator
cd ~/environment/[your-username]-order-validator
```

2. Create `order_validator.py`:

```python
import json
import random
import time

def lambda_handler(event, context):
    """
    Validates order data and customer information
    """
    
    print(f"Validating order: {json.dumps(event, indent=2)}")
    
    # Extract order details
    order_id = event.get('orderId', 'unknown')
    customer_id = event.get('customerId', 'unknown')
    amount = event.get('amount', 0)
    items = event.get('items', [])
    
    # Simulate validation processing time
    time.sleep(random.uniform(0.5, 1.5))
    
    # Validation logic
    validation_errors = []
    
    # Check required fields
    if not order_id or order_id == 'unknown':
        validation_errors.append("Missing order ID")
    
    if not customer_id or customer_id == 'unknown':
        validation_errors.append("Missing customer ID")
    
    if amount <= 0:
        validation_errors.append("Invalid amount")
    
    if not items:
        validation_errors.append("No items in order")
    
    # Check item availability (simulate)
    for item in items:
        if random.random() < 0.1:  # 10% chance of unavailable item
            validation_errors.append(f"Item {item.get('productId', 'unknown')} is out of stock")
    
    # Determine validation result
    is_valid = len(validation_errors) == 0
    
    result = {
        'orderId': order_id,
        'customerId': customer_id,
        'amount': amount,
        'items': items,
        'isValid': is_valid,
        'validationErrors': validation_errors,
        'validationTimestamp': time.time(),
        'validatedBy': 'order-validator'
    }
    
    if is_valid:
        print(f"✅ Order {order_id} validation passed")
    else:
        print(f"❌ Order {order_id} validation failed: {validation_errors}")
    
    return result
```

3. Deploy order validator:
```bash
zip order-validator.zip order_validator.py

aws lambda create-function \
  --function-name [your-username]-order-validator \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler order_validator.lambda_handler \
  --zip-file fileb://order-validator.zip \
  --timeout 30 \
  --description "Validates order data and customer information"
```

### Step 1.2: Create Payment Processor Function

1. Create directory for payment processor:
```bash
mkdir ~/environment/[your-username]-payment-processor
cd ~/environment/[your-username]-payment-processor
```

2. Create `payment_processor.py`:

```python
import json
import random
import time
import uuid

def lambda_handler(event, context):
    """
    Processes payment for validated orders
    """
    
    print(f"Processing payment: {json.dumps(event, indent=2)}")
    
    # Extract order details
    order_id = event.get('orderId', 'unknown')
    customer_id = event.get('customerId', 'unknown')
    amount = event.get('amount', 0)
    
    # Simulate payment processing time
    time.sleep(random.uniform(1.0, 3.0))
    
    # Simulate payment success/failure
    payment_success = random.random() > 0.15  # 85% success rate
    
    if payment_success:
        payment_id = f"pay_{uuid.uuid4().hex[:8]}"
        status = "SUCCESS"
        message = "Payment processed successfully"
        print(f"💳 Payment successful for order {order_id}: {payment_id}")
    else:
        payment_id = None
        status = "FAILED"
        # Random failure reasons
        failure_reasons = [
            "Insufficient funds",
            "Invalid payment method",
            "Card expired",
            "Payment gateway timeout"
        ]
        message = random.choice(failure_reasons)
        print(f"❌ Payment failed for order {order_id}: {message}")
    
    result = {
        'orderId': order_id,
        'customerId': customer_id,
        'amount': amount,
        'paymentId': payment_id,
        'status': status,
        'message': message,
        'paymentTimestamp': time.time(),
        'processedBy': 'payment-processor'
    }
    
    # If payment failed, raise an exception for Step Functions error handling
    if not payment_success:
        result['errorType'] = 'PaymentError'
        raise Exception(json.dumps(result))
    
    return result
```

3. Deploy payment processor:
```bash
zip payment-processor.zip payment_processor.py

aws lambda create-function \
  --function-name [your-username]-payment-processor \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler payment_processor.lambda_handler \
  --zip-file fileb://payment-processor.zip \
  --timeout 30 \
  --description "Processes payments for validated orders"
```

### Step 1.3: Create Inventory Updater Function

1. Create directory for inventory updater:
```bash
mkdir ~/environment/[your-username]-inventory-updater
cd ~/environment/[your-username]-inventory-updater
```

2. Create `inventory_updater.py`:

```python
import json
import random
import time

def lambda_handler(event, context):
    """
    Updates inventory after successful payment
    """
    
    print(f"Updating inventory: {json.dumps(event, indent=2)}")
    
    # Extract order details
    order_id = event.get('orderId', 'unknown')
    items = event.get('items', [])
    
    # Simulate inventory update processing
    time.sleep(random.uniform(0.3, 1.0))
    
    inventory_updates = []
    
    for item in items:
        product_id = item.get('productId', 'unknown')
        quantity = item.get('quantity', 0)
        
        # Simulate inventory update
        previous_stock = random.randint(50, 200)
        new_stock = previous_stock - quantity
        
        update_record = {
            'productId': product_id,
            'quantityReduced': quantity,
            'previousStock': previous_stock,
            'newStock': new_stock,
            'updateTimestamp': time.time()
        }
        
        inventory_updates.append(update_record)
        print(f"📦 Updated inventory for {product_id}: {previous_stock} -> {new_stock}")
    
    result = {
        'orderId': order_id,
        'inventoryUpdates': inventory_updates,
        'totalItemsProcessed': len(items),
        'updateTimestamp': time.time(),
        'updatedBy': 'inventory-updater'
    }
    
    return result
```

3. Deploy inventory updater:
```bash
zip inventory-updater.zip inventory_updater.py

aws lambda create-function \
  --function-name [your-username]-inventory-updater \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler inventory_updater.lambda_handler \
  --zip-file fileb://inventory-updater.zip \
  --timeout 30 \
  --description "Updates inventory after successful payment"
```

### Step 1.4: Create Order Fulfillment Function

1. Create directory for order fulfillment:
```bash
mkdir ~/environment/[your-username]-order-fulfillment
cd ~/environment/[your-username]-order-fulfillment
```

2. Create `order_fulfillment.py`:

```python
import json
import random
import time
import uuid

def lambda_handler(event, context):
    """
    Handles order fulfillment and shipping
    """
    
    print(f"Processing fulfillment: {json.dumps(event, indent=2)}")
    
    # Extract order details
    order_id = event.get('orderId', 'unknown')
    customer_id = event.get('customerId', 'unknown')
    items = event.get('items', [])
    
    # Simulate fulfillment processing
    time.sleep(random.uniform(1.0, 2.0))
    
    # Generate tracking information
    tracking_number = f"TRK{uuid.uuid4().hex[:8].upper()}"
    estimated_delivery = time.time() + (random.randint(2, 7) * 24 * 3600)  # 2-7 days
    
    # Random shipping carrier
    carriers = ["UPS", "FedEx", "USPS", "DHL"]
    carrier = random.choice(carriers)
    
    result = {
        'orderId': order_id,
        'customerId': customer_id,
        'fulfillmentStatus': 'SHIPPED',
        'trackingNumber': tracking_number,
        'carrier': carrier,
        'estimatedDelivery': estimated_delivery,
        'itemsShipped': len(items),
        'fulfillmentTimestamp': time.time(),
        'fulfilledBy': 'order-fulfillment'
    }
    
    print(f"📦 Order {order_id} shipped with tracking {tracking_number}")
    
    return result
```

3. Deploy order fulfillment:
```bash
zip order-fulfillment.zip order_fulfillment.py

aws lambda create-function \
  --function-name [your-username]-order-fulfillment \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler order_fulfillment.lambda_handler \
  --zip-file fileb://order-fulfillment.zip \
  --timeout 30 \
  --description "Handles order fulfillment and shipping"
```

---

## Task 2: Create Order Processing Workflow

### Step 2.1: Create IAM Role for Step Functions

1. Create IAM role for Step Functions:
```bash
aws iam create-role \
  --role-name [your-username]-stepfunctions-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "states.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'
```

2. Attach necessary policies:
```bash
aws iam attach-role-policy \
  --role-name [your-username]-stepfunctions-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaRole

# Create custom policy for additional permissions
cat > stepfunctions-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "sqs:SendMessage",
                "sns:Publish",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy \
  --role-name [your-username]-stepfunctions-role \
  --policy-name StepFunctionsExecutionPolicy \
  --policy-document file://stepfunctions-policy.json
```

### Step 2.2: Create Order Processing State Machine

1. Create the state machine definition:
```bash
cat > order-processing-workflow.json << 'EOF'
{
  "Comment": "Order processing workflow with error handling",
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
          "Variable": "$.isValid",
          "BooleanEquals": true,
          "Next": "ProcessPayment"
        }
      ],
      "Default": "ValidationFailed"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-payment-processor",
      "Next": "ParallelProcessing",
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
          "Next": "PaymentFailed",
          "ResultPath": "$.error"
        }
      ]
    },
    "ParallelProcessing": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "UpdateInventory",
          "States": {
            "UpdateInventory": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-inventory-updater",
              "End": true,
              "Retry": [
                {
                  "ErrorEquals": ["States.ALL"],
                  "IntervalSeconds": 1,
                  "MaxAttempts": 2,
                  "BackoffRate": 2.0
                }
              ]
            }
          }
        },
        {
          "StartAt": "ProcessFulfillment",
          "States": {
            "ProcessFulfillment": {
              "Type": "Task",
              "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-order-fulfillment",
              "End": true,
              "Retry": [
                {
                  "ErrorEquals": ["States.ALL"],
                  "IntervalSeconds": 1,
                  "MaxAttempts": 2,
                  "BackoffRate": 2.0
                }
              ]
            }
          }
        }
      ],
      "Next": "OrderComplete",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "ProcessingFailed",
          "ResultPath": "$.error"
        }
      ]
    },
    "OrderComplete": {
      "Type": "Pass",
      "Result": {
        "status": "ORDER_COMPLETED",
        "message": "Order processed successfully"
      },
      "ResultPath": "$.orderResult",
      "End": true
    },
    "ValidationFailed": {
      "Type": "Pass",
      "Result": {
        "status": "VALIDATION_FAILED",
        "message": "Order validation failed"
      },
      "ResultPath": "$.orderResult",
      "End": true
    },
    "PaymentFailed": {
      "Type": "Pass",
      "Result": {
        "status": "PAYMENT_FAILED", 
        "message": "Payment processing failed"
      },
      "ResultPath": "$.orderResult",
      "End": true
    },
    "ProcessingFailed": {
      "Type": "Pass",
      "Result": {
        "status": "PROCESSING_FAILED",
        "message": "Order processing failed after payment"
      },
      "ResultPath": "$.orderResult",
      "End": true
    }
  }
}
EOF
```

2. Replace placeholders in the state machine definition:
```bash
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" order-processing-workflow.json
sed -i "s/\[your-username\]/[your-username]/g" order-processing-workflow.json
```

3. Create the state machine:
```bash
aws stepfunctions create-state-machine \
  --name "[your-username]-order-processing-workflow" \
  --definition file://order-processing-workflow.json \
  --role-arn arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-stepfunctions-role \
  --type STANDARD
```

---

## Task 3: Create Express Workflow for Real-time Processing

### Step 3.1: Create Real-time Validator Function

1. Create directory for real-time validator:
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
    Fast validation for real-time processing
    """
    
    # Extract data
    user_id = event.get('userId', 'unknown')
    action = event.get('action', 'unknown')
    timestamp = event.get('timestamp', time.time())
    
    # Quick validation rules
    is_valid = True
    errors = []
    
    if not user_id or user_id == 'unknown':
        is_valid = False
        errors.append("Missing user ID")
    
    if action not in ['login', 'purchase', 'view', 'click']:
        is_valid = False
        errors.append("Invalid action type")
    
    # Add processing metadata
    result = event.copy()
    result.update({
        'isValid': is_valid,
        'validationErrors': errors,
        'validatedAt': time.time(),
        'processingLatency': time.time() - timestamp
    })
    
    return result
```

3. Deploy real-time validator:
```bash
zip realtime-validator.zip realtime_validator.py

aws lambda create-function \
  --function-name [your-username]-realtime-validator \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler realtime_validator.lambda_handler \
  --zip-file fileb://realtime-validator.zip \
  --timeout 10 \
  --description "Fast validation for real-time processing"
```

### Step 3.2: Create Express Workflow

1. Create express workflow definition:
```bash
cat > express-workflow.json << 'EOF'
{
  "Comment": "Express workflow for real-time event processing",
  "StartAt": "ValidateEvent",
  "States": {
    "ValidateEvent": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-realtime-validator",
      "Next": "CheckValidation"
    },
    "CheckValidation": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.isValid",
          "BooleanEquals": true,
          "Next": "ProcessValidEvent"
        }
      ],
      "Default": "InvalidEvent"
    },
    "ProcessValidEvent": {
      "Type": "Pass",
      "Result": {
        "status": "PROCESSED",
        "message": "Event processed successfully"
      },
      "ResultPath": "$.result",
      "End": true
    },
    "InvalidEvent": {
      "Type": "Pass",
      "Result": {
        "status": "REJECTED",
        "message": "Event validation failed"
      },
      "ResultPath": "$.result",
      "End": true
    }
  }
}
EOF
```

2. Replace placeholders:
```bash
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" express-workflow.json
sed -i "s/\[your-username\]/[your-username]/g" express-workflow.json
```

3. Create the express state machine:
```bash
aws stepfunctions create-state-machine \
  --name "[your-username]-express-workflow" \
  --definition file://express-workflow.json \
  --role-arn arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-stepfunctions-role \
  --type EXPRESS \
  --logging-configuration level=ALL,includeExecutionData=true,destinations='[{"cloudWatchLogsLogGroup":{"logGroupArn":"arn:aws:logs:us-east-1:[ACCOUNT-ID]:log-group:/aws/stepfunctions/[your-username]-express"}}]'
```

---

## Task 4: Test Workflow Executions

### Step 4.1: Test Standard Workflow

1. Create test input for successful order:
```bash
cat > successful-order.json << 'EOF'
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
EOF
```

2. Execute the standard workflow:
```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow \
  --name "test-execution-$(date +%s)" \
  --input file://successful-order.json
```

3. Note the execution ARN and check status:
```bash
aws stepfunctions describe-execution \
  --execution-arn [execution-arn-from-above]
```

### Step 4.2: Test Express Workflow

1. Create test input for express workflow:
```bash
cat > realtime-event.json << 'EOF'
{
  "userId": "user-123",
  "action": "purchase",
  "timestamp": 1627845600,
  "metadata": {
    "product": "widget-456",
    "amount": 29.99
  }
}
EOF
```

2. Execute the express workflow:
```bash
aws stepfunctions start-sync-execution \
  --state-machine-arn arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-express-workflow \
  --name "express-test-$(date +%s)" \
  --input file://realtime-event.json
```

### Step 4.3: Test Error Handling

1. Create invalid order to test error handling:
```bash
cat > invalid-order.json << 'EOF'
{
  "orderId": "",
  "customerId": "",
  "amount": -10,
  "items": []
}
EOF
```

2. Execute with invalid data:
```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow \
  --name "error-test-$(date +%s)" \
  --input file://invalid-order.json
```

---

## Task 5: Implement Callback Pattern

### Step 5.1: Create Long-Running Task Function

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

stepfunctions = boto3.client('stepfunctions')

def lambda_handler(event, context):
    """
    Simulates a long-running task that will callback to Step Functions
    """
    
    print(f"Starting long-running task: {json.dumps(event, indent=2)}")
    
    # Extract task token
    task_token = event.get('taskToken')
    task_id = str(uuid.uuid4())
    
    # In a real scenario, this would start an external process
    # For demo, we'll simulate by scheduling a callback
    
    print(f"Task {task_id} started. Will complete asynchronously.")
    
    # Store task information (in real scenario, save to database)
    task_info = {
        'taskId': task_id,
        'taskToken': task_token,
        'status': 'IN_PROGRESS',
        'startTime': event.get('timestamp', 'unknown')
    }
    
    # Return task info immediately
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

### Step 5.2: Create Callback Workflow

1. Create callback workflow definition:
```bash
cat > callback-workflow.json << 'EOF'
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
        "message": "Task timed out"
      },
      "End": true
    },
    "TaskFailed": {
      "Type": "Pass",
      "Result": {
        "status": "FAILED",
        "message": "Task failed"
      },
      "End": true
    }
  }
}
EOF
```

2. Replace placeholders and create callback workflow:
```bash
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" callback-workflow.json
sed -i "s/\[your-username\]/[your-username]/g" callback-workflow.json

aws stepfunctions create-state-machine \
  --name "[your-username]-callback-workflow" \
  --definition file://callback-workflow.json \
  --role-arn arn:aws:iam::[ACCOUNT-ID]:role/[your-username]-stepfunctions-role \
  --type STANDARD
```

---

## Task 6: Monitor and Debug Workflows

### Step 6.1: Create CloudWatch Dashboard

1. Create monitoring dashboard:
```bash
cat > stepfunctions-dashboard.json << 'EOF'
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
                    [ "AWS/States", "ExecutionsSucceeded", "StateMachineArn", "arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow" ],
                    [ ".", "ExecutionsFailed", ".", "." ],
                    [ ".", "ExecutionsTimedOut", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Order Processing Workflow Executions"
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
                    [ "AWS/States", "ExecutionTime", "StateMachineArn", "arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Average Execution Time"
            }
        }
    ]
}
EOF

sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" stepfunctions-dashboard.json
sed -i "s/\[your-username\]/[your-username]/g" stepfunctions-dashboard.json

aws cloudwatch put-dashboard \
  --dashboard-name "[your-username]-stepfunctions-monitoring" \
  --dashboard-body file://stepfunctions-dashboard.json
```

### Step 6.2: Analyze Execution History

1. List recent executions:
```bash
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow \
  --max-items 10
```

2. Get execution history for detailed analysis:
```bash
aws stepfunctions get-execution-history \
  --execution-arn [execution-arn] \
  --max-items 50
```

---

## Task 7: Performance Testing

### Step 7.1: Bulk Execution Test

1. Create bulk test script:
```bash
cat > bulk_test.sh << 'EOF'
#!/bin/bash

STATE_MACHINE_ARN="arn:aws:states:us-east-1:[ACCOUNT-ID]:stateMachine:[your-username]-order-processing-workflow"

echo "Starting bulk execution test..."

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
EOF

chmod +x bulk_test.sh
```

2. Replace placeholder and run test:
```bash
sed -i "s/\[ACCOUNT-ID\]/$(aws sts get-caller-identity --query Account --output text)/g" bulk_test.sh
sed -i "s/\[your-username\]/[your-username]/g" bulk_test.sh

./bulk_test.sh
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created four Lambda functions for workflow orchestration
- [ ] Built a Standard Step Functions workflow with error handling
- [ ] Created an Express workflow for real-time processing
- [ ] Implemented callback pattern for long-running tasks
- [ ] Successfully tested workflow executions with valid and invalid data
- [ ] Created CloudWatch dashboard for monitoring
- [ ] Performed bulk execution testing
- [ ] Applied username prefixing to all resources

### Expected Results

Your Step Functions workflows should:
1. Execute successfully with valid input data
2. Handle errors gracefully with proper error states
3. Process multiple branches in parallel
4. Demonstrate retry logic for transient failures
5. Show execution history and state transitions
6. Provide monitoring metrics in CloudWatch
7. Support both Standard and Express execution types

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** State machine execution fails with permission errors
- **Solution:** Verify IAM role has proper permissions for Lambda invocation
- Check that Lambda functions exist and are correctly named
- Ensure Step Functions service role is correctly configured

**Issue:** Workflow doesn't progress through states
- **Solution:** Check state machine definition for syntax errors
- Verify Lambda function returns proper JSON structure
- Review execution history for specific error details

**Issue:** Parallel execution failures
- **Solution:** Check that both parallel branches can execute independently
- Verify Lambda functions handle partial input correctly
- Review timeout settings for parallel tasks

**Issue:** Express workflow not executing
- **Solution:** Verify CloudWatch Logs are properly configured
- Check that express workflow uses sync execution
- Ensure proper IAM permissions for logging

---

## Clean Up (Optional)

To clean up resources after the lab:

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

# Delete IAM role
aws iam delete-role-policy --role-name [your-username]-stepfunctions-role --policy-name StepFunctionsExecutionPolicy
aws iam detach-role-policy --role-name [your-username]-stepfunctions-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaRole
aws iam delete-role --role-name [your-username]-stepfunctions-role

# Delete CloudWatch dashboard
aws cloudwatch delete-dashboards --dashboard-names [your-username]-stepfunctions-monitoring
```

---

## Key Takeaways

From this lab, you should understand:
1. **Workflow Orchestration:** How Step Functions coordinate multiple services
2. **State Machine Design:** Sequential, parallel, and conditional logic patterns
3. **Error Handling:** Retry mechanisms, catch blocks, and graceful degradation
4. **Standard vs Express:** Different workflow types for different use cases
5. **Callback Patterns:** Handling long-running and external processes
6. **Monitoring:** CloudWatch integration for workflow observability

---

## Next Steps

In the next lab, you will explore observability and monitoring patterns to gain comprehensive insights into your serverless applications.