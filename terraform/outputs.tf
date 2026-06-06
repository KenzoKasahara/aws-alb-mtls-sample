output "alb_dns_name" {
  description = "DNS name of the ALB — use this as the test endpoint"
  value       = aws_lb.main.dns_name
}

output "trust_store_arn" {
  description = "ARN of the ALB Trust Store"
  value       = aws_lb_trust_store.mtls.arn
}

output "ec2_instance_id" {
  description = "EC2 instance ID — connect via SSM Session Manager"
  value       = aws_instance.target.id
}
