variable "name_prefix" {
  type        = string
  default     = "fa"
  description = "Prefix for all resources. Will be added to everything. 2-4 chars"
}

variable "app_insights_workspace_id" {
  type        = string
  description = "If you have a workspace for application insights, this is the place for a resource id. Otherwise one will be created for you."
  default     = null
}

variable "location" {
  type        = string
  description = "Location for all resources"
  default     = "norwayeast"
}

variable "app_name" {
  type        = string
  description = "Name for your function app. Will be used to name all other resources also."
  default     = "demoapp"
}

variable "os_type" {
  type        = string
  description = "OS type for you function app."
  default     = "Windows"
}

variable "sku_name" {
  type        = string
  description = "SKU name for your app service plan. Defaults to consumption plan Y1. Skus can be found here: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan#sku_name"
  default     = "Y1"
}
