output "public_ip" {
  description = "Public IP of the EC2 instance"
  value = aws_instance.strapi_ec2_tohid.public_ip
}
