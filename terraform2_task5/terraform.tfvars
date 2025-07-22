aws_region     = "us-east-2"
ami_id         = "ami-0c02fb55956c7d316"     # Example: Amazon Linux 2 AMI in us-east-2
instance_type  = "t2.micro"
key_name       = "strapi"    # Your actual EC2 key pair name
ecr_registry   = "607700977843.dkr.ecr.us-east-2.amazonaws.com"  # Your AWS Account ECR registry URI
ecr_repository = "strapi-app-tohid"          # Your ECR repository name
image_tag      = "latest"                     # Or your current image tag from GitHub Actions
