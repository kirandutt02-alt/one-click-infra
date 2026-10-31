variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH to the app EC2 (the Jenkins server IP)"
  type        = string
}
