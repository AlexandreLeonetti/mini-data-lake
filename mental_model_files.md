## 🧠 Mini-CDL v1 — Active Recall (Project Files & Responsibilities)

This section tests whether you understand **what each file is responsible for**  
and **why it exists** in the project.

---

### 1️⃣ What is the role of `docker-compose.yml`?

**Question**  
What does `mini-cdl-v1/docker-compose.yml` do?

**Answer**  
It starts LocalStack in Docker, which emulates AWS services locally so Terraform can deploy infrastructure without using real AWS.

---

### 2️⃣ What is the purpose of the `infra/` directory?

**Question**  
What belongs inside `infra/` and why?

**Answer**  
`infra/` contains all infrastructure-as-code definitions (Terraform and Lambda code) needed to deploy the backend of Mini-CDL.

---

### 3️⃣ What is the responsibility of `main.tf`?

**Question**  
What does `infra/main.tf` define?

**Answer**  
`main.tf` declares all core infrastructure resources: S3 bucket, IAM roles and policies, Lambda functions, API Gateway routes, and their wiring.

---

### 4️⃣ What is the role of `variables.tf`?

**Question**  
Why do we have `infra/variables.tf`?

**Answer**  
It declares configurable inputs (like the S3 bucket name) so the infrastructure can be reused or adjusted without modifying core logic.

---

### 5️⃣ What does `outputs.tf` provide?

**Question**  
What is the purpose of `infra/outputs.tf`?

**Answer**  
It exposes useful values after deployment (such as the API base URL and bucket name) so users can test or integrate with the system.

---

### 6️⃣ Why is there a `lambda/` directory?

**Question**  
What lives inside `infra/lambda/` and why is it separated?

**Answer**  
It contains the Lambda function source code, separated from Terraform to keep application logic distinct from infrastructure definitions.

---

### 7️⃣ What does `list_files.py` do?

**Question**  
What is the responsibility of `infra/lambda/list_files.py`?

**Answer**  
It implements a Lambda function that lists objects in the S3 data bucket and returns the result as an HTTP JSON response.

---

### 8️⃣ What does `upload_url.py` do?

**Question**  
What is the responsibility of `infra/lambda/upload_url.py`?

**Answer**  
It implements a Lambda function that generates a presigned S3 PUT URL, allowing clients to upload files securely without direct S3 credentials.

---

### 9️⃣ What is `terraform.tfstate` and why is it dangerous?

**Question**  
What is `terraform.tfstate`, and why should it not be committed to Git?

**Answer**  
It stores Terraform’s current view of deployed infrastructure, including resource IDs and possibly sensitive data, and is environment-specific.

---

### 🔟 Why are there multiple `terraform.tfstate` files?

**Question**  
Why do we see several `terraform.tfstate` and `.backup` files?

**Answer**  
Each Terraform working directory maintains its own state file; backups are created automatically to protect against corruption or failed applies.

---

### 🧠 Interview Tip

If you can explain **every file’s role** clearly, you demonstrate:
- ownership of the project
- clean mental separation of concerns
- real Terraform understanding (not copy-paste usage)

That’s a **strong signal** in interviews.

