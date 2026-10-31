variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the public subnets (one per AZ, at least two for the ALB)"
  type        = list(string)
}

variable "private_subnet_cidr" {
  description = "CIDR for the private database subnet"
  type        = string
}
