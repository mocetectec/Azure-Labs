# Azure Cost Visibility Dashboard

> **Terraform · Azure Monitor · Logic Apps · Azure Workbooks**
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)
---

## Project Overview

This project builds an Azure cost visibility and alerting solution that helps track cloud spend, notify stakeholders when budget thresholds are reached, and present cost data in an Azure Workbook dashboard.

The goal is to solve a common business problem: Azure billing data can be difficult for non-technical stakeholders to interpret. This lab creates a simple system that monitors subscription-level spend, sends alerts, triggers a Logic App workflow, and displays cost information in a dashboard.

## Business Problem

Small businesses often move workloads to the cloud expecting better cost control, but Azure bills can become difficult to interpret once multiple services, resource groups, and usage categories are involved.

This project addresses that problem by providing:

- Monthly Azure budget monitoring
- Automated alerting at defined spend thresholds
- Email notifications through Azure Monitor Action Groups
- Logic App-based alert processing
- A dashboard for viewing spend by service and resource group
- A repeatable Infrastructure as Code deployment using Terraform


## Architecture Flow

The system is event-driven. Azure Monitor watches spend continuously. When actual costs cross a defined threshold, it fires an event to an Action Group — a reusable notification hub that knows who to contact and how. The Action Group triggers a Logic App, which formats the alert into a readable email and delivers it to the right inbox. Everything that happens between the budget breach and the email landing is automated.

All supporting infrastructure — the Log Analytics workspace, diagnostic settings, and Workbook dashboard — runs alongside this flow to give the full picture of where spend is going and why.

![Azure cost management workflow diagram showing a monthly consumption budget and spend threshold alerts flowing through Azure Monitor, an action group, Logic App workflow, and email notification, with supporting Log Analytics and Azure Workbook infrastructure](image.png)
---

## What Gets Built

```
rg-cost-dashboard-[yourname]
├── Azure Monitor Action Group     → sends email when alert fires
├── Azure Consumption Budget       → watches spend at $50 / $100 / $200 thresholds
├── Log Analytics Workspace        → stores diagnostic and activity data
├── Logic Apps Workflow            → triggered by alert, formats and sends email
└── Azure Workbook                 → spending dashboard visible in the portal
```

**6 resources. One `terraform apply`.**

---

## Key Code

### Budget with tiered alert thresholds

The consumption budget is scoped at the subscription level and resets monthly — matching how Azure bills. Each `notification` block defines an independent threshold that fires against the same Action Group.

```hcl
resource "azurerm_consumption_budget_subscription" "main" {
  name            = "budget-cost-${var.yourname}"
  subscription_id = data.azurerm_client_config.current.subscription_id
  amount          = 200
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-05-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 25
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.email_alerts.id]
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.email_alerts.id]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_groups = [azurerm_monitor_action_group.email_alerts.id]
  }
}
```

### Action Group — reusable notification target

Defined once, attached to every alert rule. The `use_common_alert_schema` flag standardizes the email body format across all alert types.

```hcl
resource "azurerm_monitor_action_group" "email_alerts" {
  name                = "ag-cost-alerts-${var.yourname}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "costalerts"

  email_receiver {
    name                    = "owner-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}
```

### Diagnostic settings — feeding Log Analytics

This forwards the subscription's activity log into the Log Analytics workspace. Without it, the workspace has no data to query.

```hcl
resource "azurerm_monitor_diagnostic_setting" "subscription_logs" {
  name                       = "diag-sub-to-law"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "Policy" }
}
```

---
