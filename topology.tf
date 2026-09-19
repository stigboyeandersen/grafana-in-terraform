resource "grafana_dashboard" "azure_topology" {
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
    refresh              = "5m"
    schemaVersion        = 42
    tags                 = ["azure", "topology", "terraform"]
    templating           = { list = [] }
    timepicker           = {}
    timezone             = "browser"
    title                = "Azure Resource Topology"
    weekStart            = ""
    time = {
      from = "now-6h"
      to   = "now"
    }
    panels = [
      {
        id      = 1
        title   = "Azure Resource Topology"
        type    = "nodeGraph"
        gridPos = { h = 18, w = 24, x = 0, y = 0 }
        datasource = {
          type = "grafana-azure-monitor-datasource"
          uid  = data.grafana_data_source.azure_monitor.uid
        }
        options = {
          nodes = {
            mainStatUnit         = "short"
            secondaryStatUnit    = "short"
            arcs                 = []
            detail__field__id    = ""
            detail__field__title = ""
          }
          edges = {
            mainStatUnit      = "short"
            secondaryStatUnit = "short"
          }
          legend = {
            asTable     = false
            calcs       = []
            displayMode = "list"
            placement   = "bottom"
            showLegend  = true
          }
        }
        targets = [
          {
            refId         = "Nodes"
            queryType     = "Azure Resource Graph"
            subscriptions = [data.azurerm_subscription.current.subscription_id]
            azureResourceGraph = {
              scope        = "subscription"
              resultFormat = "table"
              query        = <<-KQL
                ResourceContainers
                | where type =~ 'microsoft.resources/subscriptions/resourcegroups'
                | project id=tolower(id), title=name, subtitle='Resource Group'
                | union (
                    Resources
                    | project id=tolower(id), title=name, subtitle=type
                  )
                | order by title asc
              KQL
            }
          },
          {
            refId         = "Edges"
            queryType     = "Azure Resource Graph"
            subscriptions = [data.azurerm_subscription.current.subscription_id]
            azureResourceGraph = {
              scope        = "subscription"
              resultFormat = "table"
              query        = <<-KQL
                Resources
                | extend source=tolower(id),
                    target=tolower(strcat('/subscriptions/', subscriptionId, '/resourceGroups/', resourceGroup))
                | project id=strcat('edge-', tolower(id)), source, target, title=type
                | order by title asc
              KQL
            }
          }
        ]
      },
      {
        id      = 2
        title   = "Azure Resources"
        type    = "table"
        gridPos = { h = 12, w = 24, x = 0, y = 18 }
        datasource = {
          type = "grafana-azure-monitor-datasource"
          uid  = data.grafana_data_source.azure_monitor.uid
        }
        targets = [
          {
            refId         = "A"
            queryType     = "Azure Resource Graph"
            subscriptions = [data.azurerm_subscription.current.subscription_id]
            azureResourceGraph = {
              scope        = "subscription"
              resultFormat = "table"
              query        = <<-KQL
                Resources
                | project name, type, resourceGroup, location, subscriptionId, id
                | order by resourceGroup asc, type asc, name asc
              KQL
            }
          }
        ]
      }
    ]
  })

  depends_on = [time_sleep.rbac_propagation]
}
