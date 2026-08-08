variable "aws_region" {
  description = "Regiao AWS usada pelo projeto."
  type        = string
  default     = "sa-east-1"
}

variable "state_bucket_name" {
  description = "Nome globalmente unico do bucket S3 para o state remoto do Terraform."
  type        = string
  default     = "unifor-terraform-state-trabalho-final"
}

variable "force_destroy_state_bucket" {
  description = "Permite que o Terraform remova o bucket de state e todas as versoes de objetos na limpeza final."
  type        = bool
  default     = true
}
