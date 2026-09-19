# grafana-in-terraform

Terraform that provisions an Azure Managed Grafana instance, a self-monitoring
dashboard, and one Grafana-native alert rule.

Terraform does not prevent editing dashboards in Grafana. Make and test changes
in Grafana when convenient, then move the final configuration back into
Terraform so it is preserved for disaster recovery. AI can help compare the
live Grafana configuration with the Terraform files and apply the changes.

## What gets created

- **Resource group** (`rg-grafana-selfmonitor`) containing everything below.
- **Azure Managed Grafana** workspace (`azurerm_dashboard_grafana`), Standard
  SKU / X1 size, with a system-assigned managed identity and Entra ID
  authentication (no API keys).
- **RBAC role assignments**:
  - Your signed-in user gets the `Grafana Admin` role on the workspace so you
    can log in.
  - The workspace's managed identity gets `Monitoring Reader` on the resource
    group, so its built-in "Azure Monitor" data source can query metrics —
    including the workspace's own platform metrics.
- **Self-monitoring dashboard** (via the `grafana` Terraform provider): a
  single panel plotting the Grafana instance's memory usage, HTTP request
  count, and network bytes received, sourced from Azure Monitor.
- **Grafana Alerting** (native Grafana-managed alerting, provisioned via the
  `grafana` Terraform provider), routed to an email contact point:
  - High memory usage (> 85% for 15 min) — `severity: critical`.

  The rule queries the built-in Azure Monitor data source directly and lives in
  the "Grafana Self-Monitoring Alerts" folder.
## Usage

```sh
az login
terraform init
terraform plan
terraform apply
```

After editing Grafana, run `terraform plan` before applying Terraform changes.
This helps detect drift and prevents an older Terraform definition from
overwriting newer Grafana changes.

Notable variables (see `variables.tf`): `location`, `alert_email`,
`grafana_admin_object_id`, `grafana_sku_size`.

> Note: dashboard/alert authentication uses a short-lived Entra ID bearer
> token fetched via `az account get-access-token` at apply time, gated by a
> 90s `time_sleep` after the RBAC role assignments are created to allow for
> permission propagation. If the dashboard/alerting steps ever fail on a fresh
> workspace because RBAC hasn't propagated yet, simply re-run `terraform apply`.