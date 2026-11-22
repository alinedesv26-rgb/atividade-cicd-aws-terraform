variable "aws_region" {
  description = "Região AWS onde os recursos serão criados."
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Nome usado nos recursos e nas tags."
  type        = string
  default     = "atividade-cicd"
}

variable "environment" {
  description = "Ambiente da implantação."
  type        = string
  default     = "dev"
}

variable "db_username" {
  description = "Usuário administrador do MySQL."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Senha do banco. Defina por TF_VAR_db_password ou variável de ambiente."
  type        = string
  sensitive   = true
  nullable    = false
}
