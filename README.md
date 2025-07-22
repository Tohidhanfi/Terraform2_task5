# Task 5 - Automated CI/CD Deployment with GitHub Actions, AWS ECR, Terraform, and EC2

This guide describes how to set up a complete CI/CD pipeline for your Strapi application using GitHub Actions, AWS Elastic Container Registry (ECR), Terraform, and EC2. The process automates building and pushing Docker images, and deploying updates to an EC2 instance.

---

## Overview
- **CI Workflow:** On every push to `main`, GitHub Actions builds the Strapi Docker image and pushes it to AWS ECR.
- **CD Workflow:** A manually triggered GitHub Actions workflow runs Terraform to deploy the latest image to an EC2 instance.
- **EC2 Instance:** Provisions with SSH access, runs Docker, and hosts both PostgreSQL and Strapi containers.

---

## Prerequisites
- AWS account with permissions for ECR, EC2, and IAM.
- An ECR repository created for your Strapi images.
- An EC2 key pair for SSH access.
- GitHub repository with the following secrets configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `ECR_REGISTRY` (e.g., `123456789012.dkr.ecr.us-east-2.amazonaws.com`)
  - `ECR_REPOSITORY` (e.g., `strapi-app-tohid`)

---

## 1. CI Workflow: Build & Push Docker Image to ECR

- **File:** `.github/workflows/ci.yaml`
- **Trigger:** On push to `main` branch
- **Steps:**
  1. Checkout code
  2. Configure AWS credentials
  3. Log in to ECR
  4. Build Docker image (tagged with a unique value)
  5. Push image to ECR
  6. Save and upload the image tag as an artifact for the CD workflow

---

## 2. CD Workflow: Deploy with Terraform

- **File:** `.github/workflows/cd.yaml`
- **Trigger:** Manually via GitHub Actions (`workflow_dispatch`)
- **Steps:**
  1. Checkout code
  2. Download the image tag artifact from the CI workflow
  3. Set the `IMAGE_TAG` environment variable
  4. Configure AWS credentials
  5. Run `terraform init`, `plan`, and `apply` in the `terraform2_task5` directory, passing the image tag

---

## 3. Terraform: EC2 & Docker Deployment

- **Directory:** `terraform2_task5/`
- **Key files:**
  - `main.tf`: Provisions EC2, security group, and runs a user data script to install Docker, pull the image from ECR, and run PostgreSQL and Strapi containers.
  - `variables.tf`: Defines variables for AWS region, AMI, instance type, key name, ECR registry/repo, and image tag.
  - `terraform.tfvars`: Provides values for the above variables.

**Example `terraform.tfvars`:**
```hcl
aws_region     = "us-east-2"
ami_id         = "ami-0c02fb55956c7d316"
instance_type  = "t2.micro"
key_name       = "strapi" # Your EC2 key pair name
ECR_registry   = "123456789012.dkr.ecr.us-east-2.amazonaws.com"
ECR_repository = "strapi-app-tohid"
image_tag      = "latest" # This is set dynamically by the workflow
```

---

## 4. Required GitHub Secrets
| Secret Name           | Description                                      |
|----------------------|--------------------------------------------------|
| AWS_ACCESS_KEY_ID    | AWS access key with ECR/EC2/IAM permissions      |
| AWS_SECRET_ACCESS_KEY| AWS secret key                                   |
| AWS_REGION           | AWS region (e.g., us-east-2)                     |
| ECR_REGISTRY         | ECR registry URI                                 |
| ECR_REPOSITORY       | ECR repository name                              |

---

## 5. Verification
- After deployment, Strapi should be accessible at:  
  `http://<EC2_PUBLIC_IP>:1337/admin`
- You can SSH into the EC2 instance using your key pair:
  ```sh
  ssh -i /path/to/your-key.pem ec2-user@<EC2_PUBLIC_IP>
  # or use ubuntu@ if using Ubuntu AMI
  ```
- To check running containers:
  ```sh
  sudo docker ps
  sudo docker logs strapi
  ```

---

## 6. Notes
- The image tag is automatically passed from the CI workflow to the CD workflow and then to Terraform.
- Ensure your EC2 security group allows inbound traffic on ports 22 (SSH) and 1337 (Strapi).
- For production, use strong, unique secrets and secure your database.
- You can further automate verification by adding a `curl` step to the CD workflow to check the Strapi endpoint after deployment.# Terraform2_task5
