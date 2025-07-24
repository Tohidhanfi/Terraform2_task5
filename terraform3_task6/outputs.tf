output "alb_dns_name" {
  description = "Public URL to access Strapi via the Application Load Balancer"
  value       = aws_lb.alb.dns_name
} 