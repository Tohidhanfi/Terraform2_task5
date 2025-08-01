terraform {
  backend "s3" {
    bucket         = "strapi-tf-s3"
    key            = "terraform8_task11/terraform.tfstate"
    region         = "us-east-2"
    use_lockfile   = true
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-2"
}

# Data sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "selected" {
  count = length(data.aws_subnets.default_vpc_subnets.ids)
  id    = data.aws_subnets.default_vpc_subnets.ids[count.index]
}

locals {
  alb_subnet_ids = distinct([
    for az in distinct([
      for s in data.aws_subnet.selected : s.availability_zone
    ]) : (
      [for s in data.aws_subnet.selected : s if s.availability_zone == az][0].id
    )
  ])
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "tohid-task11-alb-sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tohid-task11-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "tohid-task11-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 1337
    to_port         = 1337
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tohid-task11-ecs-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "tohid_alb" {
  name               = "tohid-task11-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.alb_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "tohid-task11-alb"
  }
}

# Target Groups (Blue and Green)
resource "aws_lb_target_group" "blue" {
  name        = "tohid-task11-blue-tg"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = "1337"
    protocol            = "HTTP"
    matcher             = "200,302"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tohid-task11-blue-tg"
  }
}

resource "aws_lb_target_group" "green" {
  name        = "tohid-task11-green-tg"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = "1337"
    protocol            = "HTTP"
    matcher             = "200,302"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tohid-task11-green-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.tohid_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "tohid_cluster" {
  name = "tohid-task11-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "strapi" {
  name              = "/ecs/tohid-task11-strapi"
  retention_in_days = 7
}

# IAM Roles
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-tohid-task11"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition (Placeholder)
resource "aws_ecs_task_definition" "tohid_task" {
  family                   = "tohid-task11"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "strapi"
      image     = var.ecr_image_url
      essential = true
      portMappings = [
        {
          containerPort = 1337
          hostPort      = 1337
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.strapi.name
          awslogs-region        = "us-east-2"
          awslogs-stream-prefix = "ecs"
        }
      }
      environment = [
        { name = "DATABASE_CLIENT", value = "postgres" },
        { name = "DATABASE_HOST", value = aws_db_instance.tohid_rds.address },
        { name = "DATABASE_PORT", value = "5432" },
        { name = "DATABASE_NAME", value = "strapidb" },
        { name = "DATABASE_USERNAME", value = "tohid" },
        { name = "DATABASE_PASSWORD", value = "tohid123" },
        { name = "DATABASE_SSL", value = "false" },
        { name = "APP_KEYS", value = "468cnhT7DiBFuGxUXVh8tA==,0ijw28sTuKb2Xi2luHX6zQ==,TfN3QRc00kFU3Qtg320QNg==,hHRI+D6KWZ0g5PER1WanWw==" },
        { name = "API_TOKEN_SALT", value = "PmzN60QIfFJBz4tGtWWrDg==" },
        { name = "ADMIN_JWT_SECRET", value = "YBeqRecVoyQg7PJGSLv1hg==" },
        { name = "TRANSFER_TOKEN_SALT", value = "eHnkCSXpzUWOmXQBmb0GgQ==" },
        { name = "ENCRYPTION_KEY", value = "MjiUdTqauYmpqsW3wIlnzg==" },
        { name = "JWT_SECRET", value = "YBeqRecVoyQg7PJGSLv1hg==" },
        { name = "NODE_ENV", value = "production" }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "tohid_service" {
  name            = "tohid-task11-service"
  cluster         = aws_ecs_cluster.tohid_cluster.id
  task_definition = aws_ecs_task_definition.tohid_task.arn_without_revision
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = local.alb_subnet_ids
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "strapi"
    container_port   = 1337
  }

  # CodeDeploy integration
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  depends_on = [aws_lb_listener.main]
}

# CodeDeploy Application
resource "aws_codedeploy_app" "main" {
  name             = "tohid-task11-codedeploy-app"
  compute_platform = "ECS"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "tohid-task11-deployment-group"
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"
  service_role_arn       = aws_iam_role.codedeploy_service_role.arn

  deployment_style {
    deployment_type = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.tohid_cluster.name
    service_name = aws_ecs_service.tohid_service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.main.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  depends_on = [aws_iam_role_policy_attachment.codedeploy_service_role_policy]
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_service_role" {
  name = "CodeDeployServiceRole-tohid-task11"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy_service_role.name
}

# Additional IAM policy for CodeDeploy to access ECS
resource "aws_iam_role_policy" "codedeploy_ecs_policy" {
  name = "CodeDeployECSPolicy"
  role = aws_iam_role.codedeploy_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn
        ]
      }
    ]
  })
}