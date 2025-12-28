🧠 Mini-CDL v1 — Active Recall Questions (Terraform + Architecture)
1️⃣ What problem does Mini-CDL v1 solve?
Question:
In one sentence, what does Mini-CDL v1 do?
Answer:
It provides a minimal data-lake backend where users can upload files to S3 and list them via a public API built with API Gateway and Lambda, fully managed by Terraform.
2️⃣ What is the complete data flow?
Question:
Describe the full request flow when a user lists files.
Answer:
User → HTTP request → API Gateway → Lambda function → S3 bucket → Lambda response → API Gateway → HTTP response.
3️⃣ Why do we use LocalStack?
Question:
Why is LocalStack used instead of real AWS?
Answer:
LocalStack emulates AWS services locally so Terraform can deploy real infrastructure logic without creating resources in AWS or incurring costs.
4️⃣ What is the role of Terraform in this system?
Question:
What does Terraform do in Mini-CDL v1?
Answer:
Terraform declares and creates all infrastructure components (S3, IAM, Lambda, API Gateway) and wires them together automatically.
5️⃣ What are the most important Terraform resource types here?
Question:
Name the 5 most important Terraform resource types used.
Answer:
aws_s3_bucket
aws_iam_role / aws_iam_role_policy
aws_lambda_function
aws_api_gateway_*
aws_lambda_permission
6️⃣ Why does Lambda need an IAM role?
Question:
Why do Lambda functions need an IAM role?
Answer:
Because Lambda cannot access S3 (or any AWS service) unless explicitly granted permissions via an IAM role and policy.
7️⃣ What does AWS_PROXY integration mean?
Question:
What does type = "AWS_PROXY" do in API Gateway integrations?
Answer:
It means the Lambda function fully controls the HTTP response (status code, headers, body), and API Gateway forwards it directly to the client.
8️⃣ How does Terraform know in which order to create resources?
Question:
Terraform files are not executed top-to-bottom. How does Terraform determine creation order?
Answer:
Terraform builds a dependency graph by analyzing references between resources (e.g., Lambdas referencing IAM roles or S3 buckets).
9️⃣ Why are Lambda source files zipped?
Question:
Why do we use the archive_file data source?
Answer:
Because AWS Lambda requires code to be uploaded as a ZIP file, and archive_file packages the Python source automatically during deployment.
🔟 What are the three most important environment variables in Lambda?
Question:
Which environment variables are critical in the Lambda functions, and why?
Answer:
BUCKET_NAME: tells Lambda which S3 bucket is the data lake
S3_ENDPOINT: tells boto3 to use LocalStack instead of real AWS
(Implicit) IAM role credentials: allow Lambda to access S3 securely
