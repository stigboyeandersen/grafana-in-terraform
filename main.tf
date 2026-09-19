data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Azure Managed Grafana workspace with a system-assigned managed identity.
# The identity is used by the built-in "Azure Monitor" data source to query
# metrics/logs, including the metrics emitted by this Grafana instance itself.
resource "azurerm_dashboard_grafana" "this" {
  name                          = "${var.grafana_name_prefix}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  grafana_major_version         = var.grafana_major_version
  sku                           = "Standard"
  sku_size                      = var.grafana_sku_size
  api_key_enabled               = false
  public_network_access_enabled = true
  zone_redundancy_enabled       = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Let the signed-in user administer the Grafana workspace (log in, manage
# dashboards, data sources, etc.) via Entra ID authentication.
resource "azurerm_role_assignment" "grafana_admin_self" {
  scope                = azurerm_dashboard_grafana.this.id
  role_definition_name = "Grafana Admin"
  principal_id         = var.grafana_admin_object_id
}

# Grant the Grafana workspace's managed identity read access to monitoring
# data in the resource group so it can query its own platform metrics.
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

# Azure Resource Graph requires read access to the subscriptions whose
# resources are included in the topology dashboard.
resource "azurerm_role_assignment" "grafana_resource_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_dashboard_grafana.this.identity[0].principal_id
}

# RBAC role assignments can take a short while to propagate through Entra ID.
# Give them time to become effective before Terraform tries to authenticate
# against the Grafana HTTP API using the newly granted permissions.
resource "time_sleep" "rbac_propagation" {
  depends_on = [
    azurerm_role_assignment.grafana_admin_self,
    azurerm_role_assignment.grafana_monitoring_reader,
    azurerm_role_assignment.grafana_resource_reader,
  ]

  create_duration = "90s"
}
