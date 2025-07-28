# CloudWatch Dashboard for Strapi ECS Monitoring
resource "aws_cloudwatch_dashboard" "strapi_dashboard" {
  dashboard_name = "Strapi-ECS-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.tohid_service.name, "ClusterName", aws_ecs_cluster.tohid_cluster.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-2"
          title  = "ECS CPU & Memory Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ServiceName", aws_ecs_service.tohid_service.name, "ClusterName", aws_ecs_cluster.tohid_cluster.name],
            [".", "PendingTaskCount", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-2"
          title  = "ECS Task Count"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "NetworkRxBytes", "ServiceName", aws_ecs_service.tohid_service.name, "ClusterName", aws_ecs_cluster.tohid_cluster.name],
            [".", "NetworkTxBytes", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-2"
          title  = "ECS Network Traffic"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.tohid_alb.arn_suffix, "TargetGroup", aws_lb_target_group.tohid_tg.arn_suffix],
            [".", "RequestCount", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-2"
          title  = "ALB Response Time & Request Count"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.tohid_alb.arn_suffix, "TargetGroup", aws_lb_target_group.tohid_tg.arn_suffix],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-2"
          title  = "ALB HTTP Status Codes"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.tohid_rds.id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-2"
          title  = "RDS Metrics"
        }
      }
    ]
  })
}

# CloudWatch Alarms

# High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "strapi-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.tohid_service.name
    ClusterName = aws_ecs_cluster.tohid_cluster.name
  }
}

# High Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "strapi-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.tohid_service.name
    ClusterName = aws_ecs_cluster.tohid_cluster.name
  }
}

# Task Count Alarm (Service Down)
resource "aws_cloudwatch_metric_alarm" "ecs_task_count" {
  alarm_name          = "strapi-ecs-task-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ECS running task count"
  alarm_actions       = []

  dimensions = {
    ServiceName = aws_ecs_service.tohid_service.name
    ClusterName = aws_ecs_cluster.tohid_cluster.name
  }
}

# ALB Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "strapi-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.tohid_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.tohid_tg.arn_suffix
  }
}

# ALB 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "strapi-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5XX error count"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.tohid_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.tohid_tg.arn_suffix
  }
}

# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "strapi-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.tohid_rds.id
  }
}

# RDS Connection Count Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "strapi-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.tohid_rds.id
  }
}

# Custom Metric for Application Health Check
resource "aws_cloudwatch_metric_alarm" "application_health" {
  alarm_name          = "strapi-application-health"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors application health check"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.tohid_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.tohid_tg.arn_suffix
  }
} 