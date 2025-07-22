output "strapi_public_ip" {
  description = "Public IP of the Strapi EC2 instance"
  value       = aws_instance.strapi.public_ip
} 