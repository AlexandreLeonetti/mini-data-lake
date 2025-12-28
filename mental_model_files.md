## 🧠 Mini-CDL v1 — Active Recall (Project Files & Responsibilities)

This section tests whether you understand **what each file is responsible for**  
and **why it exists** in the project.

---

### 1️⃣ What is the role of `docker-compose.yml`?

**Answer**  
It starts LocalStack in Docker, which emulates AWS services locally so Terraform can deploy infrastructure without using real AWS.

---

### 2️⃣ What is the purpose of the `infra/` directory?

**Answer**  
`infra/` contains all infrastructure-as-code definitions (Terraform and Lambda code) needed to deploy the backend of Mini-CDL.

---

### 3️⃣ What is the responsibility of `main.tf`?
**Answer**  
`main.tf` declares all core infrastructure resources: S3 bucket, IAM roles and policies, Lambda functions, API Gateway routes, and their wiring.

---

### 4️⃣ What is the role of `variables.tf`?
**Answer**  
It declares configurable inputs (like the S3 bucket name) so the infrastructure can be reused or adjusted without modifying core logic.

---

### 5️⃣ What does `outputs.tf` provide?
**Answer**  
It exposes useful values after deployment (such as the API base URL and bucket name) so users can test or integrate with the system.

---

### 6️⃣ Why is there a `lambda/` directory?
**Answer**  
It contains the Lambda function source code, separated from Terraform to keep application logic distinct from infrastructure definitions.

---

### 7️⃣ What does `list_files.py` do?
**Answer**  
It implements a Lambda function that lists objects in the S3 data bucket and returns the result as an HTTP JSON response.

---

### 8️⃣ What does `upload_url.py` do?
**Answer**  
It implements a Lambda function that generates a presigned S3 PUT URL, allowing clients to upload files securely without direct S3 credentials.

---

### 9️⃣ What is `terraform.tfstate` and why is it dangerous?
**Answer**  
It stores Terraform’s current view of deployed infrastructure, including resource IDs and possibly sensitive data, and is environment-specific.

---

### 🔟 Why are there multiple `terraform.tfstate` files?
**Answer**  
Each Terraform working directory maintains its own state file; backups are created automatically to protect against corruption or failed applies.

---

---

## 🧠 Mini-CDL v1 — Active Recall (Questions Only)

---

1️⃣ What is the role of `docker-compose.yml`?

2️⃣ What is the purpose of the `infra/` directory?

3️⃣ What is the responsibility of `main.tf`?

4️⃣ What is the role of `variables.tf`?

5️⃣ What does `outputs.tf` provide?

6️⃣ Why is there a `lambda/` directory?

7️⃣ What does `list_files.py` do?

8️⃣ What does `upload_url.py` do?

9️⃣ What is `terraform.tfstate` and why is it dangerous?

🔟 Why are there multiple `terraform.tfstate` files?

---
