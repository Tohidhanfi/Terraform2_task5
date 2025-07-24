output "strapi_url" {
  description = "Public URL to access Strapi"
  value       = "http://${aws_lb.tohid_alb.dns_name}"
}


output "rds_endpoint" {
  value = aws_db_instance.tohid_rds.endpoint
}