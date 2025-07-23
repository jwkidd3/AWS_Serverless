import json
import boto3
import uuid
import os
import logging
import time
from botocore.exceptions import ClientError

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(level=getattr(logging, log_level))
logger = logging.getLogger(__name__)

def lambda_handler(event, context):
    """
    Triggers Step Functions workflow with comprehensive input validation and error handling
    """
    
    start_time = time.time()
    username = os.environ.get('USERNAME', 'unknown')
    state_machine_arn = os.environ.get('STATE_MACHINE_ARN')
    
    logger.info(f"Workflow trigger initiated for user: {username}")
    logger.debug(f"Received event: {json.dumps(event, default=str)}")
    
    if not state_machine_arn:
        logger.error("STATE_MACHINE_ARN environment variable not set")
        return create_error_response(500, "Configuration error: STATE_MACHINE_ARN not found")
    
    try:
        stepfunctions = boto3.client('stepfunctions')
        
        # Extract input from API Gateway event or direct invocation
        if event.get('body'):
            try:
                body = json.loads(event['body'])
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in request body: {str(e)}")
                return create_error_response(400, "Invalid JSON in request body")
        else:
            body = event
        
        # Validate required fields
        user_id = body.get('userId')
        data_type = body.get('dataType')
        
        if not user_id:
            return create_error_response(400, "Missing required field: userId")
        
        if not data_type:
            return create_error_response(400, "Missing required field: dataType")
        
        # Validate data_type against allowed values
        allowed_data_types = ['sales_data', 'customer_data', 'inventory_data', 'analytics_data', 'general']
        if data_type not in allowed_data_types:
            logger.warning(f"Unknown data_type '{data_type}', using 'general'")
            data_type = 'general'
        
        # Prepare Step Functions input with additional metadata
        workflow_input = {
            'userId': user_id,
            'dataType': data_type,
            'requestMetadata': {
                'requestId': context.aws_request_id,
                'triggerSource': 'api_gateway',
                'username': username,
                'timestamp': int(time.time()),
                'apiVersion': '1.0'
            }
        }
        
        # Add optional fields if present
        if 'priority' in body:
            workflow_input['priority'] = body['priority']
        
        if 'options' in body:
            workflow_input['options'] = body['options']
        
        # Generate execution name with timestamp and random suffix for uniqueness
        execution_name = f"{username}-{data_type}-{int(time.time())}-{uuid.uuid4().hex[:8]}"
        
        logger.info(f"Starting Step Functions execution: {execution_name}")
        logger.debug(f"Workflow input: {json.dumps(workflow_input)}")
        
        # Start Step Functions execution
        try:
            response = stepfunctions.start_execution(
                stateMachineArn=state_machine_arn,
                name=execution_name,
                input=json.dumps(workflow_input)
            )
            
            execution_arn = response['executionArn']
            logger.info(f"Step Functions execution started successfully: {execution_arn}")
            
            # Create success response
            success_response = {
                'message': 'Workflow started successfully',
                'executionArn': execution_arn,
                'executionName': execution_name,
                'stateMachineArn': state_machine_arn,
                'input': workflow_input,
                'metadata': {
                    'username': username,
                    'requestId': context.aws_request_id,
                    'startedAt': response.get('startDate', '').isoformat() if response.get('startDate') else None
                }
            }
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'X-Request-ID': context.aws_request_id
                },
                'body': json.dumps(success_response, default=str)
            }
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            logger.error(f"AWS Step Functions error [{error_code}]: {error_message}")
            
            if error_code == 'StateMachineDoesNotExist':
                return create_error_response(500, "Step Functions state machine not found")
            elif error_code == 'InvalidParameterValue':
                return create_error_response(400, f"Invalid parameter: {error_message}")
            elif error_code == 'ExecutionLimitExceeded':
                return create_error_response(429, "Too many concurrent executions")
            else:
                return create_error_response(500, f"Step Functions error: {error_message}")
        
    except Exception as e:
        total_duration = time.time() - start_time
        logger.error(f"Unexpected error in workflow trigger: {str(e)}")
        logger.error(f"Function failed after {total_duration:.2f} seconds")
        
        return create_error_response(500, f"Internal server error: {str(e)}")

def create_error_response(status_code, message):
    """Create a standardized error response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'error': message,
            'statusCode': status_code,
            'timestamp': int(time.time())
        })
    }
