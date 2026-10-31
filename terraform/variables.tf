variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "postgres-infra-tool"
}

variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "subnet_a_cidr" {
  type    = string
  default = "10.2.1.0/24"
}

variable "subnet_b_cidr" {
  type    = string
  default = "10.2.2.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "Your trusted public IP in CIDR notation"
  type        = string
}

variable "postgres_database" {
  type    = string
  default = "postgresdb"
}

variable "postgres_username" {
  type    = string
  default = "postgres"
}

variable "postgres_password" {
  type      = string
  sensitive = true
}