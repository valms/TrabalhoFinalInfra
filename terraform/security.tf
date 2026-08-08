resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Permite HTTP publico e SSH restrito para o trabalho final"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidr_blocks)

  security_group_id = aws_security_group.web.id
  description       = "SSH"
  cidr_ipv4         = each.value
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "http_ipv4" {
  security_group_id = aws_security_group.web.id
  description       = "Saida HTTP para atualizacao de pacotes"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "https_ipv4" {
  security_group_id = aws_security_group.web.id
  description       = "Saida HTTPS para atualizacao de pacotes"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
