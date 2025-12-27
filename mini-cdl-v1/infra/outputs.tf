output "api_base_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/${local.stage_name}/_user_request_"
}

output "data_bucket_name" {
  value = aws_s3_bucket.data.bucket
}

