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

