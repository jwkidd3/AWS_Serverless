import json
import time
import os
import logging
import random

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig(level=getattr(logging, log_level))
logger = logging.getLogger(__name__)

def lambda_handler(event, context):
    """
    Simple notification function with various notification types and comprehensive logging
    """
    
    start_time = time.time()
    username = os.environ.get('USERNAME', 'unknown')
    
    logger.info(f"Sending notification for user: {username}")
    logger.debug(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract data with defaults
        user_id = event.get('userId', 'unknown')
        status = event.get('status', 'UNKNOWN')
        records_processed = event.get('recordsProcessed', 0)
        data_type = event.get('dataType', 'general')
        processing_score = event.get('processingScore', 0.0)
        
        logger.info(f"Preparing notification for user {user_id}, status: {status}")
        
        # Determine notification type based on status and data
        if status == 'SUCCESS':
            if processing_score > 0.9:
                notification_type = 'SMS'  # High priority for excellent processing
            elif records_processed > 500:
                notification_type = 'EMAIL'  # Standard for large datasets
            else:
                notification_type = 'PUSH'  # Quick notification for smaller jobs
        else:
            notification_type = 'EMAIL'  # Always email for failures
        
        # Simulate notification sending time based on type
        notification_times = {
            'EMAIL': (0.5, 1.5),
            'SMS': (0.2, 0.8),
            'PUSH': (0.1, 0.5)
        }
        
        min_time, max_time = notification_times.get(notification_type, (0.5, 1.0))
        send_duration = random.uniform(min_time, max_time)
        
        logger.info(f"Sending {notification_type} notification (estimated {send_duration:.2f}s)")
        time.sleep(send_duration)
        
        # Create notification content based on status
        if status == 'SUCCESS':
            message = f'✅ Data processing completed successfully! {records_processed} {data_type} records processed with {processing_score:.1%} accuracy.'
            priority = 'normal' if processing_score < 0.9 else 'high'
        else:
            message = f'❌ Data processing failed for {data_type}. Please check logs for details.'
            priority = 'high'
        
        # Simulate occasional notification failures (5% chance)
        notification_success = random.random() > 0.05
        
        if not notification_success:
            logger.error(f"Failed to send {notification_type} notification to {user_id}")
            raise Exception(f"Notification service unavailable for {notification_type}")
        
        notification_result = {
            'userId': user_id,
            'notificationType': notification_type,
            'status': 'SENT',
            'priority': priority,
            'message': message,
            'sentAt': int(time.time()),
            'sendDuration': round(send_duration, 2),
            'deliveryId': f"{notification_type.lower()}_{int(time.time())}_{random.randint(1000, 9999)}",
            'originalData': {
                'dataType': data_type,
                'recordsProcessed': records_processed,
                'processingScore': processing_score
            },
            'metadata': {
                'username': username,
                'functionName': context.function_name,
                'requestId': context.aws_request_id
            }
        }
        
        total_duration = time.time() - start_time
        logger.info(f"{notification_type} notification sent successfully to {user_id} in {total_duration:.2f}s")
        logger.debug(f"Notification result: {json.dumps(notification_result)}")
        
        return notification_result
        
    except Exception as e:
        total_duration = time.time() - start_time
        error_result = {
            'userId': event.get('userId', 'unknown'),
            'notificationType': 'ERROR',
            'status': 'FAILED',
            'error': str(e),
            'sentAt': int(time.time()),
            'totalDuration': round(total_duration, 2),
            'metadata': {
                'username': username,
                'functionName': context.function_name,
                'requestId': context.aws_request_id
            }
        }
        
        logger.error(f"Exception in notification sending: {str(e)}")
        raise Exception(str(e))
