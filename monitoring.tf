# --- Grafana Alerting: notification target ----------------------------------

resource "grafana_contact_point" "critical" {
  name = "Critical Grafana Alerts"

  email {
    addresses               = [var.alert_email]
    subject                 = "{{ template \"default.title\" . }}"
    message                 = "{{ len .Alerts.Firing }} alert(s) firing on the Grafana instance."
    single_email            = true
    disable_resolve_message = false
  }

  depends_on = [time_sleep.rbac_propagation]
}

# Route every alert (default, unmatched policy) to the email contact point.
resource "grafana_notification_policy" "default" {
  contact_point = grafana_contact_point.critical.name
  group_by      = ["alertname"]

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"
}

resource "grafana_folder" "self_monitoring_alerts" {
  title = "Grafana Self-Monitoring Alerts"

  depends_on = [time_sleep.rbac_propagation]
}

# --- Grafana-managed alert rules on the Grafana workspace itself ------------
# Supported platform metrics for Microsoft.Dashboard/grafana:
# HttpRequestCount, MemoryUsagePercentage, NetworkBytesReceived, NetworkBytesTransmitted
#
# Each rule queries the Azure Monitor data source (query A), reduces the
# series to its most recent value (query B), then compares it against a
# threshold (query C), which is the alert condition.

resource "grafana_rule_group" "self_monitoring" {
  name             = "Grafana Self-Monitoring"
  folder_uid       = grafana_folder.self_monitoring_alerts.uid
  interval_seconds = 300

  rule {
    name           = "Grafana high memory usage"
    for            = "15m"
    condition      = "C"
    no_data_state  = "NoData"
    exec_err_state = "Alerting"

    annotations = {
      summary = "Grafana instance memory usage has exceeded 85% for 15 minutes and may become unresponsive or crash."
    }
    labels = {
      severity = "critical"
    }

    data {
      ref_id         = "A"
      query_type     = "Azure Monitor"
      datasource_uid = data.grafana_data_source.azure_monitor.uid
      relative_time_range {
        from = 900
        to   = 0
      }
      model = jsonencode({
        refId        = "A"
        queryType    = "Azure Monitor"
        subscription = data.azurerm_subscription.current.subscription_id
        azureMonitor = {
          resourceGroup   = azurerm_resource_group.this.name
          resourceName    = azurerm_dashboard_grafana.this.name
          metricNamespace = "Microsoft.Dashboard/grafana"
          metricName      = "MemoryUsagePercentage"
          aggregation     = "Average"
          timeGrain       = "auto"
        }
      })
    }

    data {
      ref_id         = "B"
      query_type     = ""
      datasource_uid = "-100"
      relative_time_range {
        from = 900
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        datasource = {
          type = "__expr__"
          uid  = "-100"
        }
      })
    }

    data {
      ref_id         = "C"
      query_type     = ""
      datasource_uid = "-100"
      relative_time_range {
        from = 900
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        conditions = [
          {
            evaluator = {
              type   = "gt"
              params = [85]
            }
          }
        ]
        datasource = {
          type = "__expr__"
          uid  = "-100"
        }
      })
    }
  }

  rule {
    name           = "Grafana no HTTP traffic"
    for            = "30m"
    condition      = "C"
    no_data_state  = "Alerting"
    exec_err_state = "Alerting"

    annotations = {
      summary = "No HTTP requests have reached the Grafana instance in 30 minutes, which can indicate an outage or connectivity issue."
    }
    labels = {
      severity = "critical"
    }

    data {
      ref_id         = "A"
      query_type     = "Azure Monitor"
      datasource_uid = data.grafana_data_source.azure_monitor.uid
      relative_time_range {
        from = 1800
        to   = 0
      }
      model = jsonencode({
        refId        = "A"
        queryType    = "Azure Monitor"
        subscription = data.azurerm_subscription.current.subscription_id
        azureMonitor = {
          resourceGroup   = azurerm_resource_group.this.name
          resourceName    = azurerm_dashboard_grafana.this.name
          metricNamespace = "Microsoft.Dashboard/grafana"
          metricName      = "HttpRequestCount"
          aggregation     = "Total"
          timeGrain       = "auto"
        }
      })
    }

    data {
      ref_id         = "B"
      query_type     = ""
      datasource_uid = "-100"
      relative_time_range {
        from = 1800
        to   = 0
      }
      model = jsonencode({
        refId      = "B"
        type       = "reduce"
        expression = "A"
        reducer    = "sum"
        datasource = {
          type = "__expr__"
          uid  = "-100"
        }
      })
    }

    data {
      ref_id         = "C"
      query_type     = ""
      datasource_uid = "-100"
      relative_time_range {
        from = 1800
        to   = 0
      }
      model = jsonencode({
        refId      = "C"
        type       = "threshold"
        expression = "B"
        conditions = [
          {
            evaluator = {
              type   = "lte"
              params = [0]
            }
          }
        ]
        datasource = {
          type = "__expr__"
          uid  = "-100"
        }
      })
    }
  }
}
