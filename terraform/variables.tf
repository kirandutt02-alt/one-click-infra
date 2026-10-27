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

variable "subnet_cidr" {
  type    = string
  default = "10.2.1.0/24"
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

variable "postgres_allowed_cidr" {
  description = "Trusted client CIDR allowed to access PostgreSQL"
  type        = string
  default     = "127.0.0.1/32"
}