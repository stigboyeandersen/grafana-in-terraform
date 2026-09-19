variable "location" {
  description = "Azure region to deploy the Grafana workspace and supporting resources into."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the resource group that will contain the Grafana workspace."
  type        = string
  default     = "rg-grafana-selfmonitor"
}

variable "grafana_name_prefix" {
  description = "Prefix used to build a globally-unique Azure Managed Grafana instance name."
  type        = string
  default     = "grafana-selfmon"
}

variable "grafana_sku_size" {
  description = "SKU size for Azure Managed Grafana. X1 is the smallest/cheapest option."
  type        = string
  default     = "X1"

  validation {
    condition     = contains(["X1", "X2"], var.grafana_sku_size)
    error_message = "grafana_sku_size must be either X1 or X2."
  }
}

variable "grafana_major_version" {
  description = "Major version of Grafana to deploy."
  type        = number
  default     = 12
}

variable "grafana_admin_object_id" {
  description = "Entra ID (Azure AD) object ID of the user that should be granted the 'Grafana Admin' role on the workspace, e.g. your own signed-in `az cli` identity."
  type        = string
  default     = "8e353f2b-6a24-4ef7-9232-16088b563ef3"
}

variable "alert_email" {
  description = "Email address that receives notifications when a critical alert fires."
  type        = string
  default     = "stigboyeandersen@gmail.com"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    project = "grafana-in-terraform"
    purpose = "demo"
  }
}
