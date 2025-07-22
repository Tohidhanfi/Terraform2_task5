variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "app_keys" {
  description = "Strapi APP_KEYS"
  type        = string
}

variable "api_token_salt" {
  description = "Strapi API_TOKEN_SALT"
  type        = string
}

variable "admin_jwt_secret" {
  description = "Strapi ADMIN_JWT_SECRET"
  type        = string
}

variable "dockerhub_username" {
  description = "Docker Hub username"
  type        = string
}
