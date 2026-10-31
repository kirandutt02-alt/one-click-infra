output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "app_a_public_ip" {
  description = "Application Server A public IP"
  value       = module.ec2.app_a_public_ip
}

output "app_b_public_ip" {
  description = "Application Server B public IP"
  value       = module.ec2.app_b_public_ip
}

output "postgres_a_private_ip" {
  description = "PostgreSQL Server A private IP"
  value       = module.ec2.postgres_a_private_ip
}

output "postgres_b_private_ip" {
  description = "PostgreSQL Server B private IP"
  value       = module.ec2.postgres_b_private_ip
}