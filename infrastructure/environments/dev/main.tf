############################
# DynamoDB - Incident Store
############################

resource "aws_dynamodb_table" "incidents" {
  name         = "cloud-blackbox-incidents-dev"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "incidentId"
  range_key = "eventTime"

  attribute {
    name = "incidentId"
    type = "S"
  }

  attribute {
    name = "eventTime"
    type = "S"
  }


  attribute {
    name = "severity"
    type = "S"
  }
  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }


  global_secondary_index {
    name            = "severity-index"
    hash_key        = "severity"
    range_key       = "eventTime"
    projection_type = "ALL"
  }
  tags = {
    Project     = "CloudBlackBox"
    Environment = "dev"
  }
}

############################
# Lambda Execution Role
############################

resource "aws_iam_role" "lambda_role" {
  name = "cloud-blackbox-lambda-role-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = "CloudBlackBox"
    Environment = "dev"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "cloud-blackbox-lambda-dynamodb-dev"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.incidents.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

############################
# Lambda Function
############################

resource "aws_lambda_function" "event_processor" {
  function_name = "cloud-blackbox-event-processor-dev"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"

  filename         = "../../../services/event-processor/function.zip"
  source_code_hash = filebase64sha256("../../../services/event-processor/function.zip")

  environment {
    variables = {
      INCIDENT_TABLE = aws_dynamodb_table.incidents.name
    }
  }

  tags = {
    Project     = "CloudBlackBox"
    Environment = "dev"
  }
}

############################
# EventBridge Rule
############################

resource "aws_cloudwatch_event_rule" "iam_activity_rule" {
  name        = "cloud-blackbox-iam-activity-dev"
  description = "Capture IAM management API calls"

  event_pattern = jsonencode({
    source        = ["aws.iam"],
    "detail-type" = ["AWS API Call via CloudTrail"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.iam_activity_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.event_processor.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.iam_activity_rule.arn
}

############################
# Outputs
############################

output "incident_table_name" {
  value = aws_dynamodb_table.incidents.name
}

output "lambda_function_name" {
  value = aws_lambda_function.event_processor.function_name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.iam_activity_rule.name
}
