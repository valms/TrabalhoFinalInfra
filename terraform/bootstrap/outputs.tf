output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "ssm_transfer_bucket" {
  value = aws_s3_bucket.ssm_transfer.id
}
