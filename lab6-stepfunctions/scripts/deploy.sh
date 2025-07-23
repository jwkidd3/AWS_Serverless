#!/bin/bash

# Lab 6 - Step Functions Deployment Script
# This script automates the deployment process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "🚀 Lab 6 - Step Functions Deployment"
echo "===================================="

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform."
    exit 1
fi

# Check AWS credentials
echo "🔐 Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run 'aws configure'."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Check for terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found. Please ensure the file exists and is configured."
    echo "📁 Expected location: $TERRAFORM_DIR/terraform.tfvars"
    echo "🔧 The file should contain your assigned username:"
    echo "   username = \"user1\"  # Replace with your assigned username"
    exit 1
fi

# Check if username is configured
USERNAME=$(grep "^username" terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
if [ "$USERNAME" = "user1" ] || [ -z "$USERNAME" ]; then
    echo "⚠️  WARNING: Username appears to be default value or missing!"
    echo "📝 Please edit terraform.tfvars with YOUR assigned username:"
    echo "   username = \"user2\"  # Use your actual assigned username"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "🛑 Deployment cancelled"
        exit 0
    fi
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Confirm deployment
echo ""
echo "🎯 Ready to deploy Lab 6 infrastructure!"
echo "This will create:"
echo "  • 3 Lambda functions"
echo "  • 1 Step Functions state machine"
echo "  • 1 API Gateway"
echo "  • IAM roles and policies"
echo "  • CloudWatch log groups"
echo ""
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Deployment cancelled"
    exit 0
fi

# Apply deployment
echo "🚀 Deploying infrastructure..."
terraform apply tfplan

# Get outputs
echo ""
echo "📊 Deployment completed! Here are your resources:"
echo "================================================"
terraform output

# Test deployment
echo ""
echo "🧪 Testing deployment..."
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
if [ -n "$API_URL" ]; then
    echo "Testing API Gateway endpoint..."
    RESPONSE=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d '{"userId": "deploy-test", "dataType": "test_data"}' \
        -w "%{http_code}")
    
    HTTP_CODE="${RESPONSE: -3}"
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ API Gateway test successful"
    else
        echo "⚠️  API Gateway test returned HTTP $HTTP_CODE"
    fi
else
    echo "⚠️  Could not retrieve API URL for testing"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. Test your workflow: ../scripts/test_workflow.sh"
echo "2. View Step Functions console: terraform output state_machine_console_url"
echo "3. Monitor with CloudWatch logs"
echo ""
echo "To clean up: terraform destroy"
