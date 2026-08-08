output "state_bucket_name" {
  description = "Nome do bucket S3 usado pelo state remoto do Terraform."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_region" {
  description = "Regiao onde o bucket de state do Terraform foi criado."
  value       = var.aws_region
}
