#!/bin/bash

# Lab 6 - Step Functions Test Script
# This script runs comprehensive tests on the deployed workflow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "🧪 Lab 6 - Step Functions Testing"
echo "================================="

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Check if infrastructure is deployed
if ! terraform state list &> /dev/null; then
    echo "❌ No Terraform state found. Please deploy infrastructure first:"
    echo "   ./scripts/deploy.sh"
    exit 1
fi

# Get API URL
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
if [ -z "$API_URL" ]; then
    echo "❌ Could not retrieve API Gateway URL. Check deployment."
    exit 1
fi

echo "🎯 Testing API endpoint: $API_URL"
echo ""

# Test data sets
declare -a TEST_CASES=(
    '{"userId": "user-001", "dataType": "sales_data", "priority": "high"}'
    '{"userId": "user-002", "dataType": "customer_data", "priority": "normal"}'
    '{"userId": "user-003", "dataType": "inventory_data"}'
    '{"userId": "user-004", "dataType": "analytics_data", "options": {"validateOnly": false}}'
    '{"userId": "user-005", "dataType": "general"}'
)

SUCCESS_COUNT=0
TOTAL_TESTS=${#TEST_CASES[@]}

echo "🚀 Running $TOTAL_TESTS test cases..."
echo ""

for i in "${!TEST_CASES[@]}"; do
    TEST_NUM=$((i + 1))
    TEST_DATA="${TEST_CASES[$i]}"
    
    echo "Test $TEST_NUM/$TOTAL_TESTS: $(echo "$TEST_DATA" | jq -r '.userId + " - " + .dataType')"
    
    # Execute test
    RESPONSE=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "$TEST_DATA" \
        -w "\n%{http_code}")
    
    # Parse response
    BODY=$(echo "$RESPONSE" | head -n -1)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo "  ✅ HTTP 200 - Workflow started"
        
        # Extract execution details
        EXECUTION_NAME=$(echo "$BODY" | jq -r '.executionName // "unknown"')
        EXECUTION_ARN=$(echo "$BODY" | jq -r '.executionArn // "unknown"')
        
        echo "     Execution: $EXECUTION_NAME"
        ((SUCCESS_COUNT++))
    else
        echo "  ❌ HTTP $HTTP_CODE - Test failed"
        echo "     Response: $BODY"
    fi
    
    echo ""
    sleep 2  # Rate limiting
done

# Summary
echo "📊 Test Summary"
echo "=============="
echo "Total tests: $TOTAL_TESTS"
echo "Successful: $SUCCESS_COUNT"
echo "Failed: $((TOTAL_TESTS - SUCCESS_COUNT))"

if [ $SUCCESS_COUNT -eq $TOTAL_TESTS ]; then
    echo "🎉 All tests passed!"
else
    echo "⚠️  Some tests failed. Check CloudWatch logs for details."
fi

# Additional testing options
echo ""
echo "🔍 Additional Testing Options:"
echo ""
echo "1. Manual Step Functions Console Testing:"
terraform output state_machine_console_url
echo ""
echo "2. CloudWatch Logs:"
echo "   - Lambda logs: /aws/lambda/[username]-*"
echo "   - Step Functions logs: /aws/stepfunctions/[username]-simple-workflow"
echo ""
echo "3. Monitor executions:"
echo "   aws stepfunctions list-executions --state-machine-arn \$(terraform output -raw state_machine_arn)"
echo ""
echo "4. Error testing (trigger failures):"
echo '   curl -X POST "'"$API_URL"'" -H "Content-Type: application/json" -d '"'"'{"userId": "", "dataType": ""}'"'"
