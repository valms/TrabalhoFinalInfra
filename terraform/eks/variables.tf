variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "environment" {
  type    = string
  default = "demo"
}

variable "kubernetes_version" {
  type = string
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "availability_zones" {
  description = "Duas zonas existentes na conta, fixadas para evitar mudanças inesperadas na VPC."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && var.availability_zones[0] != var.availability_zones[1]
    error_message = "Informe duas zonas de disponibilidade distintas."
  }
}

variable "allowed_api_cidrs" {
  type = list(string)
  validation {
    condition     = length(var.allowed_api_cidrs) > 0 && alltrue([for cidr in var.allowed_api_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"])
    error_message = "Specify restricted IPv4 CIDRs for EKS API access."
  }
}
