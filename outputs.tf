output "alb_url" {
  description = "URL pública do Application Load Balancer."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ec2_instance_id" {
  description = "ID da instância EC2."
  value       = aws_instance.web.id
}

output "rds_endpoint" {
  description = "Endpoint privado do banco RDS."
  value       = aws_db_instance.mysql.address
}
