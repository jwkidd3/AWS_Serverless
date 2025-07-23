#!/bin/bash

# Lab 6 - Step Functions Cleanup Script
# This script safely removes all deployed infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "🧹 Lab 6 - Infrastructure Cleanup"
echo "================================="

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Check if infrastructure exists
if ! terraform state list &> /dev/null; then
    echo "ℹ️  No Terraform state found. Nothing to clean up."
    exit 0
fi

# Show what will be destroyed
echo "📋 The following resources will be destroyed:"
echo ""
terraform state list
echo ""

# Get resource info before destruction
if terraform output &> /dev/null; then
    echo "📊 Current deployment info:"
    terraform output deployment_info 2>/dev/null || echo "Deployment info not available"
    echo ""
fi

# Confirm destruction
echo "⚠️  WARNING: This will permanently delete all infrastructure!"
echo "This includes:"
echo "  • All Lambda functions and their logs"
echo "  • Step Functions state machine and execution history"
echo "  • API Gateway and all configurations"
echo "  • IAM roles and policies"
echo "  • CloudWatch log groups and all log data"
echo ""
read -p "Are you sure you want to proceed? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "🛑 Cleanup cancelled"
    exit 0
fi

# Destroy infrastructure
echo ""
echo "🗑️  Destroying infrastructure..."
terraform destroy -auto-approve

# Verify cleanup
echo ""
echo "🔍 Verifying cleanup..."

# Check for any remaining resources (optional verification)
REMAINING_RESOURCES=$(terraform state list 2>/dev/null | wc -l)
if [ "$REMAINING_RESOURCES" -eq 0 ]; then
    echo "✅ All Terraform resources destroyed"
else
    echo "⚠️  $REMAINING_RESOURCES resources still in state"
fi

# Clean up local files
echo ""
echo "🧹 Cleaning up local files..."

# Remove Terraform state and plan files
if [ -f "terraform.tfstate" ]; then
    rm -f terraform.tfstate*
    echo "✅ Removed local state files"
fi

if [ -f "tfplan" ]; then
    rm -f tfplan
    echo "✅ Removed plan file"
fi

# Remove Lambda deployment packages
if [ -f "process_data.zip" ]; then
    rm -f *.zip
    echo "✅ Removed Lambda deployment packages"
fi

echo ""
echo "🎉 Cleanup completed successfully!"
echo ""
echo "All Lab 6 infrastructure has been removed."
echo "You can redeploy anytime using: ./scripts/deploy.sh"
