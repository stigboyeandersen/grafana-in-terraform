# grafana-in-terraform

Terraform for Azure Managed Grafana with Grafana-managed dashboard and alerting.

## What this config creates

- Azure resource group
- Azure Managed Grafana workspace (Entra ID auth, no API keys)
- RBAC assignments:
  - `Grafana Admin` for `grafana_admin_object_id`
  - `Monitoring Reader` for the workspace managed identity
- Grafana dashboard: **Grafana Self-Monitoring**
- Grafana alerting:
  - Email contact point (`alert_email`)
  - Default notification policy
  - Folder: **Grafana Self-Monitoring Alerts**
  - Rule: **Grafana high memory usage** (>85% for 15m)

## Usage

```sh
az login
terraform init
terraform plan
terraform apply
```

You can update both dashboards and alerts directly in Grafana. After making changes, run `terraform plan` and sync the final versions back to Terraform before `terraform apply`; otherwise an older Terraform definition can overwrite newer Grafana edits.

Key variables: `location`, `alert_email`, `grafana_admin_object_id`, `grafana_sku_size` (`X1` or `X2`).
