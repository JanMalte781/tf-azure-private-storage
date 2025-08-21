variable "project_name" {
  description = "name of the project"
  type        = string
  default     = "tf-azure-private-storage"
}

variable "location" {
  description = "azure region"
  type        = string
  default     = "germanywestcentral"
}

variable "admin_username" {
  default = "azureuser"
}

variable "admin_password" {
  description = "Password for Windows VM"
  type        = string
  sensitive   = true
}

variable "myIP" {
  description = "eigene IP Adresse"
  type        = string
}