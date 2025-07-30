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

This task shows how to deploy Strapi on AWS using ECS Fargate, ECR, and an Application Load Balancer, all managed by Terraform.

## Prerequisites
- AWS account with permissions for ECR, ECS, VPC, ALB, and IAM
- AWS CLI, Docker, and Terraform installed locally
- Strapi Dockerfile ready (see `strapi-app/Dockerfile`)

## 1. Build & Push Docker Image to ECR
1. Authenticate Docker to ECR:
   ```sh
   aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 607700977843.dkr.ecr.us-east-2.amazonaws.com
   ```
2. Build and tag your image:
   ```sh
   docker build -t strapi-app-tohid ../strapi-app
   docker tag strapi-app-tohid:latest 607700977843.dkr.ecr.us-east-2.amazonaws.com/strapi-app-tohid:latest
   ```
3. Push the image:
   ```sh
   docker push 607700977843.dkr.ecr.us-east-2.amazonaws.com/strapi-app-tohid:latest
   ```

## 2. Set the ECR Image URL in terraform.tfvars
```hcl
ecr_image_url = "607700977843.dkr.ecr.us-east-2.amazonaws.com/strapi-app-tohid:latest"
```

## 3. Deploy Infrastructure with Terraform
```sh
cd terraform3_task6
terraform init
terraform apply
```
- This will provision all AWS resources and output the ALB DNS and RDS endpoint.

## 4. Access Strapi
- Open the ALB DNS name in your browser.

## Notes
- For production, restrict security groups and set RDS to not be publicly accessible.
- Update environment variables and secrets as needed in your ECS task definition or `terraform.tfvars`. 

---

# TASK 7 – Automated CI/CD Deployment to ECS Fargate with GitHub Actions

This task automates the build, tagging, and deployment of your Strapi Docker image to AWS ECS Fargate using GitHub Actions (CI/CD). No manual Docker or ECR steps are needed after initial setup.

## Prerequisites
- AWS account with permissions for ECR, ECS, VPC, ALB, and IAM
- AWS CLI, Docker, and Terraform installed locally (for initial setup)
- Strapi Dockerfile ready (see `strapi-app/Dockerfile`)
- ECR repository created by Terraform
- GitHub repository with the following secrets configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `ECR_REGISTRY` (e.g., `607700977843.dkr.ecr.us-east-2.amazonaws.com`)
  - `ECR_REPOSITORY` (e.g., `strapi-app-tohid`)

## 1. Initial Setup (One Time, Locally)
- Run `terraform apply` in `terraform4_task7/` to provision AWS resources (including ECR repo, ECS, RDS, ALB, etc.).

## 2. CI/CD Workflow (Automated)
- On every push to `main` (or on demand), GitHub Actions will:
  1. **Build the Docker image** from your Strapi app.
  2. **Tag the image** (e.g., with the commit SHA).
  3. **Push the image** to ECR.
  4. **Update the ECS service** to use the new image by running `terraform apply` (or by updating the ECS task definition directly).

## 3. Example GitHub Actions Workflow
Create a file at `.github/workflows/task7-cicd.yaml`:

```yaml
name: Deploy Strapi to ECS Fargate

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    env:
      AWS_REGION: us-east-2
      ECR_REPOSITORY: strapi-app-tohid
      ECR_REGISTRY: 607700977843.dkr.ecr.us-east-2.amazonaws.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Log in to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push Docker image
        run: |
          IMAGE_TAG=${{ github.sha }}
          docker build -t $ECR_REPOSITORY:$IMAGE_TAG ./strapi-app
          docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        env:
          ECR_REGISTRY: ${{ env.ECR_REGISTRY }}
          ECR_REPOSITORY: ${{ env.ECR_REPOSITORY }}

      - name: Set image URL output
        id: image-url
        run: echo "IMAGE_URL=$ECR_REGISTRY/$ECR_REPOSITORY:${{ github.sha }}" >> $GITHUB_ENV

      - name: Terraform Apply (update ECS to use new image)
        run: |
          cd terraform4_task7
          terraform init
          terraform apply -auto-approve -var="ecr_image_url=${{ env.IMAGE_URL }}"
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ env.AWS_REGION }}
```

## 4. Access Strapi
- After the workflow completes, open the ALB DNS name output by Terraform.

## Notes
- For production, restrict security groups and set RDS to not be publicly accessible.
- Update environment variables and secrets as needed in your ECS task definition or `terraform.tfvars`.
- You can trigger the workflow manually or on every push.

---

# TASK 8 – Comprehensive CloudWatch Monitoring for Strapi ECS Application

This task adds comprehensive monitoring and observability to your Strapi ECS Fargate deployment using AWS CloudWatch. It includes real-time dashboards, automated alarms, and detailed metrics collection for ECS, ALB, and RDS components.

## Overview
- **CloudWatch Dashboard**: Real-time monitoring with 6 comprehensive widgets
- **Automated Alarms**: 8 different alarms for proactive issue detection
- **Log Management**: Centralized logging with CloudWatch Log Groups
- **Metrics Collection**: CPU, Memory, Network, Response Time, and Database metrics

## Prerequisites
- Completed Task 7 (ECS Fargate deployment)
- AWS account with CloudWatch permissions
- Terraform installed locally

## 1. Infrastructure Components

### CloudWatch Dashboard
A comprehensive dashboard with 6 widgets monitoring:
- **ECS CPU & Memory Utilization**
- **ECS Task Count** (Running vs Pending)
- **ECS Network Traffic** (In/Out bytes)
- **ALB Response Time & Request Count**
- **ALB HTTP Status Codes** (2XX, 4XX, 5XX)
- **RDS Metrics** (CPU, Connections, Memory)

### CloudWatch Alarms
8 different alarms monitoring:

#### ECS Alarms:
- **High CPU Utilization** (>80% for 2 periods)
- **High Memory Utilization** (>80% for 2 periods)
- **Task Count** (<1 running task for 2 periods)

#### ALB Alarms:
- **Response Time** (>5 seconds for 2 periods)
- **5XX Errors** (>10 errors for 2 periods)
- **Application Health** (no healthy hosts for 3 periods)

#### RDS Alarms:
- **High CPU Utilization** (>80% for 2 periods)
- **High Connection Count** (>80 connections for 2 periods)

## 2. Deployment Steps

### Step 1: Navigate to Task 8 Directory
```sh
cd terraform5_task8
```

### Step 2: Configure Variables
Update `terraform.tfvars` with your ECR image URL:
```hcl
ecr_image_url = "607700977843.dkr.ecr.us-east-2.amazonaws.com/strapi-app-tohid:latest"
```

### Step 3: Deploy Infrastructure
```sh
terraform init
terraform plan
terraform apply
```

### Step 4: Access Monitoring
After deployment, you can access:
- **Strapi Application**: Use the ALB DNS name from outputs
- **CloudWatch Dashboard**: Use the dashboard URL from outputs
- **CloudWatch Logs**: Navigate to `/ecs/tohid-strapi` log group

## 3. Monitoring Features

### Real-time Dashboard
- **Auto-refreshing metrics** every 5 minutes
- **Multi-dimensional monitoring** (ECS, ALB, RDS)
- **Visual performance indicators**
- **Historical data tracking**

### Proactive Alerting
- **Threshold-based alarms** for critical metrics
- **Multi-period evaluation** to reduce false positives
- **Comprehensive coverage** of all infrastructure components

### Log Management
- **Centralized logging** from ECS tasks
- **Structured log streams** with prefixes
- **7-day retention** for cost optimization
- **Real-time log viewing** in CloudWatch console

## 4. Key Benefits

### Performance Monitoring
- **Detect performance bottlenecks** before they affect users
- **Track resource utilization** for cost optimization
- **Monitor application health** in real-time

### Operational Excellence
- **Proactive issue detection** with automated alarms
- **Comprehensive visibility** across all components
- **Historical trend analysis** for capacity planning

### Cost Optimization
- **Resource utilization tracking** to identify over/under-provisioned resources
- **Performance-based scaling** decisions
- **Efficient log retention** policies

## 5. Customization Options

### Alarm Thresholds
You can modify alarm thresholds in `cloudwatch.tf`:
```hcl
threshold = "80"  # Change CPU/Memory threshold
evaluation_periods = "2"  # Adjust sensitivity
```

### Dashboard Layout
Customize dashboard widgets in `cloudwatch.tf`:
```hcl
width  = 12
height = 6
x      = 0
y      = 0
```

### Log Retention
Adjust log retention in `main.tf`:
```hcl
retention_in_days = 7  # Change retention period
```

## 6. Integration with CI/CD

### Automated Monitoring Setup
The CloudWatch monitoring is automatically deployed with your infrastructure, ensuring:
- **Consistent monitoring** across all deployments
- **No manual setup** required for new environments
- **Version-controlled** monitoring configuration

### Monitoring in CI/CD Pipeline
Add monitoring verification to your GitHub Actions workflow:
```yaml
- name: Verify CloudWatch Dashboard
  run: |
    # Add verification steps for monitoring setup
    echo "CloudWatch monitoring deployed successfully"
```

## 7. Troubleshooting

### Common Issues
1. **Alarms not triggering**: Check alarm thresholds and evaluation periods
2. **Missing metrics**: Ensure ECS tasks are running and healthy
3. **Dashboard not loading**: Verify CloudWatch permissions

### Useful Commands
```sh
# Check CloudWatch alarms
aws cloudwatch describe-alarms --alarm-names strapi-ecs-cpu-high

# View log streams
aws logs describe-log-streams --log-group-name /ecs/tohid-strapi

# Get dashboard details
aws cloudwatch get-dashboard --dashboard-name Strapi-ECS-Dashboard
```

## 8. Next Steps

### Advanced Monitoring
- **Custom metrics** for business KPIs
- **SNS notifications** for alarm actions
- **CloudWatch Insights** for advanced log analysis
- **X-Ray tracing** for distributed tracing

### Production Enhancements
- **Multi-region monitoring** for global deployments
- **Cross-account monitoring** for enterprise setups
- **Automated scaling** based on CloudWatch metrics
- **Cost anomaly detection** and alerting

## Notes
- All monitoring components are deployed as Infrastructure as Code
- CloudWatch metrics are automatically collected by AWS
- Alarms can be extended with SNS notifications for email/SMS alerts
- Dashboard provides comprehensive visibility without additional setup
- Monitoring costs are minimal for small to medium workloads

---

# TASK 9 – Cost-Optimized ECS Fargate with Spot Instances

This task optimizes the Strapi ECS Fargate deployment by implementing Fargate Spot instances, providing significant cost savings while maintaining high availability and performance. The deployment includes comprehensive CloudWatch monitoring and uses the same infrastructure as Task 8 but with cost-optimized compute resources.

## Overview
- **Fargate Spot Instances**: Up to 70% cost savings compared to regular Fargate
- **Automatic Task Replacement**: ECS handles Spot interruptions seamlessly
- **Comprehensive Monitoring**: Full CloudWatch dashboard and alarms
- **Production Ready**: Includes RDS, ALB, and security best practices

## Key Benefits

### Cost Optimization
- **70% cost reduction** compared to regular Fargate instances
- **Pay-as-you-use** pricing model
- **No upfront costs** or long-term commitments
- **Automatic scaling** based on demand

### High Availability
- **Automatic task replacement** when Spot instances are interrupted
- **Multi-AZ deployment** across availability zones
- **Load balancer health checks** ensure service continuity
- **Graceful handling** of Spot interruptions

### Production Features
- **Comprehensive monitoring** with CloudWatch dashboards and alarms
- **Centralized logging** with CloudWatch Logs
- **Security groups** and IAM roles for access control
- **RDS PostgreSQL** for persistent data storage

## Prerequisites
- Completed Task 8 (ECS Fargate with monitoring)
- AWS account with permissions for ECS, ECR, VPC, ALB, RDS, and CloudWatch
- Terraform installed locally
- ECR repository with Strapi Docker image

## 1. Infrastructure Components

### ECS Fargate Spot Configuration
- **Capacity Provider Strategy**: Uses `FARGATE_SPOT` with weight 1
- **Task Definition**: Optimized for Spot instances with proper resource allocation
- **Service Configuration**: Automatic task replacement and health monitoring

### Core Infrastructure
- **ECS Cluster**: Managed Fargate cluster
- **Application Load Balancer**: Multi-AZ load balancer with health checks
- **RDS PostgreSQL**: Managed database with automated backups
- **Security Groups**: Network security with proper port configurations
- **IAM Roles**: Least-privilege access for ECS tasks

### Monitoring & Observability
- **CloudWatch Dashboard**: Real-time monitoring with 6 comprehensive widgets
- **Automated Alarms**: 8 different alarms for proactive issue detection
- **Log Management**: Centralized logging with CloudWatch Log Groups
- **Metrics Collection**: CPU, Memory, Network, Response Time, and Database metrics

## 2. Deployment Steps

### Step 1: Navigate to Task 9 Directory
```sh
cd terraform6_task9
```

### Step 2: Configure Variables
Update `terraform.tfvars` with your ECR image URL:
```hcl
ecr_image_url = "607700977843.dkr.ecr.us-east-2.amazonaws.com/strapi-app-tohid:latest"
```

### Step 3: Deploy Infrastructure
```sh
terraform init
terraform plan
terraform apply
```

### Step 4: Access Strapi
After deployment, access your application using the ALB DNS name from the Terraform outputs.

## 3. Fargate Spot Configuration

### ECS Service Configuration
The key difference from regular Fargate is the capacity provider strategy:

```hcl
resource "aws_ecs_service" "tohid_service" {
  name            = "tohid-task9-service"
  cluster         = aws_ecs_cluster.tohid_cluster.id
  task_definition = aws_ecs_task_definition.tohid_task.arn
  desired_count   = 1
  force_new_deployment = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  # ... rest of configuration
}
```

### Task Definition
Optimized for Spot instances with proper resource allocation:

```hcl
resource "aws_ecs_task_definition" "tohid_task" {
  family                   = "tohid-task9"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_tohid.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role_tohid.arn

  # ... container definitions
}
```

## 4. Monitoring Features

### Real-time Dashboard
- **ECS CPU & Memory Utilization**: Monitor resource usage
- **ECS Task Count**: Track running vs pending tasks
- **ECS Network Traffic**: Monitor network performance
- **ALB Response Time & Request Count**: Application performance metrics
- **ALB HTTP Status Codes**: Error rate monitoring
- **RDS Metrics**: Database performance and connections

### Proactive Alerting
- **High CPU/Memory Utilization**: >80% for 2 periods
- **Task Count Monitoring**: <1 running task for 2 periods
- **ALB Response Time**: >5 seconds for 2 periods
- **5XX Error Rate**: >10 errors for 2 periods
- **RDS Performance**: CPU and connection monitoring

## 5. Cost Optimization Strategies

### Spot Instance Best Practices
- **Multi-AZ Deployment**: Reduces Spot interruption impact
- **Health Checks**: Ensures service availability during interruptions
- **Automatic Scaling**: Responds to demand changes
- **Resource Optimization**: Right-sized CPU and memory allocation

### Monitoring for Cost Control
- **Resource Utilization Tracking**: Identify over/under-provisioned resources
- **Performance Metrics**: Optimize based on actual usage patterns
- **Cost Alerts**: Monitor spending and set budget limits
- **Efficiency Analysis**: Regular review of resource allocation

## 6. Handling Spot Interruptions

### Automatic Recovery
- **ECS Service**: Automatically replaces interrupted tasks
- **Load Balancer**: Routes traffic to healthy instances
- **Health Checks**: Ensures only healthy tasks receive traffic
- **Graceful Shutdown**: Proper container shutdown procedures

### Best Practices
- **Stateless Applications**: Design for easy task replacement
- **External Storage**: Use RDS for persistent data
- **Health Endpoints**: Implement proper health check endpoints
- **Logging**: Centralized logging for debugging

## 7. Production Considerations

### Security
- **Security Groups**: Restrict network access to necessary ports
- **IAM Roles**: Least-privilege access for ECS tasks
- **RDS Security**: Database not publicly accessible
- **Encryption**: Data encryption in transit and at rest

### Scalability
- **Auto Scaling**: Configure based on CloudWatch metrics
- **Load Distribution**: Multi-AZ deployment for high availability
- **Resource Planning**: Monitor and adjust resource allocation
- **Performance Tuning**: Optimize based on monitoring data

## 8. Troubleshooting

### Common Issues
1. **Spot Interruptions**: Normal behavior, tasks will be replaced automatically
2. **High Costs**: Check resource allocation and utilization
3. **Performance Issues**: Monitor CloudWatch metrics and adjust resources
4. **Service Unavailability**: Check health checks and security groups

### Useful Commands
```sh
# Check ECS service status
aws ecs describe-services --cluster tohid-task9-cluster --services tohid-task9-service

# View CloudWatch logs
aws logs describe-log-streams --log-group-name /ecs/tohid-task9-strapi

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Monitor Spot instance pricing
aws ec2 describe-spot-price-history --instance-types fargate --product-description "Linux/UNIX"
```

## 9. Integration with CI/CD

### Automated Deployment
- **GitHub Actions**: Automated build and deployment pipeline
- **Terraform**: Infrastructure as Code for consistent deployments
- **ECR**: Container image management and versioning
- **Monitoring**: Automated monitoring setup with each deployment

### Deployment Workflow
1. **Build**: Docker image built and pushed to ECR
2. **Deploy**: Terraform applies infrastructure changes
3. **Monitor**: CloudWatch monitoring automatically configured
4. **Verify**: Health checks confirm successful deployment

## 10. Cost Comparison

### Regular Fargate vs Fargate Spot
| Metric | Regular Fargate | Fargate Spot | Savings |
|--------|----------------|--------------|---------|
| CPU (0.5 vCPU) | ~$0.04048/hour | ~$0.01214/hour | 70% |
| Memory (1GB) | ~$0.00445/hour | ~$0.00134/hour | 70% |
| **Total** | **~$0.04493/hour** | **~$0.01348/hour** | **70%** |

### Monthly Cost Example
- **Regular Fargate**: ~$32.35/month (24/7 usage)
- **Fargate Spot**: ~$9.71/month (24/7 usage)
- **Annual Savings**: ~$271.68/year

## Notes
- Fargate Spot availability varies by region and time
- Tasks may be interrupted when AWS needs capacity back
- ECS automatically replaces interrupted tasks
- Monitor CloudWatch metrics for optimal performance
- Consider using a mix of Spot and On-Demand for critical workloads
- All infrastructure is deployed as Infrastructure as Code
- Comprehensive monitoring ensures operational excellence
- Cost savings can be significant for development and production workloads

---

# TASK 10 – Host and Publish Strapi Project

This task covers the practical steps to host and publish your Strapi project after deployment, including content management, API configuration, and public access setup.

## Overview
- **Content Management**: Create and manage content types, collections, and singles
- **API Configuration**: Set up public access and configure endpoints
- **User Management**: Configure roles and permissions for public access
- **Content Publishing**: Publish content and test APIs
- **Frontend Integration**: Connect frontend applications to Strapi APIs

## Prerequisites
- Completed Task 9 (ECS Fargate Spot deployment)
- Access to the ALB DNS name from Terraform outputs
- Basic understanding of Strapi admin panel

## 1. Access Your Strapi Admin Panel

### Step 1:  Get the ALB DNS Name
```sh
cd terraform6_task9
terraform output
```

Look for the ALB DNS name in the outputs, which will be something like:
`tohid-task9-1234567890.us-east-2.elb.amazonaws.com`

### Step 2: Access Admin Panel
Open your browser and navigate to:
```
http://<alb-dns-name>/admin
```

### Step 3: Create Admin Account
- Fill in the required information:
  - **First Name**: Your first name
  - **Last Name**: Your last name
  - **Email**: Your email address
  - **Password**: Create a strong password
  - **Confirm Password**: Re-enter your password
- Click **"Let's start"**

## 2. Create Content Types

### Collections (Multiple Entries)
1. **Navigate to Content-Types Builder**
   - Go to **Content-Types Builder** in the left sidebar
   - Click **"Create new collection type"**

2. **Create a Blog Post Collection**
   - **Display name**: `Blog Post`
   - **API ID**: `blog-post`
   - Click **"Continue"**

3. **Add Fields**
   - **Title** (Text field):
     - Type: `Text`
     - Name: `title`
     - Required: ✓
   - **Content** (Rich Text field):
     - Type: `Rich text`
     - Name: `content`
     - Required: ✓
   - **Author** (Text field):
     - Type: `Text`
     - Name: `author`
     - Required: ✓
   - **Published Date** (Date field):
     - Type: `Date`
     - Name: `published_date`
     - Required: ✓

4. **Save and Generate API**
   - Click **"Save"**
   - Click **"Generate API"**

### Singles (Single Entries)
1. **Create a Home Page Single**
   - Go to **Content-Types Builder**
   - Click **"Create new single type"**
   - **Display name**: `Home Page`
   - **API ID**: `home-page`
   - Click **"Continue"**

2. **Add Fields**
   - **Hero Title** (Text field):
     - Type: `Text`
     - Name: `hero_title`
     - Required: ✓
   - **Hero Description** (Long Text field):
     - Type: `Long text`
     - Name: `hero_description`
     - Required: ✓
   - **Featured Image** (Media field):
     - Type: `Media`
     - Name: `featured_image`
     - Required: ✗

3. **Save and Generate API**
   - Click **"Save"**
   - Click **"Generate API"**

## 3. Configure Roles & Permissions

### Step 1: Access Users & Permissions
- Go to **Settings** → **Users & Permissions Plugin**

### Step 2: Configure Public Role
1. **Select "Public" role**
2. **Enable permissions for your content types:**
   - **Blog Post**: 
     - ✓ `find`
     - ✓ `findOne`
   - **Home Page**:
     - ✓ `find`
     - ✓ `findOne`

### Step 3: Configure Authenticated Role (Optional)
1. **Select "Authenticated" role**
2. **Enable additional permissions:**
   - **Blog Post**:
     - ✓ `create`
     - ✓ `update`
     - ✓ `delete`
   - **Home Page**:
     - ✓ `update`

### Step 4: Save Permissions
- Click **"Save"** to apply the changes

## 4. Create and Publish Content

### Create Blog Posts
1. **Navigate to Content Manager**
   - Go to **Content Manager** → **Blog Post**
   - Click **"Create new entry"**

2. **Add Content**
   - **Title**: "Welcome to My Strapi Blog"
   - **Content**: Add your blog content using the rich text editor
   - **Author**: "Your Name"
   - **Published Date**: Select today's date

3. **Publish Content**
   - Click **"Save"**
   - Click **"Publish"**

### Create Home Page Content
1. **Navigate to Home Page**
   - Go to **Content Manager** → **Home Page**
   - Click **"Create new entry"**

2. **Add Content**
   - **Hero Title**: "Welcome to My Website"
   - **Hero Description**: "This is a sample description for the home page"
   - **Featured Image**: Upload an image (optional)

3. **Publish Content**
   - Click **"Save"**
   - Click **"Publish"**

## 5. Test Your APIs

### API Endpoints
Your APIs will be available at:
- **Blog Posts**: `http://<alb-dns-name>/api/blog-posts`
- **Single Blog Post**: `http://<alb-dns-name>/api/blog-posts/1`
- **Home Page**: `http://<alb-dns-name>/api/home-page`

### Test with cURL
```bash
# Get all blog posts
curl http://<alb-dns-name>/api/blog-posts

# Get a specific blog post
curl http://<alb-dns-name>/api/blog-posts/1

# Get home page content
curl http://<alb-dns-name>/api/home-page
```

### Test with Browser
- Open your browser and navigate to the API URLs
- You should see JSON responses with your content

## 6. Frontend Integration

### JavaScript/Fetch Example
```javascript
// Fetch all blog posts
fetch('http://<alb-dns-name>/api/blog-posts')
  .then(response => response.json())
  .then(data => {
    console.log('Blog posts:', data);
  });

// Fetch home page content
fetch('http://<alb-dns-name>/api/home-page')
  .then(response => response.json())
  .then(data => {
    console.log('Home page:', data);
  });
```

### React Example
```jsx
import React, { useState, useEffect } from 'react';

function BlogPosts() {
  const [posts, setPosts] = useState([]);

  useEffect(() => {
    fetch('http://<alb-dns-name>/api/blog-posts')
      .then(response => response.json())
      .then(data => setPosts(data.data));
  }, []);

  return (
    <div>
      {posts.map(post => (
        <div key={post.id}>
          <h2>{post.attributes.title}</h2>
          <p>{post.attributes.content}</p>
          <small>By {post.attributes.author}</small>
        </div>
      ))}
    </div>
  );
}
```

## 7. Advanced Configuration

### Custom API Responses
You can customize API responses by modifying the controllers in:
```
src/api/[content-type]/controllers/[content-type].js
```

### API Documentation
- Access API documentation at: `http://<alb-dns-name>/documentation`
- This provides interactive API documentation

### Media Management
- Upload images through the admin panel
- Access media at: `http://<alb-dns-name>/uploads/`

## 8. Security Best Practices

### Environment Variables
Ensure your Strapi secrets are properly configured:
```env
APP_KEYS=your-app-keys
API_TOKEN_SALT=your-api-token-salt
ADMIN_JWT_SECRET=your-admin-jwt-secret
TRANSFER_TOKEN_SALT=your-transfer-token-salt
ENCRYPTION_KEY=your-encryption-key
```

### CORS Configuration
If connecting from a frontend, configure CORS in `config/middlewares.js`:
```javascript
module.exports = {
  settings: {
    cors: {
      enabled: true,
      origin: ['http://localhost:3000', 'https://yourdomain.com']
    }
  }
};
```

## 9. Monitoring and Maintenance

### Check Application Health
- Monitor your application through CloudWatch dashboards
- Check ECS service logs for any issues
- Verify ALB health checks are passing

### Backup Strategy
- RDS provides automated backups
- Consider implementing additional backup strategies for content
- Export content regularly through the admin panel

## 10. Troubleshooting

### Common Issues
1. **Cannot access admin panel**: Check ALB security groups and health checks
2. **API returns 403**: Verify public role permissions
3. **Content not appearing**: Ensure content is published
4. **Media not loading**: Check upload permissions and file sizes

### Useful Commands
```bash
# Check ECS service status
aws ecs describe-services --cluster tohid-task9-cluster --services tohid-task9-service

# View application logs
aws logs describe-log-streams --log-group-name /ecs/tohid-task9-strapi

# Test ALB health
curl -I http://<alb-dns-name>/admin
```

## Notes
- Always test APIs after publishing content
- Monitor application performance through CloudWatch
- Keep your admin credentials secure
- Regularly backup your content and database
- Consider implementing authentication for sensitive operations
- Use HTTPS in production environments
- Implement rate limiting for public APIs
- Monitor API usage and performance metrics