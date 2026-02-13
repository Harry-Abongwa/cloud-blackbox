############################
# Investigation API (Read-only)
############################

resource "aws_iam_role" "investigation_api_role" {
  name = "cloud-blackbox-investigation-api-role-dev"

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

resource "aws_iam_role_policy_attachment" "investigation_api_basic_logs" {
  role       = aws_iam_role.investigation_api_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "investigation_api_dynamodb_read" {
  name = "cloud-blackbox-investigation-api-dynamodb-read-dev"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_dynamodb_table.incidents.arn,
          "${aws_dynamodb_table.incidents.arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "investigation_api_dynamodb_read_attach" {
  role       = aws_iam_role.investigation_api_role.name
  policy_arn = aws_iam_policy.investigation_api_dynamodb_read.arn
}

resource "aws_lambda_function" "investigation_api" {
  function_name = "cloud-blackbox-investigation-api-dev"
  role          = aws_iam_role.investigation_api_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"

  filename         = "../../../services/investigation-api/function.zip"
  source_code_hash = filebase64sha256("../../../services/investigation-api/function.zip")

  environment {
    variables = {
      INCIDENT_TABLE = aws_dynamodb_table.incidents.name
      SEVERITY_INDEX = "severity-index"
    }
  }

  tags = {
    Project     = "CloudBlackBox"
    Environment = "dev"
  }
}

############################
# API Gateway (HTTP API)
############################

resource "aws_apigatewayv2_api" "investigation_http_api" {
  name          = "cloud-blackbox-investigation-http-dev"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }

  tags = {
    Project     = "CloudBlackBox"
    Environment = "dev"
  }
}

resource "aws_apigatewayv2_integration" "investigation_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.investigation_http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.investigation_api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "health_route" {
  api_id    = aws_apigatewayv2_api.investigation_http_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.investigation_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "incidents_route" {
  api_id    = aws_apigatewayv2_api.investigation_http_api.id
  route_key = "GET /incidents"
  target    = "integrations/${aws_apigatewayv2_integration.investigation_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "incident_detail_route" {
  api_id    = aws_apigatewayv2_api.investigation_http_api.id
  route_key = "GET /incidents/{incidentId}"
  target    = "integrations/${aws_apigatewayv2_integration.investigation_lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.investigation_http_api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Project     = "CloudBlackBox"
    Environment = "dev"
  }
}

resource "aws_lambda_permission" "allow_apigw_invoke_investigation" {
  statement_id  = "AllowAPIGatewayInvokeInvestigation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.investigation_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.investigation_http_api.execution_arn}/*/*"
}

output "investigation_api_url" {
  value = aws_apigatewayv2_api.investigation_http_api.api_endpoint
}
