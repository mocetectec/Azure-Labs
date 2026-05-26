# Automated Backup System
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)

Many small businesses still rely on manual backups: someone occasionally copies files to an external drive and hopes nothing gets missed. That approach fails in predictable ways. People get busy, go on vacation, forget, or assume someone else handled it. When data is eventually lost, there may be no reliable way to recover it.

This project replaces that fragile manual process with an automated cloud backup system built on Azure. Files are stored in geo-redundant Azure Blob Storage, previous versions are preserved, older data is moved to lower-cost storage tiers automatically, and the business owner receives a daily confirmation email showing that the backup process is active.

The result is a backup workflow that reduces human error, improves recoverability, controls storage cost, and provides visibility into whether backups are still running as expected.

## Architecture Overview

The system is split into two layers that work together — a storage and data protection layer on the left, and a monitoring and automation layer on the right.

The storage layer is the foundation. Files land in one of three private containers inside a geo-redundant storage account. The moment a file is uploaded, Azure replicates it asynchronously to a secondary region — East US to West US — so a regional failure doesn't take the backup down with it. Blob versioning runs continuously in the background, preserving every previous version of every file so accidental deletions and overwrites are recoverable. The lifecycle policy handles cost automatically, moving files from Hot to Cool storage after 30 days, to Archive after 90, and deleting them after 365.

The monitoring and automation layer watches the storage account and keeps the business owner informed. Storage diagnostic settings forward read, write, and delete activity into a Log Analytics Workspace, creating a complete audit trail of backup activity. Two things run off the back of that:

- A **Logic App** runs on a daily schedule at 8 AM, checks the documents container, and sends a confirmation email with a live file count — so the business owner knows the system is working without having to log into the portal
- A **Monitor alert rule** watches for zero write transactions over any 24-hour window. If backups stop flowing, the alert fires to the Action Group and an email goes out

The Action Group connects both sides. Whether the alert is triggered by the Monitor rule detecting a write failure or by the Logic App's daily confirmation run, the Action Group handles where the notification goes.

<img width="950" height="650" alt="azbackupsystem" src="https://github.com/user-attachments/assets/9f8b9113-9b3c-45d3-979a-60820e0a7a01" />

### What gets built

```
rg-backup-[yourname]
├── Storage Account (stbackup[yourname]) — GRS · TLS 1.2
│   ├── Container: documents
│   ├── Container: database-exports
│   ├── Container: application-files
│   ├── Blob Versioning — enabled · 30-day soft delete
│   └── Lifecycle Policy — Hot → Cool (30d) → Archive (90d) → Delete (365d)
├── Log Analytics Workspace — 30-day retention
├── Storage Diagnostic Settings — StorageRead · StorageWrite · StorageDelete
├── Logic App Workflow — daily 8 AM confirmation email
├── Monitor Alert Rule — fires if zero writes in 24 hours
└── Monitor Action Group — routes notifications to configured email
```

**11 resources. One `terraform apply`.**

## Core Components

### 1. Backup Storage and Data Protection

Azure Blob Storage serves as the central backup location. The storage account is configured with geo-redundant storage (GRS), which replicates data to a secondary Azure region for additional protection against regional failure.

Blob versioning is enabled so that when a file is overwritten or deleted, previous versions are preserved. This protects against accidental deletion, accidental overwrites, and corrupted files being saved over good copies.

The project uses three private containers to organize backup data:

- `documents`
- `database-exports`
- `application-files`

### 2. Lifecycle Management and Cost Control

A lifecycle management policy automatically moves backup data through lower-cost storage tiers as it ages.

The policy follows this retention pattern:

- Move blobs to the Cool tier after 30 days
- Move blobs to the Archive tier after 90 days
- Delete current blobs after 365 days
- Delete older blob versions after 30 days

This keeps recent backups readily available while reducing the cost of storing older data that is less likely to be accessed.

### 3. Logging and Monitoring

Storage diagnostic settings send read, write, and delete activity to a Log Analytics Workspace. This creates a centralized audit trail for backup activity and makes it possible to monitor whether files are still being written to storage.

An Azure Monitor alert rule checks for a lack of write activity. If no backup writes occur within a 24-hour window, the alert is triggered. This helps detect upstream backup failures before they go unnoticed for days or weeks.

### 4. Automation and Notification

An Azure Logic App provides the daily confirmation workflow. The workflow runs on a schedule, checks the backup container, and sends an email confirmation showing that the backup system is active.

This gives the business owner visibility without requiring them to manually inspect the storage account.

## Terraform Configuration

The infrastructure for this project is defined with Terraform. The configuration is split across separate files to keep variables, resources, and outputs organized.

### `variables.tf`

Defines input variables for the deploying user's name, Azure region, alert email address, and resource tags — the only values that need to change between environments.

### `main.tf`

The `main.tf` file contains the primary Terraform configuration for the backup system. It creates the Azure resources required for storage, monitoring, automation, and alerting:

- Resource group
- Geo-redundant storage account
- Private storage containers
- Blob versioning and retention settings
- Lifecycle management policy
- Log Analytics Workspace
- Storage diagnostic settings
- Azure Monitor Action Group
- Azure Monitor alert rule
- Logic App workflow

#### Storage Account — the foundation of the backup system

The storage account is configured with several settings that make it production-appropriate for backup workloads, not just a default file store.

`account_replication_type = "GRS"` replicates data to a secondary Azure region automatically. If an entire region goes offline, the data still exists in the secondary. For a backup system this is the correct choice — LRS only replicates within a single region and offers no protection against a regional failure.

`min_tls_version = "TLS1_2"` enforces that all connections use TLS 1.2 or higher. Older versions have known vulnerabilities and should not be used for backup data.

`versioning_enabled = true` is what makes this a real backup system rather than just a file store. Every time a file is overwritten or deleted, Azure preserves the previous version. A user who accidentally deletes or corrupts a file does not lose the data permanently.

`delete_retention_policy` with `days = 30` keeps deleted blobs in a soft-deleted state for 30 days before permanently removing them — a safety net on top of versioning.

```hcl
resource "azurerm_storage_account" "backup" {
  name                     = "stbackup${var.yourname}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.tags
}
```

#### Lifecycle Management Policy — automated cost control

This policy is what keeps backup storage costs from growing unbounded over time. Azure has four storage tiers — Hot, Cool, Cold, and Archive — each progressively cheaper to store but more expensive to read. The lifecycle policy moves files through these tiers automatically based on age, without any manual intervention.

The `base_blob` rule applies to the current version of each file. After 30 days without modification it moves to Cool, after 90 days to Archive, and after 365 days it is deleted. The `version` rule applies to older superseded versions — these are retained for 30 days and then permanently removed. Keeping old versions indefinitely would grow costs without limit.

The `prefix_match` filter scopes the policy to all three backup containers.

```hcl
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.backup.id

  rule {
    name    = "backup-lifecycle"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["documents/", "database-exports/", "application-files/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }

      version {
        delete_after_days_since_creation = 30
      }
    }
  }
}
```

| Stage | Trigger | Action |
|---|---|---|
| 30 days since last modification | Base blob | Move to Cool tier |
| 90 days since last modification | Base blob | Move to Archive tier |
| 365 days since last modification | Base blob | Delete permanently |
| 30 days since creation | Older versions | Delete permanently |

#### Monitor Alert Rule — detect when backups stop

This alert fires if the storage account receives zero write transactions in a 24-hour window. If nothing is being written to backup storage, something has gone wrong upstream — and the business owner should know before days go by unnoticed.

`metric_name = "Transactions"` with `operator = "LessThan"` and `threshold = 1` means the alert fires when the write count drops to zero.

The `dimension` filter on `ApiName` with values `PutBlob` and `PutBlock` is a critical detail. Without this filter the alert would evaluate *all* storage transactions — reads, deletes, metadata calls — and would fire any time the account was simply quiet. Scoping it to write operations means the alert only fires when backups specifically have stopped.

```hcl
resource "azurerm_monitor_metric_alert" "no_writes" {
  name                = "alert-no-backup-writes"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_storage_account.backup.id]
  description         = "Fires if no files have been written to backup storage in 24 hours."
  severity            = 2
  frequency           = "PT1H"
  window_size         = "P1D"

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Transactions"
    aggregation      = "Total"
    operator         = "LessThan"
    threshold        = 1

    dimension {
      name     = "ApiName"
      operator = "Include"
      values   = ["PutBlob", "PutBlock"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.backup_alerts.id
  }

  tags = var.tags
}
```

### `outputs.tf`

Prints useful values to the terminal after `terraform apply` completes:

- **Storage account name** — used to reference the account in CLI commands and portal navigation
- **Storage account connection string** — used to connect the Logic App to the storage account; marked `sensitive = true` so Terraform does not print it in plain text
- **Log Analytics Workspace ID** — used to confirm diagnostic settings are pointing to the correct workspace
- **Logic App access endpoint** — used to wire the Logic App into the Action Group after portal configuration

To retrieve the connection string after deploy:

```bash
terraform output -raw storage_account_connection_string
```


## Configure the Logic App (portal)

The Logic App is created by Terraform, but the workflow steps are configured manually in the Azure portal.

1. Navigate to `la-backup-confirm-[yourname]` in the Azure portal.
2. Open **Logic app designer**.
3. Add a trigger and search for **Recurrence**.
4. Configure the recurrence trigger:
   - Frequency: `Day`
   - Interval: `1`
   - At these hours: `8`
5. Add a new step:
   - Service: **Azure Blob Storage**
   - Action: **List blobs**
   - Container: `documents`
6. Connect to the storage account using the Terraform output below:

```bash
terraform output -raw storage_account_connection_string
```
7. Add a new step:
    - Service: **Office 365 Outlook**
    - Action: **Send an email (V2)**

8. Configure the email action: 
    - **Subject**: Daily Backup Confirmation — @{formatDateTime(utcNow(), 'yyyy-MM-dd')}
    - **Body**: Backup system status: Active. Files in documents container: @{length(body('List_blobs')?['value'])}. All backup containers are protected and healthy.

9. Save the workflow.

>Note: The storage account connection string is sensitive. Do not commit it to source control or share it in screenshots.

## Verification and Testing

After running `terraform apply` and configuring the Logic App, validate that the backup system is working as expected.

### Deployment Checks

Confirm the following resources exist in the Azure portal:

- Resource group: `rg-backup-[yourname]`
- Storage account: `stbackup[yourname]`
- Storage containers:
  - `documents`
  - `database-exports`
  - `application-files`
- Log Analytics Workspace
- Storage diagnostic settings
- Logic App workflow
- Azure Monitor alert rule

### Architecture Flow Check

Review the service connections to confirm the intended architecture flow:

- Storage account activity is sent to Log Analytics through diagnostic settings.
- Azure Monitor evaluates storage write activity.
- The alert rule uses the action group to notify the configured email address.
- The Logic App runs on a daily schedule and sends a confirmation email.

### Test Blob Versioning

Upload a test file to the `documents` container, then overwrite it to create a second version.

```bash
echo "Backup test $(date)" > /tmp/backup_test.txt

az storage blob upload \
  --account-name stbackup[yourname] \
  --container-name documents \
  --name test/backup_test.txt \
  --file /tmp/backup_test.txt \
  --auth-mode login


echo "Second version $(date)" > /tmp/backup_test.txt

az storage blob upload \
  --account-name stbackup[yourname] \
  --container-name documents \
  --name test/backup_test.txt \
  --file /tmp/backup_test.txt \
  --auth-mode login \
  --overwrite
```
List the blob versions:

```bash
az storage blob list \
  --account-name stbackup[yourname] \
  --container-name documents \
  --include v \
  --auth-mode login \
  --output table
```

>You should see two rows for test/backup_test.txt: the current version and one previous version.

>If versions are not visible in the Azure portal, open the container view and toggle **Show versions**.

## Troubleshooting

| Issue | Possible Cause | Fix |
|---|---|---|
| `BlobAccessTierNotSupported` | Archive tier may not be available for GRS accounts in some regions | Increase the archive threshold or remove the archive rule |
| Logic App blob connection fails | Storage account connection string was entered incorrectly | Re-run `terraform output -raw storage_account_connection_string` and paste the full connection string |
| Alert fires immediately | No write activity has occurred yet | Upload a test file; the alert evaluates write activity over a 24-hour window |
| Two versions are not visible in the portal | Blob versions may be hidden by default | Open the container view and toggle **Show versions** |

## Skills Demonstrated

- **Azure Blob Storage** — configuring private containers for centralized backup storage
- **GRS vs LRS** — using geo-redundant replication for disaster recovery instead of single-region replication
- **Blob versioning** — preserving file history for recovery from accidental deletion, overwrites, or corruption
- **Storage lifecycle policies** — automating tier movement from Hot to Cool to Archive to control long-term storage costs
- **Azure Logic Apps** — creating a scheduled workflow for daily backup confirmation emails
- **Azure Monitor alerts** — detecting missing backup write activity with metric-based alerting
- **Diagnostic settings** — routing storage logs to Log Analytics for audit trails and monitoring
- **Terraform** — provisioning Azure infrastructure using reusable Infrastructure as Code

## Teardown

To remove all Azure resources created by this project, run:

```bash
terraform destroy
```
