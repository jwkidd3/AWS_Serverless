# Developing Serverless Solutions on AWS - Day 1 - Lab 1
## Deploying a Simple Serverless Application

**Lab Duration:** 60 minutes

---

## Lab Overview

In this lab, you will build and deploy your first serverless application using AWS Lambda and Amazon API Gateway. You'll create a simple REST API that processes requests and returns responses, demonstrating the core concepts of serverless architecture.

## Lab Objectives

By the end of this lab, you will be able to:
- Create and configure an AWS Lambda function
- Set up an Amazon API Gateway to trigger your Lambda function
- Test your serverless application using the AWS Console and external tools
- Understand the basic serverless request/response flow
- Apply username prefixing to AWS resources for shared account management

## Prerequisites

- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- Basic understanding of JSON and HTTP concepts

---

## Lab Environment Setup

### Development Environment
For this lab, you will use AWS Cloud9 as your integrated development environment. Cloud9 provides a browser-based IDE with AWS CLI and other tools pre-installed.

### Username Prefixing
**IMPORTANT:** All AWS resources you create must be prefixed with your assigned username to avoid conflicts in the shared AWS account.

**Example:** If your username is `user3`, name your resources as:
- Lambda function: `user3-hello-world-function`
- API Gateway: `user3-hello-world-api`

---

## Task 1: Set Up Cloud9 Development Environment

### Step 1.1: Launch Cloud9 IDE

1. Navigate to the **AWS Cloud9** service in the AWS Console
2. Click **Create environment**
3. Configure your Cloud9 environment:
   - **Name:** `[your-username]-serverless-dev`
   - **Environment type:** New EC2 instance
   - **Instance type:** t3.small
   - **Platform:** Amazon Linux 2
   - **Cost-saving setting:** After 30 minutes
4. Click **Create environment**
5. Wait for the environment to launch (2-3 minutes)

### Step 1.2: Verify AWS CLI Configuration

1. In the Cloud9 terminal, verify your AWS credentials:
```bash
aws sts get-caller-identity
```

2. Set your default region:
```bash
aws configure set default.region us-east-1
```

---

## Task 2: Create Your First Lambda Function

### Step 2.1: Create the Lambda Function Code

1. In Cloud9, create a new file called `hello-world.py`:

```python
import json
import datetime

def lambda_handler(event, context):
    """
    Simple Lambda function that returns a greeting message
    """
    
    # Extract information from the event
    http_method = event.get('httpMethod', 'Unknown')
    path = event.get('path', 'Unknown')
    
    # Get current timestamp
    timestamp = datetime.datetime.now().isoformat()
    
    # Create response message
    message = {
        'greeting': 'Hello from your serverless application!',
        'timestamp': timestamp,
        'method': http_method,
        'path': path,
        'processed_by': 'AWS Lambda'
    }
    
    # Return proper API Gateway response format
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(message)
    }
```

### Step 2.2: Deploy the Lambda Function

1. Create a deployment package:
```bash
zip function.zip hello-world.py
```

2. Create the Lambda function using AWS CLI:
```bash
aws lambda create-function \
  --function-name [your-username]-hello-world-function \
  --runtime python3.9 \
  --role arn:aws:iam::[ACCOUNT-ID]:role/LabRole \
  --handler hello-world.lambda_handler \
  --zip-file fileb://function.zip \
  --description "Simple serverless hello world function"
```

**Note:** Replace `[ACCOUNT-ID]` with the actual AWS account ID provided by your instructor.

### Step 2.3: Test the Lambda Function

1. Test the function using the AWS CLI:
```bash
aws lambda invoke \
  --function-name [your-username]-hello-world-function \
  output.json
```

2. View the output:
```bash
cat output.json
```

---

## Task 3: Create API Gateway

### Step 3.1: Create the REST API

1. Create a new REST API:
```bash
aws apigateway create-rest-api \
  --name "[your-username]-hello-world-api" \
  --description "Simple serverless API"
```

2. Note the `api-id` from the response - you'll need it for subsequent commands.

3. Get the root resource ID:
```bash
aws apigateway get-resources \
  --rest-api-id [your-api-id]
```

### Step 3.2: Create API Resource and Method

1. Create a new resource under the root:
```bash
aws apigateway create-resource \
  --rest-api-id [your-api-id] \
  --parent-id [root-resource-id] \
  --path-part hello
```

2. Create a GET method on the resource:
```bash
aws apigateway put-method \
  --rest-api-id [your-api-id] \
  --resource-id [hello-resource-id] \
  --http-method GET \
  --authorization-type NONE
```

### Step 3.3: Configure Lambda Integration

1. Set up the integration between API Gateway and Lambda:
```bash
aws apigateway put-integration \
  --rest-api-id [your-api-id] \
  --resource-id [hello-resource-id] \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-hello-world-function/invocations
```

2. Grant API Gateway permission to invoke your Lambda function:
```bash
aws lambda add-permission \
  --function-name [your-username]-hello-world-function \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:[ACCOUNT-ID]:[your-api-id]/*/*"
```

### Step 3.4: Deploy the API

1. Create a deployment:
```bash
aws apigateway create-deployment \
  --rest-api-id [your-api-id] \
  --stage-name prod
```

2. Your API endpoint URL will be:
```
https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/hello
```

---

## Task 4: Test Your Serverless Application

### Step 4.1: Test Using cURL

1. Test your API endpoint:
```bash
curl https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/hello
```

2. You should receive a JSON response similar to:
```json
{
  "greeting": "Hello from your serverless application!",
  "timestamp": "2025-07-16T10:30:00.123456",
  "method": "GET",
  "path": "/hello",
  "processed_by": "AWS Lambda"
}
```

### Step 4.2: Test Using AWS Console

1. Navigate to **Lambda** service in AWS Console
2. Find your function: `[your-username]-hello-world-function`
3. Click on the function name
4. Go to the **Test** tab
5. Create a new test event:
   - **Event template:** API Gateway AWS Proxy
   - **Event name:** TestEvent
   - Modify the test event to include:
   ```json
   {
     "httpMethod": "GET",
     "path": "/hello"
   }
   ```
6. Click **Test** and verify the response

### Step 4.3: Monitor Function Execution

1. In the Lambda console, navigate to the **Monitor** tab
2. Review the CloudWatch metrics:
   - Invocations
   - Duration
   - Error count
3. Click **View logs in CloudWatch** to see detailed execution logs

---

## Task 5: Explore and Modify

### Step 5.1: Add Error Handling

1. Modify your `hello-world.py` file to include error handling:

```python
import json
import datetime
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Enhanced Lambda function with error handling
    """
    try:
        # Log the incoming event
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract query parameters if they exist
        query_params = event.get('queryStringParameters') or {}
        name = query_params.get('name', 'World')
        
        # Extract information from the event
        http_method = event.get('httpMethod', 'Unknown')
        path = event.get('path', 'Unknown')
        
        # Get current timestamp
        timestamp = datetime.datetime.now().isoformat()
        
        # Create response message
        message = {
            'greeting': f'Hello {name} from your serverless application!',
            'timestamp': timestamp,
            'method': http_method,
            'path': path,
            'processed_by': 'AWS Lambda'
        }
        
        logger.info(f"Processing successful for: {name}")
        
        # Return proper API Gateway response format
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(message)
        }
        
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'Please try again later'
            })
        }
```

### Step 5.2: Update the Lambda Function

1. Create a new deployment package:
```bash
zip function-v2.zip hello-world.py
```

2. Update the function:
```bash
aws lambda update-function-code \
  --function-name [your-username]-hello-world-function \
  --zip-file fileb://function-v2.zip
```

### Step 5.3: Test with Query Parameters

1. Test the updated function with a name parameter:
```bash
curl "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/hello?name=YourName"
```

---

## Lab Verification

### Verification Checklist

Verify that you have successfully completed the following:

- [ ] Created a Cloud9 development environment
- [ ] Created a Lambda function with proper username prefix
- [ ] Created an API Gateway with proper username prefix
- [ ] Successfully integrated API Gateway with Lambda
- [ ] Deployed the API to a stage
- [ ] Tested the API endpoint and received valid JSON responses
- [ ] Added error handling and query parameter support
- [ ] Verified function execution in CloudWatch logs

### Expected Results

Your serverless application should:
1. Respond to HTTP GET requests at your API endpoint
2. Return JSON responses with greeting messages
3. Handle query parameters (name parameter)
4. Log execution details to CloudWatch
5. Use proper HTTP status codes
6. Include CORS headers for web browser compatibility

---

## Troubleshooting

### Common Issues and Solutions

**Issue:** Lambda function returns "Internal Server Error"
- **Solution:** Check CloudWatch logs for detailed error messages
- Verify the function code syntax
- Ensure proper JSON formatting in return statements

**Issue:** API Gateway returns "Missing Authentication Token"
- **Solution:** Verify the API endpoint URL is correct
- Ensure the API has been deployed to the 'prod' stage
- Check that the resource path matches your request

**Issue:** Permission denied errors
- **Solution:** Verify the Lambda execution role has proper permissions
- Check that API Gateway has permission to invoke the Lambda function

**Issue:** Function not found
- **Solution:** Verify the function name includes your username prefix
- Check that you're working in the correct AWS region

---

## Clean Up (Optional)

If you want to clean up resources after the lab:

1. Delete the API Gateway:
```bash
aws apigateway delete-rest-api --rest-api-id [your-api-id]
```

2. Delete the Lambda function:
```bash
aws lambda delete-function --function-name [your-username]-hello-world-function
```

**Note:** Keep these resources for future labs in this course.

---

## Key Takeaways

From this lab, you should understand:
1. **Serverless Fundamentals:** How Lambda functions process events and return responses
2. **API Gateway Integration:** How to expose Lambda functions as HTTP APIs
3. **Event-Driven Architecture:** How API Gateway events trigger Lambda executions
4. **Monitoring and Logging:** How to use CloudWatch for observability
5. **Error Handling:** Importance of proper exception handling in serverless functions
6. **Resource Naming:** Best practices for resource organization in shared environments

---

## Next Steps

In the next lab, you will explore Infrastructure as Code approaches to deploy serverless applications, making the deployment process more repeatable and maintainable.
