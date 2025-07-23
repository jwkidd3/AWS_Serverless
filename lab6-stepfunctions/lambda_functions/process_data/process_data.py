import json
import random
import time
import os
import logging

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(level=getattr(logging, log_level))
logger = logging.getLogger(__name__)

def lambda_handler(event, context):
    """
    Simple data processing function with comprehensive logging and error handling
    """
    
    start_time = time.time()
    username = os.environ.get('USERNAME', 'unknown')
    
    # Log incoming event
    logger.info(f"Processing data for user: {username}")
    logger.debug(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract input with validation
        user_id = event.get('userId', 'unknown')
        data_type = event.get('dataType', 'general')
        
        if not user_id or not data_type:
            raise ValueError("Missing required fields: userId or dataType")
        
        logger.info(f"Processing {data_type} for user {user_id}")
        
        # Simulate processing time based on data type
        processing_times = {
            'sales_data': (1, 2),
            'customer_data': (0.5, 1.5),
            'inventory_data': (2, 3),
            'analytics_data': (1.5, 2.5),
            'general': (1, 2)
        }
        
        min_time, max_time = processing_times.get(data_type, (1, 2))
        processing_duration = random.uniform(min_time, max_time)
        
        logger.info(f"Simulating processing for {processing_duration:.2f} seconds")
        time.sleep(processing_duration)
        
        # Simulate processing result with different success rates by data type
        success_rates = {
            'sales_data': 0.9,
            'customer_data': 0.85,
            'inventory_data': 0.8,
            'analytics_data': 0.75,
            'general': 0.8
        }
        
        success_rate = success_rates.get(data_type, 0.8)
        success = random.random() < success_rate
        
        if success:
            records_processed = random.randint(100, 1000)
            processing_score = random.uniform(0.7, 0.99)
            
            result = {
                'userId': user_id,
                'dataType': data_type,
                'status': 'SUCCESS',
                'processedAt': int(time.time()),
                'recordsProcessed': records_processed,
                'processingDuration': round(processing_duration, 2),
                'processingScore': round(processing_score, 3),
                'nextStep': 'send_notification',
                'metadata': {
                    'username': username,
                    'functionName': context.function_name,
                    'requestId': context.aws_request_id
                }
            }
            
            logger.info(f"Data processing successful: {records_processed} records processed with score {processing_score:.3f}")
            
        else:
            error_types = ['data_corruption', 'timeout', 'validation_error', 'resource_unavailable']
            error_type = random.choice(error_types)
            
            result = {
                'userId': user_id,
                'dataType': data_type,
                'status': 'FAILED',
                'error': f'Processing error: {error_type}',
                'errorType': error_type,
                'processedAt': int(time.time()),
                'processingDuration': round(processing_duration, 2),
                'metadata': {
                    'username': username,
                    'functionName': context.function_name,
                    'requestId': context.aws_request_id
                }
            }
            
            logger.error(f"Data processing failed: {error_type}")
            raise Exception(f"Data processing failed: {error_type}")
        
        # Log execution metrics
        total_duration = time.time() - start_time
        logger.info(f"Function execution completed in {total_duration:.2f} seconds")
        
        return result
        
    except Exception as e:
        total_duration = time.time() - start_time
        error_result = {
            'userId': event.get('userId', 'unknown'),
            'dataType': event.get('dataType', 'unknown'),
            'status': 'FAILED',
            'error': str(e),
            'errorType': 'exception',
            'processedAt': int(time.time()),
            'totalDuration': round(total_duration, 2),
            'metadata': {
                'username': username,
                'functionName': context.function_name,
                'requestId': context.aws_request_id
            }
        }
        
        logger.error(f"Exception in data processing: {str(e)}")
        raise Exception(str(e))
