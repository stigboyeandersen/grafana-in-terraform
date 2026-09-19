# --- Grafana provider authentication ----------------------------------------
# Azure Managed Grafana (with API keys disabled) is authenticated via Entra ID
# bearer tokens. We mint one for the identity running `terraform apply` (the
# same `az cli` login used for the azurerm provider) against the well-known
# Azure Managed Grafana first-party application ID, and use it to configure
# dashboards through the Grafana HTTP API.
data "external" "grafana_token" {
  program = ["bash", "-c", <<-EOT
    set -euo pipefail
    token=$(az account get-access-token --resource=ce34e7e5-485f-4d76-964f-b3d2b16d1e4f --query accessToken -o tsv)
    printf '{"token":"%s"}' "$token"
  EOT
  ]

  depends_on = [time_sleep.rbac_propagation]
}

provider "grafana" {
  url  = azurerm_dashboard_grafana.this.endpoint
  auth = data.external.grafana_token.result.token
}

# Azure Managed Grafana automatically provisions a built-in "Azure Monitor"
# data source backed by the workspace's managed identity.
data "grafana_data_source" "azure_monitor" {
  name = "Azure Monitor"

  depends_on = [time_sleep.rbac_propagation]
}

# A basic self-monitoring dashboard: memory usage, HTTP request volume and
# network throughput of the Grafana instance itself.
resource "grafana_dashboard" "self_monitoring" {
  config_json = jsonencode({
    annotations = {
      list = [
        {
          builtIn = 1
          datasource = {
            type = "grafana"
            uid  = "-- Grafana --"
          }
          enable    = true
          hide      = true
          iconColor = "rgba(0, 211, 255, 1)"
          name      = "Annotations & Alerts"
          type      = "dashboard"
        }
      ]
    }
    editable             = true
    fiscalYearStartMonth = 0
    graphTooltip         = 0
    links                = []
    preload              = false
    refresh              = ""
    schemaVersion        = 42
    tags                 = ["self-monitoring", "terraform"]
    templating           = { list = [] }
    timepicker           = {}
    timezone             = "browser"
    title                = "Grafana Self-Monitoring"
    weekStart            = ""
    time = {
      from = "now-6h"
      to   = "now"
    }
    panels = [
      {
        id      = 1
        title   = "Grafana Instance Health"
        type    = "timeseries"
        gridPos = { h = 9, w = 24, x = 0, y = 0 }
        datasource = {
          type = "grafana-azure-monitor-datasource"
          uid  = data.grafana_data_source.azure_monitor.uid
        }
        fieldConfig = {
          defaults = {
            color = {
              mode = "palette-classic"
            }
            custom = {
              axisBorderShow   = false
              axisCenteredZero = false
              axisColorMode    = "text"
              axisLabel        = ""
              axisPlacement    = "auto"
              barAlignment     = 0
              barWidthFactor   = 0.6
              drawStyle        = "line"
              fillOpacity      = 0
              gradientMode     = "none"
              hideFrom = {
                legend  = false
                tooltip = false
                viz     = false
              }
              insertNulls       = false
              lineInterpolation = "linear"
              lineWidth         = 1
              pointSize         = 5
              scaleDistribution = {
                type = "linear"
              }
              showPoints = "auto"
              showValues = false
              spanNulls  = false
              stacking = {
                group = "A"
                mode  = "none"
              }
              thresholdsStyle = {
                mode = "off"
              }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                {
                  color = "green"
                  value = 0
                },
                {
                  color = "red"
                  value = 80
                }
              ]
            }
            unit = "short"
          }
          overrides = []
        }
        options = {
          legend = {
            calcs       = []
            displayMode = "table"
            placement   = "right"
            showLegend  = true
          }
          tooltip = {
            hideZeros = false
            mode      = "single"
            sort      = "none"
          }
        }
        targets = [
          {
            refId        = "A"
            queryType    = "Azure Monitor"
            subscription = data.azurerm_subscription.current.subscription_id
            azureMonitor = {
              metricNamespace = "Microsoft.Dashboard/grafana"
              metricName      = "MemoryUsagePercentage"
              aggregation     = "Average"
              timeGrain       = "auto"
              alias           = "Memory usage (%)"
              resources = [
                {
                  resourceGroup = azurerm_resource_group.this.name
                  resourceName  = azurerm_dashboard_grafana.this.name
                }
              ]
            }
          },
          {
            refId        = "B"
            queryType    = "Azure Monitor"
            subscription = data.azurerm_subscription.current.subscription_id
            azureMonitor = {
              metricNamespace = "Microsoft.Dashboard/grafana"
              metricName      = "HttpRequestCount"
              aggregation     = "Total"
              timeGrain       = "auto"
              alias           = "HTTP requests"
              resources = [
                {
                  resourceGroup = azurerm_resource_group.this.name
                  resourceName  = azurerm_dashboard_grafana.this.name
                }
              ]
            }
          },
          {
            refId        = "C"
            queryType    = "Azure Monitor"
            subscription = data.azurerm_subscription.current.subscription_id
            azureMonitor = {
              metricNamespace = "Microsoft.Dashboard/grafana"
              metricName      = "NetworkBytesReceived"
              aggregation     = "Total"
              timeGrain       = "auto"
              alias           = "Network bytes received"
              resources = [
                {
                  resourceGroup = azurerm_resource_group.this.name
                  resourceName  = azurerm_dashboard_grafana.this.name
                }
              ]
            }
          }
        ]
      }
    ]
  })
}
