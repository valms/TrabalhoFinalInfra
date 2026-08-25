output "instance_id" {
  description = "ID da instancia EC2."
  value       = aws_instance.web.id
}

output "public_url" {
  description = "URL HTTP do aplicativo publicado via NGINX."
  value       = "http://${aws_instance.web.public_ip}"
}
