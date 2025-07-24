# Strapi Project - Multi-Environment Deployment Guide

This repository contains two main folders:
- `strapi-app/` — The Strapi application (Dockerized)
- `terraform/` — Terraform scripts for cloud automation

---

# TASK 1 - Strapi Local Setup

## Steps
1. **Clone the repository:**
   ```sh
   git clone <your-repo-url>
   cd strapi-app
   ```
2. **Install dependencies:**
   ```sh
   npm install
   ```
3. **Run in development mode:**
   ```sh
   npm run develop
   # or
   npm run dev
   ```
4. **Build for production:**
   ```sh
   npm run build
   ```
5. **Run in production mode:**
   ```sh
   npm run start
   ```

---

# TASK 2 - Dockerization (with SQLite)

## Steps
1. **Create a `.env` file in `strapi-app/` with all required secrets:**
   ```env
   APP_KEYS=yourKeyA,yourKeyB,yourKeyC,yourKeyD
   API_TOKEN_SALT=yourApiTokenSalt
   ADMIN_JWT_SECRET=yourAdminJwtSecret
   DATABASE_CLIENT=sqlite
   DATABASE_FILENAME=.tmp/data.db
   ```
2. **Build the Docker image:**
   ```sh
   docker build -t my-strapi-app ./strapi-app
   ```
3. **Run the Docker container:**
   ```sh
   docker run -p 1337:1337 --env-file ./strapi-app/.env my-strapi-app
   # Or pass secrets with -e flags
   ```
4. **Access the admin panel:**
   - Go to [http://localhost:1337/admin](http://localhost:1337/admin)

---

# TASK 3 - Docker Compose with PostgreSQL & Nginx Reverse Proxy (Local)

## Steps
1. **Create `docker-compose.yml` and `nginx.conf` in the project root:**
   - See below for example configs.
2. **Run the stack:**
```sh
   docker-compose up -d
   ```
3. **Access Strapi:**
   - Go to [http://localhost](http://localhost)

### Example `docker-compose.yml`
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: strapi
      POSTGRES_USER: strapi
      POSTGRES_PASSWORD: strapi
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - strapi-net
  strapi:
    image: tohidazure/strapi-app:latest
    depends_on:
      - postgres
    environment:
      DATABASE_CLIENT: postgres
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_NAME: strapi
      DATABASE_USERNAME: strapi
      DATABASE_PASSWORD: strapi
      APP_KEYS: ...
      API_TOKEN_SALT: ...
      ADMIN_JWT_SECRET: ...
    ports:
      - "1337:1337"
    networks:
      - strapi-net
  nginx:
    image: nginx:alpine
    depends_on:
      - strapi
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - strapi-net
volumes:
  pgdata:
networks:
  strapi-net:
    driver: bridge
```

### Example `nginx.conf`
```nginx
events {}
http {
  server {
    listen 80;
    server_name _;
    location / {
      proxy_pass http://strapi:1337;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
}
```

---

# TASK 4 - Automated Strapi + PostgreSQL Deployment on EC2 with Terraform and Docker

## Overview
This task upgrades the local Docker Compose setup to a fully automated deployment of Strapi and PostgreSQL on AWS EC2 using Terraform and Docker. The process includes building and pushing a Docker image, launching an EC2 instance, installing Docker, pulling the image, and running both containers on a user-defined Docker network—all automated via Terraform.

## Steps
1. **Build and push your Strapi Docker image:**
```sh
   docker build -t tohidazure/strapi-app:latest ./strapi-app
   docker push tohidazure/strapi-app:latest
   ```
2. **Configure Terraform variables in `terraform/terraform.tfvars`:**
   ```hcl
   aws_region    = "ap-south-1"
   ami_id        = "ami-0a7cf821b91bcccbc"   # Ubuntu 22.04 LTS in ap-south-1
   instance_type = "t2.micro"
   key_name      = "your-ec2-key-name"
   ```
3. **Review `terraform/main.tf` for the following user_data script:**
```hcl
user_data = <<-EOF
  #!/bin/bash
  apt update -y
  apt install -y docker.io
  systemctl start docker
  systemctl enable docker
     docker network create strapi-net
     docker run -d --name postgres --network strapi-net \
       -e POSTGRES_DB=strapi \
       -e POSTGRES_USER=strapi \
       -e POSTGRES_PASSWORD=strapi \
       -v /srv/pgdata:/var/lib/postgresql/data \
       postgres:15
     docker pull tohidazure/strapi-app:latest
     docker run -d --name strapi --network strapi-net \
       -e DATABASE_CLIENT=postgres \
       -e DATABASE_HOST=postgres \
       -e DATABASE_PORT=5432 \
       -e DATABASE_NAME=strapi \
       -e DATABASE_USERNAME=strapi \
       -e DATABASE_PASSWORD=strapi \
       -e APP_KEYS=... \
       -e API_TOKEN_SALT=... \
       -e ADMIN_JWT_SECRET=... \
       -p 1337:1337 \
       tohidazure/strapi-app:latest
EOF
```
4. **Deploy with Terraform:**
    ```sh
    cd terraform
    terraform init
    terraform apply
    ```
5. **Access Strapi:**
   - After deployment, go to `http://<ec2-public-ip>:1337/admin`

---

# Notes
- For production, use strong, unique secrets and secure your database.
- You can adapt this setup for cloud deployment, CI/CD, or managed databases.
- All steps are automated for easy reproducibility and team onboarding.

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
- You can further automate verification by adding a `curl` step to the CD workflow to check the Strapi endpoint after deployment. 

---

# TASK 6 – Strapi on AWS ECS Fargate (Serverless, Managed, Scalable)

This task shows how to deploy Strapi on AWS using ECS Fargate, ECR, and an Application Load Balancer, all managed by Terraform. This is a fully managed, production-ready, and scalable approach—no EC2 instances to manage!

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
   - VPC, public/private subnets, IGW, route tables
   - ECS Cluster, Task Definition (using your ECR image)
   - Fargate Service
   - Security Groups for ALB and ECS tasks
   - Application Load Balancer (ALB)

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

--- 