## 🧠 Mini-CDL v1 — Active Recall (Terraform + Architecture)

Use this section for **active recall training**.  
👉 Read the **question**, answer **out loud**, then check the answer.

---

### 1️⃣ What problem does Mini-CDL 1 do ?

**Answer**  
1Mini-CDL is a backend service  where users can upload files to S3 and list them via a public API 
2built with API Gateway and Lambda, 
3fully managed by Terraform.

---

### 2️⃣ What is the complete data flow?

**Answer**  
the full request flow when a user lists files.
User → HTTP request → 
API Gateway → Lambda function → S3 bucket → 
Lambda response → API Gateway → HTTP response.

---

### 3️⃣ Why do we use LocalStack?

**Answer**  
LocalStack emulates AWS services locally so 
Terraform can deploy with 0 costs. 

---

### 4️⃣ What is the role of Terraform in this system?

**Answer**  
Terraform declares and creates all infrastructure components (S3, IAM, Lambda, API Gateway) 
and wires them together automatically.

---

### 5️⃣ What are the 6  most important Terraform resource types here?

**Answer**
- `aws_api_gateway_*`
- `aws_iam_role`  
- `aws_iam_role_policy`
- `aws_lambda_function`
- `aws_lambda_permission`
- `aws_s3_bucket`

---
### 6️⃣ Why does Lambda need an IAM role?

**Answer**  
without iam role Lambda cannot access S3 (or any AWS service) 
with iam role and policy there is granted permissions.
---

### 7️⃣ What does type = `AWS_PROXY` integration mean?

**Answer**  
It means the Lambda function fully controls the HTTP response (status code, headers, body), 
API Gateway forwards it directly to the client.

---

### 8️⃣ How does Terraform know in which order to create resources?

**Answer**  
Terraform files are not executed top-to-bottom 
Terraform builds a dependency graph by analyzing references between resources 
(for example, Lambdas referencing IAM roles or S3 buckets).

---

### 9️⃣ Why are Lambda source files zipped?

**Answer**  

because AWS Lambda requires code to be uploaded as a ZIP file, 
and `archive_file` packages the Python source automatically during deployment.

---

### 🔟 What are the most important Lambda environment variables?

**Answer**
- `BUCKET_NAME` → tells Lambda which S3 bucket is the data lake  
- `S3_ENDPOINT` → tells boto3 to use LocalStack instead of real AWS  
- *(implicit)* IAM role credentials → allow Lambda to access S3 securely  

---

### 🧠 Interview Tip

If you can explain all 10 answers **without looking**, you understand:
- the architecture
- the Terraform wiring
- the data flow
- the IAM boundaries

That is **more than enough** for most infrastructure interviews.

### 1️⃣ What problem does Mini-CDL v1 solve?
### 2️⃣ What is the complete data flow?
### 3️⃣ Why do we use LocalStack?
### 4️⃣ What is the role of Terraform in this system?
### 5️⃣ What are the most important Terraform resource types here?
### 6️⃣ Why does Lambda need an IAM role?
### 7️⃣ What does `AWS_PROXY` integration mean?
### 8️⃣ How does Terraform know in which order to create resources?
### 9️⃣ Why are Lambda source files zipped?
### 🔟 What are the most important Lambda environment variables?

