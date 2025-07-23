# Troubleshooting Guide

This guide helps resolve common issues encountered during deployment and operation of the Step Functions workflow.

## Deployment Issues

### Terraform Apply Failures

#### Issue: Insufficient IAM Permissions
```
Error: error creating Lambda function: AccessDenied
```

**Cause**: AWS credentials lack required permissions
**Solution**:
1. Verify AWS credentials:
```bash
aws sts get-caller-identity
```

2. Required IAM permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "states:*",
        "apigateway:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "logs:CreateLogGroup",
        "logs:PutRetentionPolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Issue: Resource Name Conflicts
```
Error: resource already exists
```

**Cause**: Username prefix not unique
**Solution**:
1. Use unique username in `terraform.tfvars`:
```hcl
username = "user1"  # Ensure this is unique
```

2. Check existing resources:
```bash
aws lambda list-functions --query 'Functions[?contains(FunctionName, `user1`)]'
```

## Runtime Issues

### Lambda Function Errors

#### Issue: Module Import Errors
```
Runtime.ImportModuleError: Unable to import module 'process_data'
```

**Cause**: Incorrect handler path or missing Python file
**Solution**:
1. Verify handler configuration in Terraform:
```hcl
handler = "process_data.lambda_handler"  # file.function
```

2. Check Python file exists:
```bash
ls lambda_functions/process_data/process_data.py
```

### Step Functions Execution Errors

#### Issue: Lambda Invocation Failed
```
States.TaskFailed: Lambda function failed
```

**Cause**: Lambda function error or timeout
**Solution**:
1. Check Lambda logs:
```bash
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/[username]-process-data" \
  --order-by LastEventTime --descending
```

2. Review CloudWatch logs for specific error details

## Testing Issues

### API Gateway Testing Problems

#### Issue: 403 Forbidden Error
```
{"message": "Forbidden"}
```

**Cause**: API Gateway method not configured correctly
**Solution**:
1. Check API Gateway deployment:
```bash
aws apigateway get-deployments --rest-api-id [api-id]
```

2. Verify method exists:
```bash
aws apigateway get-method \
  --rest-api-id [api-id] \
  --resource-id [resource-id] \
  --http-method POST
```

#### Issue: 500 Internal Server Error
```
{"message": "Internal server error"}
```

**Cause**: Lambda function error or integration issue
**Solution**:
1. Check API Gateway logs:
```bash
aws logs get-log-events \
  --log-group-name "API-Gateway-Execution-Logs_[api-id]/prod"
```

2. Verify Lambda permission for API Gateway:
```bash
aws lambda get-policy --function-name [username]-trigger-workflow
```

## Common Error Messages

### Terraform Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Resource already exists` | Name conflict | Use unique username prefix |
| `Invalid function name` | Invalid characters | Use alphanumeric and hyphens only |
| `Access denied` | IAM permissions | Verify AWS credentials and permissions |
| `No such file or directory` | Missing source code | Check lambda_functions directory structure |

### Lambda Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Runtime.ImportModuleError` | Missing Python file | Verify file exists and handler is correct |
| `KeyError: 'ENV_VAR'` | Missing environment variable | Check Terraform environment configuration |
| `Task timed out` | Function timeout | Increase timeout value |
| `Memory limit exceeded` | Insufficient memory | Increase memory allocation |

### Step Functions Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `States.TaskFailed` | Lambda function error | Check Lambda logs |
| `States.ExecutionLimitExceeded` | Too many concurrent executions | Implement backoff or increase limits |
| `InvalidDefinition` | State machine JSON error | Validate JSON syntax |
| `AccessDenied` | IAM permissions | Check Step Functions execution role |

### API Gateway Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `403 Forbidden` | Method not configured | Verify API deployment |
| `500 Internal Server Error` | Backend error | Check Lambda function logs |
| `502 Bad Gateway` | Integration error | Verify Lambda integration configuration |
| `504 Gateway Timeout` | Backend timeout | Increase integration timeout |

## Getting Help

### AWS Support Resources
- [AWS Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/)
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Best Practices
1. **Always check CloudWatch logs first** - Most issues are logged
2. **Use unique resource names** - Prevents conflicts in shared environments
3. **Validate JSON syntax** - Use linters for complex configurations
4. **Test incrementally** - Deploy and test each component separately
5. **Monitor resource limits** - Check AWS service quotas and limits
