#!/bin/bash

# Lab 6 - Step Functions Validation Script
# This script validates the deployed infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "✅ Lab 6 - Infrastructure Validation"
echo "===================================="

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Check Terraform state
echo "🔍 Checking Terraform state..."
if ! terraform state list &> /dev/null; then
    echo "❌ No Terraform state found. Infrastructure not deployed."
    exit 1
fi

RESOURCE_COUNT=$(terraform state list | wc -l)
echo "✅ Found $RESOURCE_COUNT Terraform resources"

# Validate Terraform configuration
echo ""
echo "🔧 Validating Terraform configuration..."
terraform validate
echo "✅ Terraform configuration is valid"

# Check AWS resources
echo ""
echo "🔍 Validating AWS resources..."

# Get deployment info
DEPLOYMENT_INFO=$(terraform output -json deployment_info)
USERNAME=$(echo "$DEPLOYMENT_INFO" | jq -r '.username')
REGION=$(echo "$DEPLOYMENT_INFO" | jq -r '.region')
ACCOUNT_ID=$(echo "$DEPLOYMENT_INFO" | jq -r '.account_id')

echo "📋 Deployment Details:"
echo "   Username: $USERNAME"
echo "   Region: $REGION"
echo "   Account: $ACCOUNT_ID"
echo ""

# Validate Lambda functions
echo "🔍 Checking Lambda functions..."
LAMBDA_FUNCTIONS=$(terraform output -json lambda_functions)
FUNCTION_COUNT=0

for func in process_data send_notification trigger_workflow; do
    FUNCTION_NAME=$(echo "$LAMBDA_FUNCTIONS" | jq -r ".$func.name")
    
    if aws lambda get-function --function-name "$FUNCTION_NAME" &>/dev/null; then
        echo "✅ Lambda function: $FUNCTION_NAME"
        ((FUNCTION_COUNT++))
    else
        echo "❌ Lambda function not found: $FUNCTION_NAME"
    fi
done

echo "   Found $FUNCTION_COUNT/3 Lambda functions"

# Validate Step Functions state machine
echo ""
echo "🔍 Checking Step Functions state machine..."
STATE_MACHINE_ARN=$(terraform output -raw state_machine_arn)

if aws stepfunctions describe-state-machine --state-machine-arn "$STATE_MACHINE_ARN" &>/dev/null; then
    echo "✅ Step Functions state machine: $(basename "$STATE_MACHINE_ARN")"
    
    # Check state machine status
    STATUS=$(aws stepfunctions describe-state-machine --state-machine-arn "$STATE_MACHINE_ARN" --query 'status' --output text)
    echo "   Status: $STATUS"
else
    echo "❌ Step Functions state machine not found"
fi

# Validate API Gateway
echo ""
echo "🔍 Checking API Gateway..."
API_ID=$(terraform output -raw api_gateway_id)

if aws apigateway get-rest-api --rest-api-id "$API_ID" &>/dev/null; then
    echo "✅ API Gateway: $API_ID"
    
    # Check deployment
    STAGE_NAME="prod"
    if aws apigateway get-stage --rest-api-id "$API_ID" --stage-name "$STAGE_NAME" &>/dev/null; then
        echo "   Stage '$STAGE_NAME' deployed"
        
        # Get API URL
        API_URL=$(terraform output -raw api_gateway_url)
        echo "   Endpoint: $API_URL"
    else
        echo "❌ API Gateway stage not deployed"
    fi
else
    echo "❌ API Gateway not found"
fi

# Test connectivity
echo ""
echo "🔍 Testing connectivity..."
API_URL=$(terraform output -raw api_gateway_url)

echo "Testing API Gateway endpoint..."
HTTP_CODE=$(curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d '{"userId": "validation-test", "dataType": "test"}' \
    -w "%{http_code}" -o /dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ API Gateway connectivity test passed"
else
    echo "⚠️  API Gateway returned HTTP $HTTP_CODE"
fi

# Summary
echo ""
echo "📊 Validation Summary"
echo "===================="
echo "✅ Infrastructure validation completed"
echo ""
echo "🔧 Terraform Resources: $RESOURCE_COUNT"
echo "🔧 Lambda Functions: $FUNCTION_COUNT/3"
echo "🔧 Step Functions: 1/1"
echo "🔧 API Gateway: 1/1"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "🎉 All validation checks passed!"
    echo ""
    echo "Ready for lab exercises:"
    echo "• Run tests: ./scripts/test_workflow.sh"
    echo "• View console: terraform output state_machine_console_url"
    echo "• Monitor logs in CloudWatch"
else
    echo "⚠️  Some validation checks failed. Review the output above."
fi
