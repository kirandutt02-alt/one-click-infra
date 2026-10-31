variable "project_name" {
  type = string
}

variable "name" {
  description = "Role name used in the Name tag, e.g. app or db"
  type        = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "associate_public_ip" {
  type    = bool
  default = false
}

variable "user_data" {
  type    = string
  default = null
}
