terraform {
  backend "s3" {
    bucket       = "unifor-terraform-state-trabalho-final"
    key          = "trabalho-final/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
