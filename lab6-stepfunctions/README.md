# Lab 6 - Workflow Orchestration Using AWS Step Functions

![AWS Step Functions](https://img.shields.io/badge/AWS-Step%20Functions-orange)
![Terraform](https://img.shields.io/badge/Terraform-1.0+-blue)
![Python](https://img.shields.io/badge/Python-3.9-blue)
![License](https://img.shields.io/badge/License-MIT-green)

**Lab Duration:** 60 minutes

---

## Lab Overview

In this lab, you will build a simplified serverless workflow using AWS Step Functions to orchestrate Lambda functions. You'll use Terraform to provision all infrastructure and create a Standard workflow with error handling to learn the fundamentals of state machine design.

## Lab Objectives

By the end of this lab, you will be able to:
- Use Terraform to provision Step Functions infrastructure
- Create and configure AWS Step Functions state machines
- Design workflows with sequential and conditional logic
- Implement basic error handling in workflows
- Integrate Step Functions with Lambda functions
- Monitor workflow executions
- Apply username prefixing to Step Functions resources

## Prerequisites

- Access to AWS Console with provided credentials
- Assigned username (user1, user2, user3, etc.)
- AWS CLI configured
- Terraform >= 1.0 installed
- Python 3.9+

---

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   API Gateway   │───▶│  Trigger Lambda  │───▶│   Step Functions    │
│  (POST /process)│    │  (HTTP → SF)     │    │   State Machine     │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                                           │
                               ┌───────────────────────────┼───────────────────────────┐
                               ▼                           ▼                           ▼
                    ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
                    │ Process Data    │         │ Send Notification│         │ Error Handling  │
                    │    Lambda       │         │     Lambda      │         │     States      │
                    │  (Business Logic)│         │ (Email/SMS/Push)│         │ (Retry/Catch)   │
                    └─────────────────┘         └─────────────────┘         └─────────────────┘
```

---

## Task 1: Configure Your Username

### Step 1.1: Critical Configuration

**⚠️ CRITICAL: You MUST configure your assigned username to avoid resource conflicts!**

1. **Edit the Terraform variables file**:
```bash
nano terraform/terraform.tfvars
```

2. **Update the username with YOUR assigned username**:
```hcl
# REQUIRED: Replace with your assigned username (user1, user2, user3, etc.)
username = "user1"  # ⚠️ CHANGE THIS to your assigned username

# Optional: You can modify these if needed
aws_region = "us-east-1"
log_level = "INFO"
log_retention_days = 7
```

**Example:** If you are assigned "user5":
```hcl
username = "user5"
```

**This creates resources like:**
- `user5-process-data` (Lambda function)
- `user5-simple-workflow` (Step Functions)
- `user5-workflow-api` (API Gateway)

### Step 1.2: Verify Prerequisites

1. **Check AWS credentials**:
```bash
aws sts get-caller-identity
```

2. **Verify Terraform**:
```bash
terraform --version
```

---

## Task 2: Deploy Infrastructure

### Step 2.1: Initialize Terraform

1. **Navigate to terraform directory and initialize**:
```bash
cd terraform
terraform init
```

2. **Review planned changes**:
```bash
terraform plan
```

This creates:
- 3 Lambda functions
- 1 Step Functions state machine  
- 1 API Gateway
- IAM roles and policies
- CloudWatch log groups

### Step 2.2: Deploy Resources

1. **Apply the configuration**:
```bash
terraform apply
```

Type `yes` when prompted.

2. **Save the outputs** (needed for testing):
```bash
terraform output
```

Expected outputs:
- `api_gateway_url` - API endpoint for triggering workflows
- `state_machine_console_url` - Direct AWS console link
- `lambda_functions` - Function names and ARNs

---

## Task 3: Test Your Workflow

### Step 3.1: Console Testing

1. **Open Step Functions console**:
```bash
terraform output state_machine_console_url
```

2. **Start a new execution**:
   - Click "Start execution"
   - Name: `console-test-1` 
   - Input:
   ```json
   {
     "userId": "user-123",
     "dataType": "sales_data"
   }
   ```

3. **Watch the execution** in the Graph view

### Step 3.2: API Gateway Testing

1. **Get your API URL**:
```bash
API_URL=$(terraform output -raw api_gateway_url)
echo "Your API: $API_URL"
```

2. **Test successful processing**:
```bash
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"userId": "api-user-123", "dataType": "customer_data"}'
```

3. **Test different data types**:
```bash
# Test sales data
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"userId": "test-user", "dataType": "sales_data"}'

# Test inventory data  
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"userId": "test-user", "dataType": "inventory_data"}'
```

### Step 3.3: Error Testing

**Test error handling**:
```bash
curl -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"userId": "", "dataType": ""}'
```

Watch how the workflow handles errors in the console.

---

## Task 4: Monitoring and Analysis

### Step 4.1: CloudWatch Monitoring

1. **Navigate to CloudWatch → Metrics**
2. **Go to AWS/States**  
3. **Select your state machine**
4. **View metrics**:
   - ExecutionsStarted
   - ExecutionsSucceeded
   - ExecutionsFailed

### Step 4.2: Review Logs

1. **Check Lambda logs** in CloudWatch:
   - `/aws/lambda/[username]-process-data`
   - `/aws/lambda/[username]-send-notification`
   - `/aws/lambda/[username]-trigger-workflow`

2. **Review execution details** in Step Functions console

### Step 4.3: Automated Testing

1. **Return to lab root**:
```bash
cd ..
```

2. **Run comprehensive tests**:
```bash
./scripts/test_workflow.sh
```

---

## Task 5: Understanding the Workflow

### Step 5.1: State Machine Design

The workflow implements these states:

1. **ProcessData** - Main business logic with retry mechanisms
2. **CheckStatus** - Conditional routing based on processing results
3. **SendNotification** - Success path for notifications
4. **WorkflowCompleted** - Final success state
5. **ProcessingFailed** - Error handling state

### Step 5.2: Error Handling Patterns

- **Retry Logic**: Automatic retries with exponential backoff
- **Catch Blocks**: Graceful error capture and routing  
- **Conditional Paths**: Different flows based on results
- **Error States**: Dedicated failure handling

### Step 5.3: Lambda Function Roles

- **process-data**: Simulates data processing with variable success rates
- **send-notification**: Handles different notification types (EMAIL/SMS/PUSH)
- **trigger-workflow**: API Gateway integration with input validation

---

## Task 6: Advanced Testing

### Step 6.1: Multiple Executions

**Generate test load**:
```bash
# Run 5 test executions
for i in {1..5}; do
  curl -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "{\"userId\": \"load-test-$i\", \"dataType\": \"analytics_data\"}"
  sleep 2
done
```

### Step 6.2: Validation

**Verify your deployment**:
```bash
./scripts/validate.sh
```

This checks:
- All AWS resources exist
- Functions are accessible
- API Gateway responds correctly
- Logs are being created

---

## Lab Verification

### Verification Checklist

Confirm you have completed:

- [ ] Configured username in terraform.tfvars
- [ ] Successfully deployed infrastructure via Terraform
- [ ] Tested workflows via Step Functions console
- [ ] Tested API Gateway endpoints
- [ ] Viewed execution results and logs
- [ ] Generated multiple test executions
- [ ] Monitored CloudWatch metrics

### Expected Results

Your workflow should:
- Execute successfully with valid inputs
- Handle errors gracefully with retry logic
- Show detailed execution history
- Provide monitoring metrics
- Accept API requests to trigger executions

---

## Troubleshooting

### Common Issues

**Terraform fails**: Check AWS credentials and unique username
**API returns 500**: Check Lambda logs in CloudWatch  
**No executions**: Verify API URL and Step Functions permissions
**Permission errors**: Ensure IAM roles are properly configured

**For detailed troubleshooting**, see: `docs/TROUBLESHOOTING.md`

---

## Clean Up

**Destroy all resources**:
```bash
cd terraform
terraform destroy
```

Or use the cleanup script:
```bash
./scripts/cleanup.sh
```

---

## Key Takeaways

You learned:
- **Infrastructure as Code** with Terraform for serverless
- **Step Functions orchestration** of Lambda functions  
- **State machine design** with error handling
- **API Gateway integration** for workflow triggering
- **CloudWatch monitoring** for observability
- **Resource isolation** with username prefixing

---

## Repository Structure

```
lab6-stepfunctions/
├── README.md                    # This lab guide
├── terraform/                   # Infrastructure code
│   ├── main.tf                  # Main configuration
│   ├── variables.tf             # Variables
│   ├── outputs.tf               # Outputs
│   └── terraform.tfvars         # Your configuration
├── lambda_functions/            # Function source code
├── scripts/                     # Automation scripts  
├── docs/                        # Additional docs
└── examples/                    # Sample payloads
```

---

**Course**: Developing Serverless Solutions on AWS | **Lab**: 6 | **Duration**: ~60 minutes
