provider "aws" {
  region = "ap-south-1"
}

#creation of dynamodb table to store the time capsule data
resource "aws_dynamodb_table" "time_capsule" {
  name         = "time-capsule"
  billing_mode = "PAY_PER_REQUEST"
    hash_key     = "id" #primary key

    attribute {
        name = "id"
        type = "S" #string type
    }
    ttl {
      attribute_name = "expiration_time"  #check this column
      enabled = true
    }
    stream_enabled = true
    stream_view_type = "OLD_IMAGE" #view exactly the old image of the item before it gets deleted
}


#creating iam user for dynamodb to assume role
resource "aws_iam_role" "time_capsule_role" {
  name = "time-capsule-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

#iam policy to define the permissions (custom)
resource "aws_iam_policy" "time_capsule_policy" {
  name = "time-capsule-policy"
  

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow" #allow to put and get item from the table
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",

        ]
        Resource = aws_dynamodb_table.time_capsule.arn
      },
      {
        #allow effect to stream
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
        ]
        Resource = aws_dynamodb_table.time_capsule.stream_arn
      },
      #global powers to log and send email
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ses:SendEmail",
          
        ]
        Resource = "*"
      }
    ]
  })
}

#attach the policy to the role
resource "aws_iam_role_policy_attachment" "time_capsule_role_attachment" {
  role       = aws_iam_role.time_capsule_role.name
  policy_arn = aws_iam_policy.time_capsule_policy.arn
}

#archive the backend.py file in a zip format 
data "archive_file" "backend_zip" {
  type        = "zip"
  source_file = "backend.py"
  output_path = "backend.zip"
}

#lambda function to process the data and send email
resource "aws_lambda_function" "time_capsule_lambda" {
  function_name = "save_message_v2"
  role          = aws_iam_role.time_capsule_role.arn
  handler       = "backend.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.backend_zip.output_path
  source_code_hash = data.archive_file.backend_zip.output_base64sha256
}


#HTTP api gateway
resource "aws_apigatewayv2_api" "HTTP_api" {
  name          = "time-capsule-api"
  protocol_type = "HTTP"
 /* # adding CORS configuration to allow cross-origin requests from the frontend
  cors_configuration {
    allow_origins = ["*"] #allow all origins, can be restricted to specific domains in production
    allow_methods = ["POST", "OPTIONS"] #allow only POST and OPTIONS methods
    allow_headers = ["Content-Type"] #allow only Content-Type header
  }*/
} 

#stage for the api gateway
#if i change code , update live url automatically
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.HTTP_api.id
  name        = "$default"
  auto_deploy = true
}

#integration of api gateway with lambda function
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.HTTP_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.time_capsule_lambda.invoke_arn
  payload_format_version = "2.0" #modern lambda handling format
}

#route for the api gateway
resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.HTTP_api.id
  route_key = "POST /save_message"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

#permission for api gateway to invoke lambda function
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.time_capsule_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.HTTP_api.execution_arn}/*/*"
}

output "api_endpoint" {
  value = "${aws_apigatewayv2_api.HTTP_api.api_endpoint}/save_message"
}