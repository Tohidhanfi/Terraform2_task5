aws_region     = "us-east-2"
ami_id         = "ami-0d1b5a8c13042c939"     # Example: Amazon Linux 2 AMI in us-east-2
instance_type  = "t2.micro"
key_name       = "strapi-tohid"    # Your actual EC2 key pair name

dockerhub_username = "your-dockerhub-username"  # Your Docker Hub username
image_tag          = "latest"                    # Will be overridden by workflow
