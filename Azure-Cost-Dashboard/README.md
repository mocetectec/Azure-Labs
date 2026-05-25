
# Azure Cost Visibility Dashboard

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Logic Apps](https://img.shields.io/badge/Logic_Apps-0066FF?style=flat&logo=microsoftazure&logoColor=white)

> **Terraform · Azure Monitor · Logic Apps · Azure Workbooks**

🎥 **Video walkthrough:** [Azure Cost Visibilty Dashboard](https://www.loom.com/share/658499abaccd4dee9ae81cfef5c155fa)
---

## Project Overview

Cloud bills are easy to rack up and hard to explain. Most small businesses move to the cloud expecting to save money - then the first invoice arrives, packed with line items like `Microsoft.Compute/virtualMachines - $340` that no one in the business can read, predict, or justify to anyone else.

This project tackles that problem directly. I built a cost visibility and alerting system that monitors Azure spend, sends automatic notifications when budget thresholds are reached, and surfaces everything in a dashboard that actually makes sense to a business owner - not just an engineer.

---

## Business Problem

Once multiple services, resource groups, and usage categories are involved, Azure billing data becomes difficult for non-technical stakeholders to interpret. This project addresses that by creating a simple, automated system that monitors subscription-level spend and puts the right information in front of the right people before the bill becomes a problem.

What it provides:

- Monthly budget monitoring at the subscription level
- Automated alerting at $50, $100, and $200 spend thresholds
- Email notifications delivered through Azure Monitor Action Groups
- Logic App-based alert processing via webhook
- A parameterized Workbook dashboard for viewing resources by subscription and resource group
- A repeatable Infrastructure as Code deployment using Terraform

## Architecture Flow

The system is event-driven. Azure Cost Management evaluates subscription spend against the monthly budget. When actual costs cross a defined threshold, it fires an event to an Action Group - a reusable notification hub that knows who to contact and how. The Action Group triggers a Logic App, which formats the alert into a readable email and delivers it to the right inbox. Everything that happens between the budget breach and the email landing is automated.

<p align="center">
  <img width="850" height="750" alt="azcostdashboard(1)" src="https://github.com/user-attachments/assets/5a22c616-374e-465a-a1ba-f84a5dd93da3" />
</p>


All supporting infrastructure - the Log Analytics workspace, diagnostic settings, and Workbook dashboard - runs alongside this flow to give the full picture of where spend is going and why.

---


## Tools and Services Used

| Service | Purpose |
|---|---|
| Azure Resource Group | Organizes all project resources |
| Azure Cost Management Budget | Tracks and monitors monthly subscription spend |
| Azure Monitor Action Group | Routes alert notifications to defined targets |
| Azure Logic Apps | Receives alert webhook payloads and sends formatted email notifications |
| Log Analytics Workspace | Stores activity and diagnostic logs |
| Azure Workbooks | Displays a parameterized cost visibility dashboard |
| Terraform | Deploys all core Azure resources as code |
| Azure CLI | Used for post-deploy configuration and validation |

---

## What Gets Built

```
rg-cost-dashboard-[yourname]
├── Azure Monitor Action Group     → sends email when alert fires
├── Azure Consumption Budget       → watches spend at $50 / $100 / $200 thresholds
├── Log Analytics Workspace        → stores diagnostic and activity data
├── Logic Apps Workflow            → triggered by alert, formats and sends email
└── Azure Workbook                 → parameterized spending dashboard in the portal
```

---

## Terraform Configuration

### `variables.tf`

Defines input variables for the deploying user's name, Azure region, alert email address, and resource tags - the only values that need to change between environments.

### `main.tf`

The main Terraform file deploys the Azure infrastructure required for the cost visibility system.

It creates:

- Resource group
- Log Analytics Workspace
- Azure Monitor Action Group
- Azure Consumption Budget
- Logic App workflow container
- Subscription diagnostic settings

#### Budget with tiered alert thresholds

The consumption budget is scoped at the subscription level and resets monthly - matching how Azure bills. Each `notification` block defines an independent threshold that fires against the same Action Group.

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

The budget amount is set to `$200`.

The alert thresholds are based on percentages of that budget:

| Threshold | Percentage | Dollar Amount |
|---|---:|---:|
| First alert | 25% | $50 |
| Second alert | 50% | $100 |
| Final alert | 100% | $200 |


#### Action Group - reusable notification target

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

#### Diagnostic settings - feeding Log Analytics

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

### `outputs.tf`

The outputs file prints useful values to the terminal after `terraform apply` completes.

Outputs include:

- Resource group name
- Log Analytics Workspace ID
- Logic App access endpoint
- Action Group ID

These values make the portal configuration and post-deployment validation easier.

---

## Deploy It Yourself

### Prerequisites

Before deploying, install and configure:

- Terraform
- Azure CLI
- An active Azure subscription
- Sufficient permissions to create budgets, resource groups, monitoring resources, and Logic Apps

---

### 1. Configure Variables

Update `terraform.tfvars`:

```hcl
yourname    = "yourname"
location    = "East US"
alert_email = "your.email@example.com"
```

Update the `start_date` in `main.tf` to the first day of the current or a future month:

```hcl
start_date = "2026-05-01T00:00:00Z"
```

---

### 2. Authenticate to Azure

```bash
az login
az account set --subscription "<subscription-name-or-id>"
az account show
```

---

### 3. Deploy with Terraform

```bash
terraform init
terraform plan
terraform apply
```

When prompted, enter:

```text
yes
```

## Logic App Configuration

Terraform deployed the Logic App container. The workflow was configured in the Azure Portal using the visual designer.

The Logic App uses:

1. **Trigger** - When an HTTP request is received
2. **Action** - Send an email notification via Office 365 Outlook

After saving the workflow, Azure generated a callback URL for the HTTP trigger. That URL was then registered as a Logic App receiver on the Azure Monitor Action Group, completing the alert pipeline.

<img width="650" height="500" alt="image" src="https://github.com/user-attachments/assets/1071880c-6a0d-47be-8895-6f3976c7a97b" />

---

## Testing and Validation

### Action Group test

The email receiver was validated directly from the Azure Portal:

```
Azure Monitor → Alerts → Action groups → Select action group → Test
```

The test confirmed email alerts were firing successfully to the configured address.

### Logic App test

The Logic App was validated by checking run history:

```
Logic App → Runs history
```

<img width="1674" height="555" alt="image" src="https://github.com/user-attachments/assets/64881bf4-33af-4714-b3a6-61b3e36c0265" />

A successful run entry confirmed the Action Group was able to trigger the Logic App and the full alert pipeline was working end to end.

---

### Cost Data Test

Because the subscription initially had no cost data, a public IP resource was deployed to generate a small amount of billable usage. This confirmed that cost data was flowing into the Workbook and that the alerting thresholds had real spend to evaluate against.

--- 

## Building the Cost Dashboard in Azure Workbooks

Azure Workbooks was used to create the visual reporting layer for the project. The goal of the workbook is to give a quick view of Azure cost and resource data without requiring users to dig through raw billing exports or Cost Management screens.

The workbook provides visibility into:

- Resources grouped by subscription and resource group
- Month-to-date cost by resource group
- Month-to-date cost by Azure service
- Cost trends once Azure Cost Management begins ingesting usage data

---

### 1. Create a New Workbook

In the Azure Portal:

```text
Azure Portal → Monitor → Workbooks → + New
```

Start with a blank workbook, then remove any default sample content if Azure adds it automatically.

---

### 2. Add a Resource Group Inventory Query

The first workbook section uses Azure Resource Graph to show which resource groups exist in the subscription.

Configure the query:

| Setting | Value |
|---|---|
| Data source | Azure Resource Graph |
| Resource type | Subscriptions |
| Visualization | Grid |

Query:

```kusto
resourcecontainers
| where type == "microsoft.resources/subscriptions/resourcegroups"
| project resourceGroup, location
| order by resourceGroup asc
```

This confirms the workbook can query Azure Resource Graph and gives a simple inventory view of the resource groups being monitored.

---

### 3. Add a Resource Inventory Query

To show the resources deployed across the subscription, add another Azure Resource Graph query.

Query:

```kusto
resources
| project name, type, resourceGroup, location
| order by resourceGroup asc, type asc, name asc
```

This makes it easy to see what resources exist, where they are deployed, and which resource group they belong to.

---

### 4. Add Cost by Resource Group

The original lab suggested using **Add metric** and selecting **Cost Management** as the resource type. In practice, Cost Management was not available in the Metrics picker. Instead, I queried the Cost Management API directly using the **Azure Resource Manager** data source.

Configure the query:

| Setting | Value |
|---|---|
| Data source | Azure Resource Manager |
| Method | POST |
| Path | `/subscriptions/<subscription-id>/providers/Microsoft.CostManagement/query?api-version=2023-11-01` |

Request body:

```json
{
  "type": "Usage",
  "timeframe": "MonthToDate",
  "dataset": {
    "granularity": "None",
    "aggregation": {
      "totalCost": {
        "name": "PreTaxCost",
        "function": "Sum"
      }
    },
    "grouping": [
      {
        "type": "Dimension",
        "name": "ResourceGroup"
      }
    ]
  }
}
```

Column mappings:

| Column ID | Column JSON Path | Type |
|---|---|---|
| `ResourceGroup` | `$.properties.rows[0][1]` | string |
| `Cost` | `$.properties.rows[0][0]` | long |
| `Currency` | `$.properties.rows[0][2]` | string |

The Cost Management API returns row data as nested arrays, so I used **Result Settings → JSON Path** to reshape the response.

Result settings:

| Setting | Value |
|---|---|
| Result Format | JSON Path |
| JSON Path Table | `$` |

Expected output:

| ResourceGroup | Cost | Currency |
|---|---:|---|
| rg-cost-dashboard-[name] | 0.034727644936907 | USD |

---

### 5. Add Cost by Service

A second Azure Resource Manager query was added to show month-to-date cost grouped by Azure service. Same path and method as above, with grouping changed to ServiceName:

Request body:

```json
{
  "type": "Usage",
  "timeframe": "MonthToDate",
  "dataset": {
    "granularity": "None",
    "aggregation": {
      "totalCost": {
        "name": "PreTaxCost",
        "function": "Sum"
      }
    },
    "grouping": [
      {
        "type": "Dimension",
        "name": "ServiceName"
      }
    ]
  }
}
```

Example response data:

| Service | Cost | Currency |
|---|---:|---|
| Azure Monitor | 0 | USD |
| Logic Apps | 0.00060748671591288 | USD |
| Virtual Network | 0.0438652777777778 | USD |

This helped confirm that the public IP test resource was generating networking-related cost data under **Virtual Network**.

<img width="3291" height="1589" alt="image" src="https://github.com/user-attachments/assets/57505344-32d0-4928-bf2a-1282a337ef73" />

---

### Considerations

- Cost Management data is not real-time — new usage can take several hours to appear in dashboards and trigger alerts
- Very small charges may display as $0.00 if the Workbook visualization rounds values
- The Cost Management API returns grouped rows as arrays, which required JSON Path mapping in the Workbook
- The Logic App callback URL contains a sensitive sig parameter and should never be committed to source control or shared publicly — if exposed, regenerate the trigger URL immediately and update the Action Group receiver
- Azure Resource Manager queries are a reliable alternative when Cost Management is not available through the standard Metrics picker

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `BudgetStartDateInvalid` | Start date must be the first of the current or a future month | Update `start_date` in `main.tf` |
| `AuthorizationFailed` on budget | Missing Cost Management Contributor role | `az role assignment create --role "Cost Management Contributor" --assignee <your-email> --scope /subscriptions/<sub-id>` |
| Cost Management not available as metric type in Workbooks | Billing data does not appear through the Azure Monitor Metrics picker in this workbook experience | Use the Azure Resource Manager data source to query the Cost Management API directly |
| Alert email not received | Thresholds require actual spend to cross the limit | Manually trigger a test action from the Action Group in the portal |

---

## Skills Demonstrated

- Azure cost monitoring and budget alerting
- Azure Monitor Action Group configuration
- Logic App webhook integration
- Terraform-based Infrastructure as Code
- Azure CLI troubleshooting
- Azure Workbook dashboard creation
- Cost Management API querying
- Log Analytics and diagnostic settings
- Cloud governance and FinOps fundamentals

---

## Final Outcome

This project produced a working Azure cost visibility and alerting solution. The system monitors subscription-level spend, sends email alerts when cost thresholds are reached, triggers a Logic App workflow from an Azure Monitor Action Group, and displays cost data through an Azure Workbook dashboard.

The result is a practical FinOps-focused Azure project that demonstrates cloud cost monitoring, automation, reporting, and business-focused cloud governance.

---

## Teardown

To remove the deployed infrastructure:

```bash
terraform destroy
```

Type `yes` when prompted. This deletes all Terraform-managed resources including the resource group, budget, Logic App, and Log Analytics Workspace.

---

<i>Part of my Azure cloud portfolio. Follow along as I build and document real-world cloud solutions.</i>
