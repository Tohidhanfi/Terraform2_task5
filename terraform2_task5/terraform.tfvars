aws_region     = "us-east-2"
ami_id         = "ami-0c02fb55956c7d316"     # Example: Amazon Linux 2 AMI in us-east-2
instance_type  = "t2.micro"
key_name       = "strapi-tohid"    # Your actual EC2 key pair name

dockerhub_username = "your-dockerhub-username"  # Your Docker Hub username
image_tag          = "latest"                    # Will be overridden by workflow

# Strapi secrets (replace with your actual secure values)
app_keys         = "your-app-keys"
api_token_salt   = "your-api-token-salt"
admin_jwt_secret = "your-admin-jwt-secret"
