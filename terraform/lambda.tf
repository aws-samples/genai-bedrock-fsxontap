
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_bedrock_rag_retreival_role" {
  name = "Lambda-${var.aws_region}-BedrockRagRetreival"

  assume_role_policy = jsonencode(
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
)
}
resource "aws_iam_role_policy" "lambda_bedrock_rag_retreival_policy" {
  name        = "Lambda-${var.aws_region}-BedrockRagRetreival"
  role        = aws_iam_role.lambda_bedrock_rag_retreival_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Bedrock",
            "Effect": "Allow",
            "Action": [
				"bedrock:GetFoundationModel",
				"bedrock:InvokeModel",
				"bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
            ]
        },
        {
            "Sid": "OpensearchServerless",
            "Effect": "Allow",
            "Action": [
				"aoss:APIAccessAll"
            ],
            "Resource": [
                "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:collection/${aws_opensearchserverless_collection.fsxnragvector.id}"
            ]
        },
        {
            "Sid": "DynamoDB",
            "Effect": "Allow",
            "Action": [
				"dynamodb:ListTables",
				"dynamodb:GetItem",
				"dynamodb:PutItem",
				"dynamodb:UpdateItem"
            ],
            "Resource": [
                "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.session-table.name}"
            ]
        }
    ]
    })
}


resource "aws_iam_role_policy_attachment" "lambda_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_bedrock_rag_retreival_role.name
}

resource "aws_lambda_function" "bedrock_rag_retreival" {

  image_uri = docker_registry_image.push-rag-image.name
  function_name = "bedrock_rag_retreival"
  role          = aws_iam_role.lambda_bedrock_rag_retreival_role.arn

  architectures = ["x86_64"]
  package_type = "Image"

  timeout = 90

  environment {
    variables = {
      aoss_host = aws_opensearchserverless_collection.fsxnragvector.collection_endpoint
    }
  }
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bedrock_rag_retreival.function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.bedrock_lambda.execution_arn}/*/*/${aws_api_gateway_resource.root.path_part}"
}