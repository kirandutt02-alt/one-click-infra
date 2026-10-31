module "vpc" {
  source = "./modules/vpc"

  project_name  = var.project_name
  vpc_cidr      = var.vpc_cidr
  subnet_a_cidr = var.subnet_a_cidr
  subnet_b_cidr = var.subnet_b_cidr
}

module "security_group" {
  source = "./modules/security-group"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "ec2" {
  source = "./modules/ec2"

  project_name = var.project_name

  subnet_a_id = module.vpc.subnet_a_id
  subnet_b_id = module.vpc.subnet_b_id

  app_security_group_id      = module.security_group.app_security_group_id
  database_security_group_id = module.security_group.database_security_group_id

  instance_type = var.instance_type
  key_name      = var.key_name
}

module "alb" {
  source = "./modules/alb"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id

  subnet_ids = [
    module.vpc.subnet_a_id,
    module.vpc.subnet_b_id
  ]

  alb_security_group_id = module.security_group.alb_security_group_id

  app_a_id = module.ec2.app_a_id
  app_b_id = module.ec2.app_b_id
}