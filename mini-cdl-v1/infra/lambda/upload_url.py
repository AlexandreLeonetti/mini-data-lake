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

