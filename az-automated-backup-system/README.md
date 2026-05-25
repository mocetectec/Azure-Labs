# Automated Backup System

Many small businesses still rely on manual backups: someone occasionally copies files to an external drive and hopes nothing gets missed. That approach fails in predictable ways. People get busy, go on vacation, forget, or assume someone else handled it. When data is eventually lost, there may be no reliable way to recover it.

This project replaces that fragile manual process with an automated cloud backup system built on Azure. Files are stored in geo-redundant Azure Blob Storage, previous versions are preserved, older data is moved to lower-cost storage tiers automatically, and the business owner receives a daily confirmation email showing that the backup process is active.

The result is a backup workflow that reduces human error, improves recoverability, controls storage cost, and provides visibility into whether backups are still running as expected.

🎥 **Video walkthrough:**

## Architecture Overview

This lab simulates a complete small-business backup workflow using Azure Blob Storage, lifecycle management, monitoring, and workflow automation.

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

The `variables.tf` file defines the input variables used during deployment.

These variables include:

- Deploying user's name
- Azure region
- Alert email address
- Resource tags

This keeps the configuration reusable across different users, environments, and Azure regions.

### `main.tf`

The `main.tf` file contains the primary Terraform configuration for the backup system.

It creates the Azure resources required for storage, monitoring, automation, and alerting:

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

### `outputs.tf`

The `outputs.tf` file displays useful values after `terraform apply` completes.

Outputs include:

- Storage account name
- Storage account connection string
- Log Analytics Workspace ID
- Logic App access endpoint

These outputs make it easier to complete portal-based configuration, connect the Logic App to the storage account, and validate the deployment.

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
    - Service: Office 365 Outlook
    - Action: Send an email (V2)

8. Configure the email action: 
    - Subject: Daily Backup Confirmation — @{formatDateTime(utcNow(), 'yyyy-MM-dd')}
    - Body: Backup system status: Active. Files in documents container: @{length(body('List_blobs')?['value'])}. All backup containers are protected and healthy.

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
