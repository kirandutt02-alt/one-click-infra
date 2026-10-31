output "app_a_id" {
  value = aws_instance.app_a.id
}

output "app_b_id" {
  value = aws_instance.app_b.id
}

output "app_a_public_ip" {
  value = aws_instance.app_a.public_ip
}

output "app_b_public_ip" {
  value = aws_instance.app_b.public_ip
}

output "postgres_a_id" {
  value = aws_instance.postgres_a.id
}

output "postgres_b_id" {
  value = aws_instance.postgres_b.id
}

output "postgres_a_private_ip" {
  value = aws_instance.postgres_a.private_ip
}

output "postgres_b_private_ip" {
  value = aws_instance.postgres_b.private_ip
}