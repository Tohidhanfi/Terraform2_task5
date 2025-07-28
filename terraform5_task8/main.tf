terraform {
  backend "s3" {
    bucket         = "strapi-tf-s3"
    key            = "terraform5_task8/terraform.tfstate"
    region         = "us-east-2"
    use_lockfile   = true
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for ECS service
resource "aws_security_group" "tohid_ecr_sg" {
  name        = "tohid1-sg"
  description = "Allow HTTP/Strapi traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "tohid_alb" {
  name               = "tohid"
  internal           = false
  load_balancer_type = "application"
  subnets = [
    "subnet-0c0bb5df2571165a9", # us-east-2a
    "subnet-0cc2ddb32492bcc41", # us-east-2b
    "subnet-0f768008c6324831f"  # us-east-2c
  ]
  security_groups = [aws_security_group.tohid_ecr_sg.id]
  enable_deletion_protection = false
}



resource "aws_lb_target_group" "tohid_tg" {
  name        = "tohid-tg"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = "1337"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.tohid_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tohid_tg.arn
  }
}

resource "aws_ecs_cluster" "tohid_cluster" {
  name = "tohid-cluster"
}

resource "aws_cloudwatch_log_group" "tohid_strapi" {
  name              = "/ecs/tohid-strapi"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_task_execution_role_tohid1" {
  name = "ecsTaskExecutionRole-tohid1"

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
  role       = aws_iam_role.ecs_task_execution_role_tohid1.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "tohid_task" {
  family                   = "tohid-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_tohid1.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role_tohid1.arn

  container_definitions = jsonencode([
    {
      name      = "strapi"
      image     = var.ecr_image_url
      essential = true
      portMappings = [
        {
          containerPort = 1337
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/tohid-strapi",
          awslogs-region        = "us-east-2",
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

        # Strapi secrets
        { name = "APP_KEYS", value = "468cnhT7DiBFuGxUXVh8tA==,0ijw28sTuKb2Xi2luHX6zQ==,TfN3QRc00kFU3Qtg320QNg==,hHRI+D6KWZ0g5PER1WanWw==" },
        { name = "API_TOKEN_SALT", value = "PmzN60QIfFJBz4tGtWWrDg==" },
        { name = "ADMIN_JWT_SECRET", value = "YBeqRecVoyQg7PJGSLv1hg==" },
        { name = "TRANSFER_TOKEN_SALT", value = "eHnkCSXpzUWOmXQBmb0GgQ==" },
        { name = "ENCRYPTION_KEY", value = "MjiUdTqauYmpqsW3wIlnzg==" }
      ]
    }
  ])
}

resource "aws_ecs_service" "tohid_service" {
  name            = "tohid-service-v2"
  cluster         = aws_ecs_cluster.tohid_cluster.id
  task_definition = aws_ecs_task_definition.tohid_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  force_new_deployment = true

  network_configuration {
    subnets         = [
      "subnet-0c0bb5df2571165a9", # us-east-2a
      "subnet-0cc2ddb32492bcc41", # us-east-2b
      "subnet-0f768008c6324831f"  # us-east-2c
    ]
    security_groups = [aws_security_group.tohid_ecr_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tohid_tg.arn
    container_name   = "strapi"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.http]
}