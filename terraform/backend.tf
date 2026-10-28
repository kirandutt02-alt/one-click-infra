terraform {
  backend "s3" {
    bucket       = "postgres-infra"
    key          = "one-click-infra/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}