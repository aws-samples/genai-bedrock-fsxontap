resource "aws_api_gateway_rest_api" "bedrock_lambda" {
  name          = "bedrock_lambda_api"
  description = "Bedrock Lambda API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

}

resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_lambda.id
  parent_id = aws_api_gateway_rest_api.bedrock_lambda.root_resource_id
  path_part = "bedrock_rag_retreival"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_lambda.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_lambda.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.method.http_method
  integration_http_method = "ANY"

  type = "AWS"
  uri = aws_lambda_function.bedrock_rag_retreival.invoke_arn
}

resource "aws_api_gateway_method_response" "response" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_lambda.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "response" {
  rest_api_id = aws_api_gateway_rest_api.bedrock_lambda.id
  resource_id = aws_api_gateway_resource.root.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.response.status_code

  depends_on = [
    aws_api_gateway_method.method,
    aws_api_gateway_integration.lambda_integration
  ]
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_rest_api_policy.bedrock_lambda_api_policy]

  rest_api_id = aws_api_gateway_rest_api.bedrock_lambda.id
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.bedrock_lambda.id
  stage_name    = "prod"
}
