provider "aws" {
  region = var.aws_region
}

variable "image_tag" {
  type = string
}

locals {
  image_url = "${var.ecr_registry}/${var.ecr_repository}:${var.image_tag}"
}

resource "aws_instance" "strapi_ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]

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
    docker pull ${local.image_url}
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
      ${local.image_url}
  EOF
}
