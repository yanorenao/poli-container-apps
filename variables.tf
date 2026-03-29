variable "environment" {
  description = "El ambiente de despliegue (ej. dev, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "La región de Azure para hospedar los recursos"
  type        = string
  default     = "East US 2"
}

variable "db_admin_user" {
  description = "Nombre de usuario administrador para PostgreSQL"
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  description = "Contraseña para PostgreSQL (Debe ser inyectada vía pipeline, no hardcodeada)"
  type        = string
  sensitive   = true
}

variable "pg_version" {
  description = "Versión de PostgreSQL"
  type        = string
  default     = "15"
}

variable "api_image_tag" {
  description = "Etiqueta (tag) de la imagen del contenedor de API"
  type        = string
  default     = "v1.0.0"
}
