# Developing Serverless Solutions on AWS - Day 1 - Lab 1

## Lab 1: Deploying a Simple Serverless Application

**Duration:** 60 minutes

### Learning Objectives
By the end of this lab, you will be able to:
- Create and deploy a Lambda function using Cloud9
- Set up API Gateway to expose Lambda functions as HTTP endpoints
- Test serverless applications using AWS CLI and web browsers
- Monitor function execution through CloudWatch logs
- Apply proper error handling in serverless functions

### Prerequisites
- Access to AWS Console with provided credentials
- Basic understanding of AWS services
- Familiarity with command line interface

---

## Lab Setup

### Username Prefixing for All Resources
**IMPORTANT:** All resources must include your username prefix to avoid conflicts in the shared AWS environment.

**Example:** If your username is `user3`, name your resources as:
- Lambda function: `user3-hello-world-function`
- API Gateway: `user3-hello-world-api`

---

## Task 1: Set Up Development Environment

### Step 1.1: Access Cloud9

1. Open the AWS Console and navigate to **Cloud9**
2. Click **Open IDE** for your pre-configured environment
3. Wait for the environment to load completely
4. Verify you have terminal access at the bottom of the screen

### Step 1.2: Verify AWS CLI Configuration

1. Check your AWS credentials:
```bash
aws sts get-caller-identity
```

2. Verify your region:
```bash
aws configure get region
```

3. Set region if needed:
```bash
aws configure set region us-east-1
```

---

## Task 2: Create Lambda Function

### Step 2.1: Create Function Code

1. Create a directory for your project:
```bash
mkdir ~/environment/[your-username]-serverless-app
cd ~/environment/[your-username]-serverless-app
```

2. In Cloud9, create a new file called `hello-world.py`:

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

1. Test the function using the AWS CLI (no payload file needed):
```bash
aws lambda invoke \
  --function-name [your-username]-hello-world-function \
  output.json
```

2. View the output:
```bash
cat output.json
```

3. For testing with specific event data, use the Lambda console:
   - Go to Lambda console
   - Select your function
   - Click **Test**
   - Create test event with:
```json
{
  "httpMethod": "GET",
  "path": "/hello"
}
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

1. Set up Lambda integration:
```bash
aws apigateway put-integration \
  --rest-api-id [your-api-id] \
  --resource-id [hello-resource-id] \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:[ACCOUNT-ID]:function:[your-username]-hello-world-function/invocations"
```

2. Grant API Gateway permission to invoke Lambda:
```bash
aws lambda add-permission \
  --function-name [your-username]-hello-world-function \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:[ACCOUNT-ID]:[your-api-id]/*/*"
```

---

## Task 4: Deploy and Test API

### Step 4.1: Deploy the API

1. Create a deployment:
```bash
aws apigateway create-deployment \
  --rest-api-id [your-api-id] \
  --stage-name prod
```

2. Your API endpoint will be:
```
https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/hello
```

### Step 4.2: Test the API

1. Test using curl:
```bash
curl "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/hello"
```

2. If you get "internal server error", check CloudWatch logs:
```bash
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/[your-username]-hello-world-function" \
  --order-by LastEventTime \
  --descending \
  --max-items 1
```

3. Get the latest log events:
```bash
aws logs get-log-events \
  --log-group-name "/aws/lambda/[your-username]-hello-world-function" \
  --log-stream-name [latest-log-stream-name]
```

4. **Common Fix:** Update your Lambda function to handle missing event fields:

```python
import json
import datetime

def lambda_handler(event, context):
    """
    Simple Lambda function that returns a greeting message
    """
    
    # Safely extract information from the event
    http_method = event.get('httpMethod', 'GET')
    path = event.get('path', '/hello')
    
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

5. Update your function:
```bash
zip function-fixed.zip hello-world.py
aws lambda update-function-code \
  --function-name [your-username]-hello-world-function \
  --zip-file fileb://function-fixed.zip
```

6. Test again:
```bash
curl "https://[your-api-id].execute-api.us-east-1.amazonaws.com/prod/hello"
```

### Step 4.3: Test Lambda Function Directly

1. Test Lambda function directly without payload:
```bash
aws lambda invoke \
  --function-name [your-username]-hello-world-function \
  lambda-output.json

cat lambda-output.json
```

2. For testing with API Gateway event structure, use the Lambda console:
   - Go to AWS Lambda console
   - Select your function `[your-username]-hello-world-function`
   - Click **Test** tab
   - Click **Create new test event**
   - Choose **API Gateway AWS Proxy** template
   - Name it "APIGatewayTest"
   - Click **Create** and then **Test**

### Step 4.4: Monitor Function Execution

1. View CloudWatch logs:
```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/[your-username]-hello-world-function"
```

2. Get recent log events:
```bash
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/[your-username]-hello-world-function"
```

---

## Task 5: Enhance and Test

### Step 5.1: Add Error Handling and Query Parameters

1. Modify your `hello-world.py` file:

```python
import json
import datetime
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Enhanced Lambda function with error handling and query parameters
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
            'processed_by': 'AWS Lambda',
            'context': {
                'request_id': context.aws_request_id,
                'function_name': context.function_name,
                'memory_limit': context.memory_limit_in_mb
            }
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
                'message': 'Please try again later',
                'timestamp': datetime.datetime.now().isoformat()
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

2. Test error handling by creating an invalid test:
```bash
cat > error-test-payload.json << 'EOF'
{
  "httpMethod": "GET",
  "path": "/hello",
  "queryStringParameters": {"name": "TestUser"},
  "body": "invalid json"
}
EOF

aws lambda invoke \
  --function-name [your-username]-hello-world-function \
  --payload file://error-test-payload.json \
  error-output.json

cat error-output.json
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

**Issue:** Invalid base64 payload error
- **Solution:** Use `file://` prefix when invoking with payload files
- Ensure payload JSON is properly formatted

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
6. **Testing Strategies:** Multiple ways to test serverless applications
7. **Resource Management:** Using username prefixes in shared environments

### Next Steps

In the next lab, you will learn about Infrastructure as Code and deploy more complex serverless applications using AWS SAM and CloudFormation templates.