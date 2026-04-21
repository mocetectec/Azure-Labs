# Phase 2 - Azure Target Infrastructure

This phase provisions the Azure staging and target environment used by Azure Migrate to assess, replicate, and receive the migrated workload. It builds two resource groups - one for migration staging infrastructure and one for the final migrated VM - along with all supporting services and appliance VMs required for discovery, replication, and cutover.

All infrastructure in this phase is managed with Terraform.

---

## What This Phase Builds

### Staging Resource Group - `rg-migrate-source-[yourname]`
Holds all migration infrastructure. Everything in this resource group is temporary — it exists to support the migration and is destroyed after cutover.

| Resource | Details |
|---|---|
| Virtual Network | 10.1.0.0/16 - target network |
| Subnet | 10.1.1.0/24 - snet-migrate |
| Azure Migrate Project | Created manually in the Azure portal - control plane for discovery, assessment, and replication |
| Storage Account | Standard LRS - replication cache during disk sync |
| Log Analytics Workspace | Stores discovery data and performance metrics |
| Recovery Services Vault | Orchestrates replication via Azure Site Recovery |
| Migration Appliance VM | Windows Server VM used for discovery and Azure Migrate appliance setup |
| Replication Appliance VM | High-capacity VM (D16s_v3, 650GB disk) used for replication processing |
| Network Interfaces | Attached to appliance VMs with public IPs for connectivity |
| Public IPs | Enables access to appliance VMs |
| Network Security Groups | Allow RDP and required inbound traffic for appliance access |

### Target Resource Group - `rg-migrate-target-[yourname]`
Holds the final migrated VM and its supporting resources after cutover. A Network Security Group is pre-created to allow immediate RDP access for post-migration validation.

| Resource | Details |
|---|---|
| Network Security Group | Allows RDP (port 3389) access to the migrated VM |

---
## Prerequisites

- Azure subscription
- Azure CLI installed and authenticated
- Terraform installed
- Phase 1 deployed and EC2 instance running

Verify Azure CLI is authenticated:

```powershell
az account show
```

If not logged in:

```powershell
az login
az account set --subscription "your-subscription-name"
```
> **Note:** If using a free Azure account or a new subscription, you may encounter vCPU quota limits when deploying the replication appliance VM (Standard_D16s_v3). If this occurs, request a quota increase in the Azure portal:
>
> Azure Portal → Subscriptions → Usage + quotas
---

## File Structure

```
phase-2-azure-infrastructure/
├── main.tf                    # All Azure resources
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Resource group, vault, storage outputs
├── terraform.tfvars.example   # Template — copy and fill in your values
└── README.md
```

---

## How to Deploy

This phase deploys both the Azure infrastructure and the appliance VMs required for discovery and replication. Ensure your subscription has sufficient quota before proceeding.

**Step 1 - Copy the example vars file and fill in your values:**

```powershell
copy terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
yourname = "your-name-here"
location = "East US"
appliance_admin_password   = "YourSecureP@ssword123!"
replication_admin_password = "YourSecureP@ssword123!"
```

> Use the same `yourname` value as Phase 1 — it is used to name resources consistently across both environments.

**Step 2 - Initialize Terraform:**

```powershell
terraform init
```

**Step 3 - Review the plan:**

```powershell
terraform plan
```

**Step 4 - Deploy:**

```powershell
terraform apply
```

Deployment takes approximately 5–10 minutes depending on VM provisioning time.

---
## Key Design Decisions

**Why two resource groups?**
Staging and target environments are kept intentionally separate. After cutover, the migration infrastructure - appliances, storage cache, vault replication state - can be destroyed cleanly without touching the migrated VM. This is the ideal pattern for any real-world migration engagement and makes teardown significantly safer.

```
rg-migrate-source  →  migration infrastructure (temporary)
rg-migrate-target  →  migrated VM (permanent)
```
> This separation allows the migration infrastructure to be fully destroyed after cutover while preserving the migrated workload.

**Why 10.1.0.0/16 for the Azure VNet?**
The AWS VPC uses 10.0.0.0/16. Overlapping CIDR ranges between the two environments would cause routing failures if a VPN or peering connection is added later. Using non-overlapping ranges from the start is a standard design requirement for any cross-cloud or hybrid architecture.

**Why Standard LRS for the storage account?**
The storage account is used as a replication cache - a temporary buffer that holds disk data from the EC2 instance before it is committed to Azure managed disks. LRS (Locally Redundant Storage) is sufficient for this purpose. Azure Migrate validates the storage account configuration during replication setup and requires:
- Account tier: Standard
- Account kind: StorageV2
- Replication: LRS

Non-compliant values will cause replication setup to fail.

**Why soft_delete_enabled = false on the Recovery Services Vault?**
By default, Azure protects Recovery Services Vaults from deletion for 14 days. With soft delete enabled, `terraform destroy` will fail on the vault at lab teardown. Disabling it allows clean destruction at the end of the lab. In a production environment, leave soft delete enabled.

**Why a separate NSG in the target resource group?**
The NSG is pre-created in the target resource group so it is ready to attach to the migrated VM immediately after cutover. It opens RDP (port 3389) for post-migration verification. In a real migration, this NSG would be configured to match the source security group rules.

**Why these network security group rules?**
The Network Security Groups (NSGs) are configured to allow only the ports required for appliance access and migration operations.

| Port | Protocol | Purpose | Phase Used |
|------|----------|---------|------------|
| 3389 | TCP | RDP - administrative access to appliance VMs | All phases |
| 443  | TCP | HTTPS - secure communication between Azure services and the replication appliance | Replication |
| 9443 | TCP | Azure Site Recovery replication traffic (Mobility Agent → Process Server) | Replication |

In this implementation, NSGs are intentionally minimal and focused on the ports required to:
- Access the appliance VMs for configuration and validation
- Allow Azure Migrate and Azure Site Recovery to communicate with the replication appliance

> Opening ports to `*` (any source) is acceptable for a short-lived lab environment. In production, restrict access to trusted IP ranges.

**Why custom VM sizes for the migration appliances?**
The original lab sizing was not sufficient in this environment, so the appliance VMs were sized based on actual validation requirements during deployment.

- **Migration Appliance VM:** `Standard_E2s_v3` — sufficient for discovery and appliance setup in this lab.
- **Replication Appliance VM:** `Standard_D16s_v3` with a 650 GB OS disk — required to meet the replication appliance manager validation requirements for CPU and disk capacity.

>In practice, the replication appliance required the equivalent of **8 CPU cores** and at least **600 GB of disk space** to complete setup successfully. This reflects real-world scenarios where lab defaults may need to be adjusted based on platform constraints.
---

## Save Your Outputs

After `terraform apply` completes, save these values - you will need them in Phase 3:

```powershell
terraform output
```

Expected outputs:

```
migrate_project_name          = "migrate-project-[yourname]"
source_resource_group         = "rg-migrate-source-[yourname]"
target_resource_group         = "rg-migrate-target-[yourname]"
replication_storage_account   = "stmigrate[yourname]"
recovery_services_vault       = "rsv-migrate-[yourname]"
target_subnet_id              = "/subscriptions/.../snet-migrate"
vnet_name                     = "vnet-migrate-[yourname]"
appliance_public_ip           = "x.x.x.x"
replication_appliance_public_ip = "x.x.x.x"
```
---
## Verify Deployment

Confirm the Terraform-managed resources in the staging resource group:

```powershell
az resource list --resource-group rg-migrate-source-[yourname] --output table
```
You should see the virtual network, storage account, Log Analytics workspace, Recovery Services Vault, migration appliance VM, replication appliance VM, and associated networking resources. 

Confirm the Azure Migrate project exists in the Azure portal after creating it manually in the portal for Phase 3.

---

## Estimated Cost

| Resource | Estimated Cost |
|---|---|
| Migration Appliance VM (`Standard_E2s_v3`) | Low daily compute cost |
| Replication Appliance VM (`Standard_D16s_v3`) | High daily compute cost |
| Replication VM OS Disk (650 GB Standard_LRS) | Additional daily storage cost |
| Storage Account (replication cache) | Low daily cost |
| Log Analytics Workspace | Low daily cost at lab scale |
| Recovery Services Vault | No hourly cost |

**Cost note:** The replication appliance VM is the primary cost driver in this phase due to its large size (D16s_v3) and 650 GB disk. All other infrastructure components have relatively low cost impact at lab scale.

---

## Teardown

> **Important:** Do not destroy Phase 2 resources until after Phase 4 (cutover) is complete and you have stopped replication in the Azure Migrate portal.

Destroy order matters - Azure resources must be destroyed after AWS:

```powershell
# Stop replication first in the Azure portal
# Azure Migrate → Replicating Machines → Stop Replication

# Then destroy
terraform destroy
```

If `terraform destroy` fails on the Recovery Services Vault with a "vault is not empty" error:

1. Go to Azure portal → Recovery Services Vault → `rsv-migrate-[yourname]`
2. Click **Replication items** → delete all items
3. Click **Backup items** → delete all items
4. Retry `terraform destroy`

Both appliance VMs, their NICs, NSGs, public IPs, and both resource groups are managed by Terraform in this phase.

---

## Troubleshooting

**Azure Migrate project created in the wrong region**

In this lab, the Azure Migrate project region does not need to match the region of the staging infrastructure for the migration to succeed.

During testing, the project was created in different regions (for example, West US and Central US) while the staging resources remained in East US, and the migration process still completed successfully.

What matters is:
- The target Azure resources (VNet, storage account, Recovery Services Vault) are deployed in the intended region
- Replication is configured correctly against those resources

In production environments, aligning regions may still be preferred for latency, compliance, and data residency considerations.

---

**Azure Migrate project in the wrong resource group**

The project must live in the **staging** resource group (`rg-migrate-source`), not the target resource group. If it ends up in the wrong place, delete the project in the Azure portal and recreate it in the correct resource group.

Correct separation:
- `rg-migrate-source` → Azure Migrate project, appliances, storage, vault
- `rg-migrate-target` → migrated VM only

---

**Terraform apply fails on storage account name**

Storage account names must be globally unique across all of Azure, 3–24 characters, lowercase letters and numbers only. If the name `stmigrate[yourname]` is already taken:

```hcl
# In terraform.tfvars, use a more unique yourname value
yourname = "name02"
```

---

**Insufficient vCPU quota for appliance VMs**

The replication appliance requires a large VM size (Standard_D16s_v3 - 16 vCPUs). If your subscription does not have sufficient quota, you will receive an error when deploying the replication appliance VM in this phase. Request a quota increase before proceeding:

```
Azure portal → Subscriptions → your subscription → Usage + quotas
```

Filter by the VM family you need and submit a quota increase request. Approval is typically within a few minutes for lab-scale increases.

---

**Replication appliance deployment fails due to insufficient resources**

If the replication appliance VM fails to deploy or validate, it is typically due to insufficient CPU or disk resources.

In this implementation, the replication appliance required:
- At least 8 CPU cores (mapped to Azure vCPUs)
- A minimum of 600 GB disk space

Using smaller VM sizes or disks will cause the appliance manager validation to fail.

Solution:
- Use a VM size such as `Standard_D16s_v3`
- Configure the OS disk to at least 650 GB
---

## Next Phase

Once the Azure infrastructure and appliance VMs are successfully deployed and verified, proceed to:

**[Phase 3 — Appliance Deployment and Discovery](../phase-3-appliance-and-discovery/README.md)**