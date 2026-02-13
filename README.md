# Cloud Blackbox

Cloud Blackbox is a lightweight cloud security investigation platform built entirely on AWS.

It ingests CloudTrail management events, classifies sensitive IAM activity, stores structured incidents in DynamoDB, and exposes a filtered investigation API consumed by a static web dashboard hosted on Amazon S3.

This project demonstrates real-world cloud security engineering practices including event-driven architecture, API design, pagination, filtering, least-privilege IAM, infrastructure-as-code, and production hardening.

---

## Architecture Overview

Frontend Layer
- Static HTML/CSS/JS dashboard
- Hosted on Amazon S3 (website mode)
- Fetches data from API Gateway
- Displays severity badges, user counts, IP aggregation, and raw event copy

API Layer
- Amazon API Gateway (HTTP API v2)
- AWS Lambda (Python 3.11)
- Supports filtering, pagination, time windowing
- CORS enabled
- Structured error handling

Processing Layer
- EventBridge rule captures IAM management events
- Processor Lambda classifies events
- High-severity events stored in DynamoDB

Data Layer
- DynamoDB table: cloud-blackbox-incidents-dev
- Global Secondary Index: severity-index
- On-demand billing mode
- Server-side encryption enabled

Observability
- CloudWatch Logs enabled
- API Gateway metrics enabled
- Lambda X-Ray tracing enabled

---

## Core Features

- Severity-based filtering
- Time-range filtering
- Pagination using nextToken
- Optional raw event retrieval
- Unique user aggregation
- Unique IP aggregation
- Copy raw event functionality
- CORS-enabled API
- Clean JSON responses
- Production-safe error handling

---

## API Usage

Base URL

https://<api-id>.execute-api.us-east-1.amazonaws.com

Retrieve incidents by severity

GET /incidents?severity=High

Filter by time

GET /incidents?severity=High&from=2026-02-13T08:30:00Z

Enable pagination

GET /incidents?severity=High&limit=5

Use nextToken for next page

GET /incidents?severity=High&limit=5&nextToken=<encoded_token>

Include raw CloudTrail event

GET /incidents?severity=High&includeRaw=true

---

## Example Response

{
  "mode": "severity-index",
  "severity": "High",
  "count": 2,
  "items": [
    {
      "incidentId": "72659421a2115f85e03f",
      "eventName": "CreatePolicyVersion",
      "userIdentity": "arn:aws:iam::094156049339:user/harry-local-cli",
      "sourceIPAddress": "107.194.141.176",
      "eventTime": "2026-02-13T08:52:10Z",
      "severity": "High",
      "isSensitive": true
    }
  ],
  "nextToken": "base64-token"
}

---

## Project Structure

cloud-blackbox/
│
├── infrastructure/
│   └── environments/
│       └── dev/
│           ├── main.tf
│           ├── api.tf
│           ├── cloudtrail.tf
│           ├── variables.tf
│           └── providers.tf
│
├── services/
│   ├── investigation-api/
│   │   ├── handler.py
│   │   └── function.zip
│   │
│   └── ui/
│       └── index.html
│
└── README.md

Infrastructure is provisioned using Terraform.

---

## Security Controls

- Least-privilege IAM role for Lambda
- DynamoDB index permissions restricted
- Server-side encryption enabled
- S3 bucket versioning enabled
- API Gateway metrics enabled
- Lambda tracing enabled
- Structured exception handling
- No credentials stored in code
- CORS explicitly controlled

---

## Production Hardening Completed

- API pagination implemented
- Time filtering implemented
- Raw event toggle implemented
- Error handling standardized
- DynamoDB GSI access properly scoped
- Bucket encryption enabled
- Bucket versioning enabled
- Lambda tracing enabled
- Git version control finalized

---

## Cost Profile (Development)

This architecture is designed to remain low-cost:

- DynamoDB (On-Demand)
- 2 Lambda functions
- 1 HTTP API
- 1 S3 static website bucket
- CloudWatch logs

In light dev usage, this remains within free tier or minimal monthly cost.

---

## Version

Cloud Blackbox v1.0  
Production Hardened Security Incident Dashboard

---

## Author

Harry Bush  
Cloud Security Engineer  
