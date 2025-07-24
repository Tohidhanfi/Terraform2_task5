# Task 6 – Strapi on AWS ECS Fargate (Serverless, Managed, Scalable)

This task shows how to deploy Strapi on AWS using ECS Fargate, ECR, and an Application Load Balancer, all managed by Terraform. This version uses the AWS default VPC and creates new, unique subnets for isolation (no custom VPC/IGW/route tables needed).

---

## Prerequisites
- AWS account with permissions for ECR, ECS, VPC, ALB, and IAM
- AWS CLI, Docker, and Terraform installed locally
- Strapi Dockerfile ready (see `strapi-app/Dockerfile`)

---

## 1. Build & Push Docker Image to ECR
1. **Provision ECR repository with Terraform:**
   - Run `terraform apply` in `terraform3_task6/` to create the ECR repo.
2. **Push your Docker image:**
   - Follow `terraform3_task6/README_ECR_PUSH.md` for:
     - Authenticating Docker to ECR
     - Building the image
     - Tagging and pushing to ECR

---

## 2. Deploy Infrastructure with Terraform
1. **Configure variables in `terraform3_task6/variables.tf` as needed**
2. **Deploy:**
   ```sh
   cd terraform3_task6
   terraform init
   terraform apply
   ```
   This will provision:
   - ECS Cluster, Task Definition (using your ECR image)
   - Fargate Service
   - Security Groups for ALB and ECS tasks
   - Application Load Balancer (ALB)
   - New, unique subnets in the default VPC for isolation

---

## 3. Access Strapi
- After `terraform apply`, Terraform will output the ALB DNS name:
  ```
  alb_dns_name = <your-alb-dns>
  ```
- Visit `http://<your-alb-dns>` in your browser to access Strapi.

---

## Notes
- The ECS service runs the Strapi container in private subnets, fronted by a public ALB.
- You can customize the region and other settings in `variables.tf`.
- For production, configure environment variables, secrets, and persistent storage as needed.
- This method is fully managed and serverless (no EC2 instances to manage).
- Uses the AWS default VPC for simplicity and compatibility with shared environments. 