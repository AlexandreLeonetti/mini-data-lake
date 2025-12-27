**Mini-CDL v1 fully locally** on your Mac and test it end-to-end **without AWS** by using an AWS emulator in Docker.

# Terraform mental model (this project)
* **provider** "aws" points Terraform at LocalStack endpoints.
* **aws_s3_bucket.data** creates the lake bucket.
* **archive_file** zips the Python files into deployable Lambda artifacts.
* **(aws_lambda_function.*)** deploys code + env vars.
* **(aws_api_gateway_*)** creates routes and integrates them to Lambdas.
* **outputs.tf** prints URLs so you can test without digging in the console.

The simplest “close to AWS” local setup is:

* **LocalStack (Docker)** → emulates **S3 + Lambda + API Gateway + IAM**
* **Terraform** → creates the buckets, lambdas, API routes
* **curl** → tests upload + list

Below is a complete, copy-paste guide.

---

# Mini-CDL v1 Local Guide (Mac) — Terraform + LocalStack

## 0) Prerequisites (one-time)

You need:

* **Docker Desktop** (running)
* **Terraform**
* **Python 3** (for lambda code)
* (Optional but helpful) **jq**

Quick checks:

```bash
docker --version
terraform -version
python3 --version
jq --version 2>/dev/null || echo "jq not installed (optional)"
```

---

## 1) Create the project structure

```bash
mkdir -p mini-cdl-v1/infra/lambda
cd mini-cdl-v1
```

---

## 2) Start LocalStack (local “AWS”, AWS emulator)

Create `docker-compose.yml` at the root (`mini-cdl-v1/docker-compose.yml`):

```yaml
services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,lambda,apigateway,iam,sts,logs,cloudwatch
      - DEBUG=0
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
```

Start it:

```bash
docker compose up -d
docker compose logs -f localstack
```

Wait until you see something like “Ready.” Then Ctrl+C the logs (container keeps running).

---

## 3) Write the Lambda functions

### 3.1 `infra/lambda/list_files.py`

```python
import json
import os
import boto3

def handler(event, context):
    bucket = os.environ["BUCKET_NAME"]
    endpoint = os.environ.get("S3_ENDPOINT")  # localstack: http://localstack:4566

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id="test",
        aws_secret_access_key="test",
        region_name="us-east-1",
    )

    resp = s3.list_objects_v2(Bucket=bucket)
    keys = [obj["Key"] for obj in resp.get("Contents", [])]

    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"bucket": bucket, "files": keys}),
    }
```

what's going on :
* curl
*  → API Gateway
*     → Lambda function (list_files.handler)
*          → S3
*      ← Lambda returns JSON
*  ← API Gateway returns HTTP response


API Gateway:
receives HTTP
invokes Lambda
converts Lambda’s return value into HTTP

### 3.2 `infra/lambda/upload_url.py`

This returns a **presigned PUT URL** for S3 upload.

```python
import json
import os
import boto3

def handler(event, context):
    bucket = os.environ["BUCKET_NAME"]
    endpoint = os.environ.get("S3_ENDPOINT")  # localstack: http://localstack:4566

    body = event.get("body") or "{}"
    if isinstance(body, str):
        body = json.loads(body)

    key = body.get("key")
    if not key:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing 'key' in JSON body"})}

    content_type = body.get("content_type", "application/octet-stream")

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id="test",
        aws_secret_access_key="test",
        region_name="us-east-1",
    )

    url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": bucket, "Key": key, "ContentType": content_type},
        ExpiresIn=300,
    )

    # IMPORTANT: Terraform will later output the API URL.
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"bucket": bucket, "key": key, "content_type": content_type, "upload_url": url}),
    }
```

---

## 4) Terraform config for LocalStack

Create these files in `mini-cdl-v1/infra/`.

### 4.1 `infra/main.tf`

```hcl
#############################################
# Terraform configuration
#############################################

terraform {
  # Minimum Terraform version required
  required_version = ">= 1.5.0"

  # Providers Terraform will use
  required_providers {
    # AWS provider: used to create S3, Lambda, API Gateway, IAM, etc.
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    # Archive provider: used to ZIP Lambda source code
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

#############################################
# AWS provider (pointing to LocalStack)
#############################################

provider "aws" {
  # Region is required by AWS APIs even when using LocalStack
  region = "us-east-1"

  # Dummy credentials (LocalStack does not validate them)
  access_key = "test"
  secret_key = "test"

  # Disable real AWS checks (because we are NOT talking to real AWS)
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  # Force path-style S3 URLs (required for LocalStack compatibility)
  s3_use_path_style = true

  # Override AWS service endpoints to point to LocalStack
  endpoints {
    s3         = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    apigateway = "http://localhost:4566"
    iam        = "http://localhost:4566"
    sts        = "http://localhost:4566"
    logs       = "http://localhost:4566"
  }
}

#############################################
# Local variables
#############################################

locals {
  # API Gateway stage name (appears in the URL)
  stage_name = "local"
}

#############################################
# S3 bucket = "data lake"
#############################################

resource "aws_s3_bucket" "data" {
  # Bucket name is provided via variables.tf
  bucket = var.data_bucket_name

  # Allows terraform destroy to delete the bucket even if it has files
  force_destroy = true
}

#############################################
# IAM role for Lambda functions
#############################################

resource "aws_iam_role" "lambda_role" {
  name = "mini-cdl-lambda-role"

  # Trust policy: allows AWS Lambda service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

#############################################
# IAM policy attached to Lambda role
#############################################

resource "aws_iam_role_policy" "lambda_policy" {
  name = "mini-cdl-lambda-policy"
  role = aws_iam_role.lambda_role.id

  # Permissions granted to Lambdas
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Allow listing objects in the bucket
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.data.arn
      },
      # Allow uploading and downloading objects
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}

#############################################
# Package Lambda source code into ZIP files
#############################################

# Zip for list_files Lambda
data "archive_file" "list_files_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/list_files.py"
  output_path = "${path.module}/.build/list_files.zip"
}

# Zip for upload_url Lambda
data "archive_file" "upload_url_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/upload_url.py"
  output_path = "${path.module}/.build/upload_url.zip"
}

#############################################
# Lambda: list files in S3 bucket
#############################################

resource "aws_lambda_function" "list_files" {
  function_name = "mini-cdl-list-files"

  # IAM role that defines permissions
  role = aws_iam_role.lambda_role.arn

  runtime = "python3.11"
  handler = "list_files.handler"

  # ZIP file created above
  filename         = data.archive_file.list_files_zip.output_path
  source_code_hash = data.archive_file.list_files_zip.output_base64sha256

  # Environment variables available inside Lambda
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.data.bucket

      # Used so boto3 talks to LocalStack instead of real AWS
      S3_ENDPOINT = "http://localstack:4566"
    }
  }
}

#############################################
# Lambda: generate presigned upload URL
#############################################

resource "aws_lambda_function" "upload_url" {
  function_name = "mini-cdl-upload-url"

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.11"
  handler = "upload_url.handler"

  filename         = data.archive_file.upload_url_zip.output_path
  source_code_hash = data.archive_file.upload_url_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.data.bucket
      S3_ENDPOINT = "http://localstack:4566"
    }
  }
}

#############################################
# API Gateway (REST API)
#############################################

resource "aws_api_gateway_rest_api" "api" {
  name = "mini-cdl-api"
}

#############################################
# GET /files → list_files Lambda
#############################################

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

  # AWS_PROXY means Lambda controls the HTTP response
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_files.invoke_arn
}

#############################################
# POST /upload-url → upload_url Lambda
#############################################

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

#############################################
# Allow API Gateway to invoke Lambdas
#############################################

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

#############################################
# Deploy and expose the API
#############################################

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  # Ensures integrations exist before deployment
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

```

### 4.2 `infra/variables.tf`

```hcl
variable "data_bucket_name" {
  type    = string
  default = "mini-cdl-data-local"
}
```

### 4.3 `infra/outputs.tf`

LocalStack REST API invoke format:
`http://localhost:4566/restapis/<api_id>/<stage>/_user_request_`

```hcl
output "api_base_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/${local.stage_name}/_user_request_"
}

output "data_bucket_name" {
  value = aws_s3_bucket.data.bucket
}
```

---

## 5) Deploy locally

From `mini-cdl-v1/infra`:

```bash
cd infra
terraform init
terraform apply
```

At the end, Terraform prints outputs. Grab the API base URL:

```bash
API_BASE=$(terraform output -raw api_base_url)
echo "$API_BASE"
```

---

## 6) Test (upload + list)

### 6.1 List files (should be empty)

```bash
curl -s "$API_BASE/files" | jq .
```

If you don’t have `jq`:

```bash
curl -s "$API_BASE/files"
```



### 6.2 Create an upload URL


```bash
curl -s -X POST "$API_BASE/upload-url" \
  -H "content-type: application/json" \
  -d '{"key":"hello.txt","content_type":"text/plain"}' | jq -r .upload_url
```

Save it:

```bash
UPLOAD_URL=$(curl -s -X POST "$API_BASE/upload-url" \
  -H "content-type: application/json" \
  -d '{"key":"hello.txt","content_type":"text/plain"}' | jq -r .upload_url)

echo "$UPLOAD_URL"
```

### 6.3 Upload a file to S3 via the presigned URL
```bash
echo "Hello Mini-CDL" > hello.txt

UPLOAD_URL=$(curl -s -X POST "$API_BASE/upload-url" \
  -H "content-type: application/json" \
  -d '{"key":"hello.txt","content_type":"text/plain"}' | jq -r .upload_url)

# Lambda runs in Docker and signs URLs with host "localstack".
# Your Mac can't resolve "localstack", so rewrite to localhost:
UPLOAD_URL_HOST=${UPLOAD_URL/localstack/localhost}

curl -X PUT "$UPLOAD_URL_HOST" \
  -H "Content-Type: text/plain" \
  --data-binary @hello.txt
```
instead of
```bash
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: text/plain" \
  --data-binary @hello.txt
```
because 
localstack is a Docker-internal hostname.  Mac uses localhost:4566 to reach LocalStack instead.
### 6.4 List again (should include hello.txt)

```bash
curl -s "$API_BASE/files" | jq .
```

---

## 7) Quick “S3 sanity check” (optional)

This proves the object really exists in the bucket.

```bash
BUCKET=$(terraform output -raw data_bucket_name)
aws --endpoint-url=http://localhost:4566 s3 ls "s3://$BUCKET"
```

If your AWS CLI complains about credentials, set dummy ones:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

---

## 8) Clean up (destroy everything)

### Terraform resources:

```bash
terraform destroy
```

### Stop LocalStack:

```bash
cd ..
docker compose down -v
```

---

# Notes / gotchas (so you don’t get stuck)

* This local guide uses **API Gateway REST API (v1)** because it’s the most reliable in LocalStack Community.

  * In the cloud guide later, we can switch to **API Gateway HTTP API (v2)** exactly like your Sanofi setup.
* The presigned URL uses the LocalStack endpoint; that’s why Lambda uses `S3_ENDPOINT=http://localstack:4566`.

---

