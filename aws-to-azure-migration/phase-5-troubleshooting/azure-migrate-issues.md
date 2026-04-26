# Azure Migrate / Portal Issues

These issues were encountered during real execution of the migration and reflect platform behavior rather than configuration mistakes alone.

---

## Issue 1 — Azure Migrate Project Created in the Wrong Region

**Phase:** 2 (Azure infrastructure setup)

**Symptom:**

The Azure Migrate project exists but the appliance registration or discovery may fail or behave inconsistently due to confusion between project region and target infrastructure region. Alternatively, you notice after creation that the project is in West US while all infrastructure is in East US.

**Root Cause:**

The Azure Migrate project region is fixed at creation time and cannot be changed. However, the project region does not strictly need to match the target infrastructure region.

Issues arise when there is confusion between:
- Project region
- Target region for replication
- Resource group placement

Inconsistent configuration can lead to appliance registration or replication confusion, even though the project itself may still function.

**Resolution:**

If the project is created in an unintended region, you have two options:

1. Continue using the project if replication and appliance registration function correctly
2. Delete and recreate the project for consistency with your target region

To recreate:

```powershell
az resource delete \
    --resource-group rg-migrate-source-<yourname> \
    --resource-type "Microsoft.Migrate/MigrateProjects" \
    --name migrate-project-<yourname>
```

3. Recreate via Terraform with the correct region confirmed in `terraform.tfvars`:
```hcl
location = "East US"
```

4. Re-run `terraform apply` to recreate the project in the correct region.

> Always confirm your `location` variable matches your infrastructure region before running `terraform apply` on the Azure side. > Aligning the project region with the staging resource group region is recommended for consistency, but not strictly required for functionality.

---

## Issue 2 — Azure Migrate Project Created in the Wrong Resource Group

**Phase:** 2 (Azure infrastructure setup)

**Symptom:**

The Azure Migrate project exists in `rg-migrate-target` instead of `rg-migrate-source`, or in a completely separate resource group. Replication setup fails or appliances cannot register correctly.

**Root Cause:**

The staging and target resource groups are created in the same region and often have similar naming, making it easy to select the wrong one during manual portal steps.

The correct design is:
- `rg-migrate-source` → Azure Migrate project, both appliances, storage account, Recovery Services Vault
- `rg-migrate-target` → migrated VM only (post-cutover)

**Resolution:**

Destroy and redeploy the Azure infrastructure with the project in the correct resource group:

```powershell
cd phase-2-azure-infrastructure
terraform destroy
terraform apply
```

Verify the project landed in the correct resource group:

```powershell
az resource list \
    --resource-group rg-migrate-source-[yourname] \
    --resource-type "Microsoft.Migrate/MigrateProjects" \
    --output table
```

---

## Issue 3 — Insufficient vCPU Quota for Appliance VMs

**Phase:** 2–3 (appliance VM deployment)

**Symptom:**

```
Error: compute.VirtualMachinesClient#CreateOrUpdate: Failure sending request:
StatusCode=409 -- Operation could not be completed as it results in exceeding
approved Total Regional Cores quota.
```

Or the VM deployment succeeds but the Azure Site Recovery installer fails with:

```
Memory and CPU validation failed. The server has only 4 CPU cores.
We recommend 8 cores.
```

**Root Cause:**

Two separate but related issues:

1. **Quota error at deployment:** Azure subscriptions have default vCPU limits per region and per VM family. New or free-tier subscriptions often have very low limits (4–10 vCPUs total). The replication appliance requires Standard_D16s_v3 — 16 vCPUs — which exceeds the default quota for many subscriptions.

2. **CPU validation failure at install:** The Azure Site Recovery replication appliance installer validates against **physical CPU cores**, not vCPUs. Due to hyperthreading, 8 vCPUs = 4 physical cores. The installer requires a minimum of 8 physical cores, which means at least 16 vCPUs are needed. Any VM with fewer than 16 vCPUs will fail validation even if the deployment succeeds.

This requirement is enforced by the Azure Site Recovery installer, not Terraform or Azure VM deployment.

**Resolution:**

**Step 1 — Request a quota increase:**

Go to **Azure portal → Subscriptions → your subscription → Usage + quotas**

Filter by:
- Region: East US
- Provider: Microsoft.Compute
- VM family: DSv3 Series (or whichever family you need)

Click the pencil icon and request an increase to at least 16 vCPUs for the required family. Approval for lab-scale increases is typically within a few minutes.

**Step 2 — Verify physical core count inside the VM after deployment:**

```powershell
Get-CimInstance Win32_Processor | Select NumberOfLogicalProcessors, NumberOfCores
# NumberOfLogicalProcessors should be 16
# NumberOfCores should be 8
```

Both values must meet the requirement before running the ASR installer. 

> The discovery appliance (Standard_E2s_v3) was used in this lab in place of the recommended Standard_A4_v2, which was unavailable in East US at time of deployment. The E2s_v3 completed discovery successfully for a single-source workload despite being below the recommended vCPU count.
