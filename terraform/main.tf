module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  subnet_cidr  = var.subnet_cidr
}

module "security_group" {
  source = "./modules/security-group"

  project_name          = var.project_name
  vpc_id                = module.vpc.vpc_id
  ssh_allowed_cidr      = var.ssh_allowed_cidr
  postgres_allowed_cidr = var.postgres_allowed_cidr
}

module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  subnet_id         = module.vpc.subnet_id
  security_group_id = module.security_group.security_group_id
  instance_type     = var.instance_type
  key_name          = var.key_name
}