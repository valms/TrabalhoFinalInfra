variable "aws_region" {
  description = "Regiao AWS usada pelo projeto."
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Nome do projeto usado nos nomes dos recursos e tags."
  type        = string
  default     = "unifor-trabalho-final"
}

variable "environment" {
  description = "Valor da tag de ambiente."
  type        = string
  default     = "academic"
}

variable "vpc_cidr_block" {
  description = "Bloco CIDR da VPC do projeto."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "vpc_cidr_block deve ser um CIDR IPv4 valido."
  }
}

variable "public_subnet_cidr_block" {
  description = "Bloco CIDR da subnet publica onde a EC2 sera criada."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr_block))
    error_message = "public_subnet_cidr_block deve ser um CIDR IPv4 valido."
  }
}

variable "instance_type" {
  description = "Tipo da instancia EC2. Mantenha t3.micro/t2.micro para compatibilidade com opcoes Free Tier."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Use t2.micro ou t3.micro para manter o projeto alinhado com opcoes Free Tier."
  }
}

variable "root_volume_size" {
  description = "Tamanho do volume EBS raiz em GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 30
    error_message = "O volume raiz deve ter entre 8 e 30 GiB."
  }
}

variable "key_name" {
  description = "Nome da Key Pair EC2 que sera criada na AWS."
  type        = string
  default     = "unifor-terraform-key"
}

variable "public_key" {
  description = "Conteudo da chave publica SSH usado para criar a Key Pair EC2. Nao use chave privada aqui."
  type        = string
  sensitive   = true

  validation {
    condition     = startswith(var.public_key, "ssh-rsa ") || startswith(var.public_key, "ssh-ed25519 ")
    error_message = "public_key deve ser uma chave publica OpenSSH valida iniciando com ssh-rsa ou ssh-ed25519."
  }
}

variable "allowed_ssh_cidr_blocks" {
  description = "Blocos CIDR permitidos para acesso SSH. Use apenas IPs publicos especificos com /32."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidr_blocks :
      can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"
    ])
    error_message = "allowed_ssh_cidr_blocks deve conter CIDRs IPv4 validos e nao pode liberar SSH para 0.0.0.0/0."
  }
}
