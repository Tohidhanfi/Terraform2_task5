variable "ecr_image_url" {
  description = "Full image URL for ECS task definition"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}