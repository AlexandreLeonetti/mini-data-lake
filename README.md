Start with **Terraform first**, and use a diagram only as a sanity check (you can draw it in 2 minutes once the resources exist). Here’s the cleanest path to get Mini-CDL v1 working fast, without overthinking.

---

## What you build first (order that reduces confusion)

### Step 0 — Make a new tiny repo folder

Create a separate folder so you don’t fight the existing Sanofi stack.

```bash
mkdir mini-cdl-v1 && cd mini-cdl-v1
mkdir -p infra/lambda
```

---

## Step 1 — Create the simplest architecture (no ECS, no custom domain)

For v1, skip Route53/ALB/ECS entirely. Use:

* **S3 data bucket**
* **API Gateway (public)**
* **2 Lambdas**
* **IAM role for Lambdas**

This already matches: **User → UI → API → Lambda → S3** (UI can even be Postman/curl at first).

### Files you need (minimal)

You do need a few Terraform files, but keep it small:

* `infra/main.tf`
* `infra/variables.tf`
* `infra/outputs.tf`
* `infra/lambda/list_files.py`
* `infra/lambda/upload_url.py`

That’s enough.

---

## Step 2 — Build backend first (Lambda + API + S3)

Because once the API works, the frontend becomes trivial.

### 2.1 Terraform skeleton (what goes in main.tf)

In `infra/main.tf` you will define:

* `aws_s3_bucket` (data bucket)
* `aws_iam_role` + policy allowing `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`
* `aws_lambda_function` x2 (zip packaged)
* `aws_apigatewayv2_api` (HTTP API)
* `aws_apigatewayv2_integration` + `aws_apigatewayv2_route` for:

  * `GET /files`
  * `POST /upload-url`
* `aws_lambda_permission` to let API Gateway invoke lambdas

**Yes:** you start by creating a `main.tf`. That’s your “source of truth”.

### 2.2 Test with curl (no frontend yet)

Once deployed you’ll test:

* `GET https://<api-id>.execute-api.<region>.amazonaws.com/files`
* `POST https://<api-id>.../upload-url` → returns a presigned URL
* Then `curl -X PUT <presigned_url> --upload-file something.txt`

---

## Step 3 — Only after backend works, add the frontend

Frontend options in order of simplicity:

### Option A (fastest): no UI, use curl/Postman

This is honestly the best way to learn first.

### Option B: tiny static HTML in S3

Just one `index.html` calling your API.
You can do that after backend is confirmed.

### Option C (later): ECS nginx proxy

Add it only once you understand the flow. ECS adds a lot of “noise”.

---

## Do you need a diagram?

Not at the start.

But it helps once you have the resources, because the diagram becomes **grounded**:

### Mini diagram (v1)

* Browser
  → API Gateway (public)
  → Lambda
  → S3

That’s enough.

If you want, we can render a clean diagram later (Mermaid or draw.io), but the fastest learning is:
**deploy → hit endpoints → see S3 objects appear.**

---

# Your exact “first action” checklist (do this now)

1. Create the folder structure (above)
2. Create `infra/main.tf`, `infra/variables.tf`, `infra/outputs.tf`
3. Write 2 simple lambdas in python:

   * list keys in bucket
   * return presigned PUT URL
4. `terraform init`
5. `terraform apply`
6. Test with curl

---

## If you want, I can generate the full minimal code in one message

Tell me two things and I’ll output the complete files ready to copy/paste:

1. Which AWS region? (e.g. `eu-west-3` / `eu-west-1`)
2. Do you want lambdas in **Python** or **Node.js**?

Then I’ll give you:

* full Terraform `main.tf/variables.tf/outputs.tf`
* both Lambda source files
* a small `Makefile` or bash commands to zip + deploy
* curl test commands

No diagram needed until it runs.

