
output "openwebui_url" {
  description = "DNS público del ALB"
  value       = aws_lb.openwebui_alb.dns_name
}
