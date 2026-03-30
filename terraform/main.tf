terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ─── SQS Queue ────────────────────────────────────────────────────────────────

resource "aws_sqs_queue" "hello_world" {
  name = "hello-world-queue"
}

# ─── IAM: Producer Lambda ─────────────────────────────────────────────────────

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "producer" {
  name               = "hello-world-producer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "producer_basic" {
  role       = aws_iam_role.producer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "producer_sqs" {
  name = "sqs-send"
  role = aws_iam_role.producer.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.hello_world.arn
    }]
  })
}

# ─── DynamoDB ─────────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "greetings" {
  name         = "greetings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "name"
  range_key    = "timestamp"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

# ─── IAM: Consumer Lambda ─────────────────────────────────────────────────────

resource "aws_iam_role" "consumer" {
  name               = "hello-world-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "consumer_basic" {
  role       = aws_iam_role.consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "consumer_sqs" {
  role       = aws_iam_role.consumer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "consumer_dynamodb" {
  name = "dynamodb-write"
  role = aws_iam_role.consumer.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = aws_dynamodb_table.greetings.arn
    }]
  })
}

# ─── Lambda: Producer ─────────────────────────────────────────────────────────

data "archive_file" "producer" {
  type        = "zip"
  source_file = "${path.module}/../lambda_function.py"
  output_path = "${path.module}/../function.zip"
}

resource "aws_lambda_function" "producer" {
  function_name    = "hello-world-producer"
  role             = aws_iam_role.producer.arn
  runtime          = "python3.12"
  handler          = "lambda_function.handler"
  filename         = data.archive_file.producer.output_path
  source_code_hash = data.archive_file.producer.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.hello_world.url
    }
  }
}

# ─── Lambda: Consumer ─────────────────────────────────────────────────────────

data "archive_file" "consumer" {
  type        = "zip"
  source_file = "${path.module}/../consumer.py"
  output_path = "${path.module}/../consumer.zip"
}

resource "aws_lambda_function" "consumer" {
  function_name    = "hello-world-consumer"
  role             = aws_iam_role.consumer.arn
  runtime          = "python3.12"
  handler          = "consumer.handler"
  filename         = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.greetings.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.hello_world.arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 10
}

# ─── Lambda: Frontend ─────────────────────────────────────────────────────────

resource "aws_iam_role" "frontend" {
  name               = "hello-world-frontend-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "frontend_basic" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "frontend_dynamodb" {
  name = "dynamodb-read"
  role = aws_iam_role.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:Scan"]
      Resource = aws_dynamodb_table.greetings.arn
    }]
  })
}

data "archive_file" "frontend" {
  type        = "zip"
  source_file = "${path.module}/../frontend.py"
  output_path = "${path.module}/../frontend.zip"
}

resource "aws_lambda_function" "frontend" {
  function_name    = "hello-world-frontend"
  role             = aws_iam_role.frontend.arn
  runtime          = "python3.12"
  handler          = "frontend.handler"
  filename         = data.archive_file.frontend.output_path
  source_code_hash = data.archive_file.frontend.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.greetings.name
    }
  }
}

resource "aws_lambda_permission" "apigw_frontend" {
  statement_id  = "AllowAPIGatewayInvokeFrontend"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.frontend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_world.execution_arn}/*/*"
}

# ─── API Gateway ──────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "hello_world" {
  name          = "hello-world-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "producer" {
  api_id                 = aws_apigatewayv2_api.hello_world.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.producer.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_hello" {
  api_id    = aws_apigatewayv2_api.hello_world.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

resource "aws_apigatewayv2_route" "post_hello" {
  api_id    = aws_apigatewayv2_api.hello_world.id
  route_key = "POST /hello"
  target    = "integrations/${aws_apigatewayv2_integration.producer.id}"
}

resource "aws_apigatewayv2_integration" "frontend" {
  api_id                 = aws_apigatewayv2_api.hello_world.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.frontend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.hello_world.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.frontend.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.hello_world.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_world.execution_arn}/*/*"
}

# ─── Outputs ──────────────────────────────────────────────────────────────────

output "api_url" {
  value = "${aws_apigatewayv2_stage.default.invoke_url}/hello"
}

output "queue_url" {
  value = aws_sqs_queue.hello_world.url
}
