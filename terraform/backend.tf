terraform {
  backend "s3" {
    key          = "trabalho-final/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
