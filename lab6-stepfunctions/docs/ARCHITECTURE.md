# Architecture Guide

## Overview

This lab demonstrates a serverless workflow orchestration pattern using AWS Step Functions, Lambda, and API Gateway. The architecture follows AWS Well-Architected principles for serverless applications.

## Architecture Diagram

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
                               │                           │                           │
                               ▼                           ▼                           ▼
                    ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
                    │   CloudWatch    │         │   CloudWatch    │         │   CloudWatch    │
                    │     Logs        │         │     Logs        │         │     Logs        │
                    └─────────────────┘         └─────────────────┘         └─────────────────┘
```

## Components

### 1. API Gateway
- **Purpose**: HTTP endpoint to trigger workflows
- **Path**: `POST /process`
- **Integration**: Lambda Proxy integration with trigger function
- **Features**: CORS enabled, request/response logging

### 2. Trigger Lambda Function
- **Purpose**: Validates input and starts Step Functions execution
- **Runtime**: Python 3.9
- **Key Features**:
  - Input validation and sanitization
  - Error handling and proper HTTP responses
  - Step Functions execution management
  - Correlation ID generation

### 3. Step Functions State Machine
- **Type**: Standard workflow
- **Features**:
  - Error handling with retry mechanisms
  - Conditional logic based on processing results
  - Comprehensive logging
  - State transition monitoring

#### State Flow:
1. **ProcessData**: Main business logic execution
2. **CheckStatus**: Conditional routing based on success/failure
3. **SendNotification**: Success path notification
4. **WorkflowCompleted**: Final success state
5. **ProcessingFailed**: Error handling state
6. **NotificationFailed**: Notification error handling

### 4. Process Data Lambda Function
- **Purpose**: Simulates data processing business logic
- **Features**:
  - Variable processing times based on data type
  - Configurable success rates
  - Comprehensive result metadata
  - Error simulation for testing

### 5. Send Notification Lambda Function
- **Purpose**: Handles notification delivery
- **Notification Types**: EMAIL, SMS, PUSH
- **Features**:
  - Dynamic notification type selection
  - Priority-based routing
  - Delivery confirmation
  - Failure simulation

## Security

### 1. IAM Roles and Policies
- **Principle of Least Privilege**: Minimal required permissions
- **Resource-Specific Permissions**: Function-specific access controls
- **Cross-Service Integration**: Secure service-to-service communication

### 2. Logging and Monitoring
- **CloudWatch Logs**: Comprehensive logging for all components
- **Structured Logging**: JSON-formatted logs for analysis
- **Correlation IDs**: Request tracking across services

## Scalability Considerations

### 1. Lambda Scaling
- **Concurrent Executions**: Automatic scaling based on demand
- **Memory Configuration**: Optimized for function requirements
- **Timeout Settings**: Appropriate timeout values

### 2. Step Functions Scaling
- **Execution Limits**: Account and region limits
- **State Machine Versions**: Version management for updates
- **Parallel Executions**: Support for concurrent workflows

### 3. API Gateway Scaling
- **Throttling**: Request rate limiting
- **Regional Distribution**: Multi-region deployment capability
