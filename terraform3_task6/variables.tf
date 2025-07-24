variable "aws_region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "us-east-2"
}

variable "strapi_environment" {
  description = "Map of environment variables for the Strapi container. Example for PostgreSQL: { DATABASE_CLIENT = \"postgres\", DATABASE_HOST = \"<rds-endpoint>\", DATABASE_PORT = \"5432\", DATABASE_NAME = \"strapi\", DATABASE_USERNAME = \"strapi\", DATABASE_PASSWORD = \"password\", APP_KEYS = \"...\", ADMIN_JWT_SECRET = \"...\" }"
  type        = map(string)
  default     = {}
} 