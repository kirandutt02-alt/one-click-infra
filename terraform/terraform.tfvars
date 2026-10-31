aws_region   = "ap-south-1"
project_name = "postgres-infra-tool"

vpc_cidr      = "10.2.0.0/16"
subnet_a_cidr = "10.2.1.0/24"
subnet_b_cidr = "10.2.2.0/24"

instance_type = "t3.micro"

key_name = "keypair-01"

ssh_allowed_cidr = "YOUR.PUBLIC.IP.ADDRESS/32"

postgres_database = "postgresdb"
postgres_username = "postgres"
postgres_password = "CHANGE-THIS-PASSWORD"