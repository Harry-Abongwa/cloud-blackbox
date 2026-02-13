#################################
# Investigation API Lambda
#################################

resource "aws_lambda_function" "investigation_api" {
  function_name = "cloud-blackbox-investigation-api-dev"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"

  filename         = "${path.module}/../../../services/investigation-api/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../services/investigation-api/function.zip")

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

#################################
# HTTP API
#################################

resource "aws_apigatewayv2_api" "investigation_http_api" {
  name          = "cloud-blackbox-investigation-api-dev"
  protocol_type = "HTTP"

  tags = {
    Project     = "CloudBlackBox"
    Environment = "dev"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.investigation_http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.investigation_api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_incidents_route" {
  api_id    = aws_apigatewayv2_api.investigation_http_api.id
  route_key = "GET /incidents"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
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

#################################
# Output
#################################

output "investigation_api_url" {
  value = aws_apigatewayv2_api.investigation_http_api.api_endpoint
}
