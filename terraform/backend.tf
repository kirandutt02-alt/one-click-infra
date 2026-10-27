terraform {
  backend "s3" {
    bucket       = "postgres-infra"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}