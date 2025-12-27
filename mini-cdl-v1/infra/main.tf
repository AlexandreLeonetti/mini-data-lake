terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  s3_use_path_style = true

  endpoints {
    s3         = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    apigateway = "http://localhost:4566"
    iam        = "http://localhost:4566"
    sts        = "http://localhost:4566"
    logs       = "http://localhost:4566"
  }
}

locals {
  stage_name = "local"
}

# -------------------------
# S3 data bucket
# -------------------------
resource "aws_s3_bucket" "data" {
  bucket        = var.data_bucket_name
  force_destroy = true
}

# -------------------------
# IAM role for lambdas
# -------------------------
resource "aws_iam_role" "lambda_role" {
  name = "mini-cdl-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "mini-cdl-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = aws_s3_bucket.data.arn
      },
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject"],
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}

# -------------------------
# Package lambdas (zip)
# -------------------------
data "archive_file" "list_files_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/list_files.py"
  output_path = "${path.module}/.build/list_files.zip"
}

data "archive_file" "upload_url_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/upload_url.py"
  output_path = "${path.module}/.build/upload_url.zip"
}

resource "aws_lambda_function" "list_files" {
  function_name = "mini-cdl-list-files"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.11"
  handler       = "list_files.handler"

  filename         = data.archive_file.list_files_zip.output_path
  source_code_hash = data.archive_file.list_files_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.data.bucket
      # LocalStack is reachable from Lambda container by this hostname:
      S3_ENDPOINT = "http://localstack:4566"
    }
  }
}

resource "aws_lambda_function" "upload_url" {
  function_name = "mini-cdl-upload-url"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.11"
  handler       = "upload_url.handler"

  filename         = data.archive_file.upload_url_zip.output_path
  source_code_hash = data.archive_file.upload_url_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.data.bucket
      S3_ENDPOINT = "http://localstack:4566"
    }
  }
}

# -------------------------
# API Gateway (REST API) – easiest with LocalStack community
# -------------------------
resource "aws_api_gateway_rest_api" "api" {
  name = "mini-cdl-api"
}

# /files
resource "aws_api_gateway_resource" "files" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "files"
}

resource "aws_api_gateway_method" "files_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.files.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "files_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.files.id
  http_method             = aws_api_gateway_method.files_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_files.invoke_arn
}

# /upload-url
resource "aws_api_gateway_resource" "upload_url" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "upload-url"
}

resource "aws_api_gateway_method" "upload_url_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.upload_url.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_url_post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.upload_url.id
  http_method             = aws_api_gateway_method.upload_url_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload_url.invoke_arn
}

# Let API Gateway invoke lambdas
resource "aws_lambda_permission" "allow_apigw_list" {
  statement_id  = "AllowAPIGatewayInvokeListFiles"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_files.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "allow_apigw_upload" {
  statement_id  = "AllowAPIGatewayInvokeUploadUrl"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_url.function_name
  principal     = "apigateway.amazonaws.com"
}

# Deploy API
resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.files_get,
    aws_api_gateway_integration.upload_url_post
  ]
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  stage_name    = local.stage_name
}

