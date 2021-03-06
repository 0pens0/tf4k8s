variable "resource_group_name" {}

variable "storage_account_name" {}

variable "storage_container_name" {}

variable "az_subscription_id" {
  description = "Azure Subscription (id)"
  type = string
}

variable "az_client_id" {
  description = "Azure Service Principal (appId)"
  type = string
}

variable "az_client_secret" {
  description = "Azure Service Principal (password)"
  type = string
}

variable "az_tenant_id" {
  description = "Azure Service Principal (tenant)"
  type = string
}
