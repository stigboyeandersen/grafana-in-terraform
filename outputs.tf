output "resource_group_name" {
  description = "Name of the resource group containing the Grafana workspace."
  value       = azurerm_resource_group.this.name
}

output "grafana_name" {
  description = "Name of the Azure Managed Grafana instance."
  value       = azurerm_dashboard_grafana.this.name
}

output "grafana_endpoint" {
  description = "URL of the Grafana workspace."
  value       = azurerm_dashboard_grafana.this.endpoint
}

output "grafana_dashboard_url" {
  description = "Direct URL to the self-monitoring dashboard."
  value       = "${azurerm_dashboard_grafana.this.endpoint}/d/${grafana_dashboard.self_monitoring.uid}"
}

output "grafana_alert_folder_url" {
  description = "URL of the folder containing the Grafana-managed self-monitoring alert rules."
  value       = "${azurerm_dashboard_grafana.this.endpoint}/dashboards/f/${grafana_folder.self_monitoring_alerts.uid}"
}
