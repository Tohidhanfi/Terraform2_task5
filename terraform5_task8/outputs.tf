output "strapi_url" {
  description = "Public URL to access Strapi"
  value       = "http://${aws_lb.tohid_alb.dns_name}"
}

output "rds_endpoint" {
  value = aws_db_instance.tohid_rds.endpoint
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=Strapi-Task8-ECS-Dashboard"
}