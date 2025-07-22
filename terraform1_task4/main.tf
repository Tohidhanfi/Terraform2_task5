provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "strapi_sg" {
  name        = "strapi-app-sg"
  description = "Allow SSH and Strapi"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1337
    to_port     = 1337
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

resource "aws_instance" "strapi" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.strapi_sg.id]

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
      -e APP_KEYS=468cnhT7DiBFuGxUXVh8tA==,0ijw28sTuKb2Xi2luHX6zQ==,TfN3QRc00kFU3Qtg320QNg==,hHRI+D6KWZ0g5PER1WanWw== \
      -e API_TOKEN_SALT=PmzN60QIfFJBz4tGtWWrDg== \
      -e ADMIN_JWT_SECRET=YBeqRecVoyQg7PJGSLv1hg== \
      -p 1337:1337 \
      tohidazure/strapi-app:latest
  EOF

  tags = {
    Name = "strapi-ec2"
  }
} 