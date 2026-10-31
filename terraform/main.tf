module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidr = var.private_subnet_cidr
}

module "security_group" {
  source = "./modules/security-group"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

# Generated DB password. Alphanumeric only so it is safe in shell, SQL and env files.
resource "random_password" "db" {
  length  = 20
  special = false
}

# Database server: private subnet, no public IP. Postgres is installed by Ansible.
module "db" {
  source = "./modules/ec2"

  project_name        = var.project_name
  name                = "db"
  subnet_id           = module.vpc.private_subnet_id
  security_group_id   = module.security_group.db_sg_id
  instance_type       = var.instance_type
  key_name            = var.key_name
  associate_public_ip = false
}

# App server: public subnet. Flask app is installed through user_data.
module "app" {
  source = "./modules/ec2"

  project_name        = var.project_name
  name                = "app"
  subnet_id           = module.vpc.public_subnet_ids[0]
  security_group_id   = module.security_group.app_sg_id
  instance_type       = var.instance_type
  key_name            = var.key_name
  associate_public_ip = true

  user_data = templatefile("${path.module}/templates/app_user_data.sh.tpl", {
    db_host      = module.db.private_ip
    db_name      = var.db_name
    db_user      = var.db_user
    db_password  = random_password.db.result
    app_py_b64   = filebase64("${path.module}/../app/app.py")
    index_b64    = filebase64("${path.module}/../app/index.html")
  })
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_group.alb_sg_id
  app_instance_id   = module.app.instance_id
}
