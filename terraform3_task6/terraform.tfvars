aws_region = "us-east-2"

strapi_environment = {
  DATABASE_CLIENT   = "postgres"
  DATABASE_HOST     = "strapi-db.xxxxxxxx.us-east-2.rds.amazonaws.com" # Replace with your actual RDS endpoint (without :5432)
  DATABASE_PORT     = "5432"
  DATABASE_NAME     = "strapi"
  DATABASE_USERNAME = "strapi"
  DATABASE_PASSWORD = "changeme123" # Use your actual RDS password
  APP_KEYS          = "your-app-key1,your-app-key2,your-app-key3,your-app-key4"
  ADMIN_JWT_SECRET  = "your-admin-jwt-secret"
  API_TOKEN_SALT    = "your-api-token-salt"
  # Add any other Strapi environment variables you need
}
