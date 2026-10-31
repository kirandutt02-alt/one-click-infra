aws_region    = "ap-south-1"
project_name  = "postgres-infra-tool"
instance_type = "t3.micro"

key_name = "keypair-01"

# Public IP of the Jenkins server, e.g. "13.233.x.x/32".
# It must be able to SSH to the app EC2 (the jump host to the private DB).
ssh_allowed_cidr = "0.0.0.0/0"


# aws_region   = "ap-south-1"
# project_name = "postgres-infra-tool"

# vpc_cidr      = "10.2.0.0/16"
# subnet_a_cidr = "10.2.1.0/24"
# subnet_b_cidr = "10.2.2.0/24"

# instance_type = "t3.micro"

# key_name = "keypair-01"

# ssh_allowed_cidr = "YOUR.PUBLIC.IP.ADDRESS/32"

# postgres_database = "postgresdb"
# postgres_username = "postgres"
# postgres_password = "CHANGE-THIS-PASSWORD"