output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "Open this in a browser to use the app"
  value       = module.alb.alb_dns_name
}

output "app_public_ip" {
  description = "Jump host / app server"
  value       = module.app.public_ip
}

output "db_private_ip" {
  value = module.db.private_ip
}

output "db_name" {
  value = var.db_name
}

output "db_user" {
  value = var.db_user
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
