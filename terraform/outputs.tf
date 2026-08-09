output "instance_id" {
  description = "ID da instancia EC2."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "IP publico usado pelo inventario do Ansible."
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "DNS publico da instancia EC2."
  value       = aws_instance.web.public_dns
}

output "public_url" {
  description = "URL HTTP da pagina publicada no NGINX."
  value       = "http://${aws_instance.web.public_ip}"
}

output "ssh_user" {
  description = "Usuario SSH padrao da AMI Ubuntu."
  value       = var.ssh_user
}
