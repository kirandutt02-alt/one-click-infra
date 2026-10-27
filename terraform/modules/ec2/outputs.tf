output "instance_id" {
  value = aws_instance.postgres.id
}

output "public_ip" {
  value = aws_instance.postgres.public_ip
}