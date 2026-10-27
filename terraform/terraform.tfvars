aws_region    = "ap-south-1"
project_name  = "postgres-infra-tool"
instance_type = "t3.micro"

key_name = "your-existing-key-pair"

# Replace with your trusted public IP
ssh_allowed_cidr = "0.0.0.0/0"

# Keep restricted until PostgreSQL access is required
postgres_allowed_cidr = "0.0.0.0/0"