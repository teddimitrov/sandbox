variable "environment" {
  type        = string
  description = "Type of environment"
}

variable "location" {
  type        = string
  description = "location of resources"
  default     = "Southcentral US"

}
variable "admin_username" {
  type        = string
  description = "VM Admin username"
}

variable "admin_password" {
  type        = string
  description = "VM Admin password"
}

variable "resource_id" {
  type        = string
  description = "Identifying label for the resource"
}
variable "project_name" {
  type        = string
  description = "Identifying value for the specific project"
}

variable "app_name" {
  type        = string
  description = "Name of appllication"

}
variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)

}