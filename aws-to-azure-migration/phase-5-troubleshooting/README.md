# Phase 5 - Troubleshooting Reference

Real-world issues encountered during execution of this cross-cloud migration, organized by phase. Each issue includes the exact symptom, root cause, and resolution, with a focus on understanding why failures occur in a cross-cloud environment without private connectivity.

---

## Scope

This reference is not a step-by-step guide. It is designed to help diagnose and resolve issues encountered during each phase of the migration.

## Index

### [Terraform Issues](./terraform-issues.md)
Issues encountered during `terraform apply` on both the AWS and Azure sides.

| Issue | Quick Summary |
|---|---|
| AccessDenied during terraform apply | Terraform IAM user missing EC2 or IAM permissions |
| AMI not found / empty result error | Hardcoded AMI ID is stale or region-specific |
| Storage account name conflict | Name already taken globally in Azure |

---

### [Azure Migrate Issues](./azure-migrate-issues.md)
Issues related to Azure Migrate project configuration and subscription-level settings.

| Issue | Quick Summary |
|---|---|
| Project created in wrong region | Region is locked at creation - may require recreation for consistency |
| Project created in wrong resource group | Must live in staging RG, not target RG |
| Insufficient vCPU quota | Subscription quota too low for appliance VM sizes |

---

### [Discovery and Appliance Issues](./discovery-issues.md)
Issues encountered during appliance registration, WinRM configuration, and discovery.

| Issue | Quick Summary |
|---|---|
| Error 951 — Discovery Incomplete | UAC token filtering blocks remote WMI - not a network issue |
| WinRM firewall limits access to local subnet | OS firewall restricts WinRM even when SG is open |
| Replication appliance CPU validation failed | ASR validates physical cores not vCPUs - needs 16 vCPUs |
| DNS resolution failure during registration | EC2 cannot resolve Azure hostnames - requires hosts file entry |

---

### [Replication Issues](./replication-issues.md)
Issues encountered during mobility service installation, replication, and cutover.

| Issue | Quick Summary |
|---|---|
| Mobility agent hardcodes private Azure IP | Agent uses hardcoded private IP - requires direct config file patching |
| Replication stuck at 0% | Mobility service not running or storage account misconfigured |
| Replication appliance not communicating with EC2 | Port 9443 or 443 blocked - check both SG and Windows Firewall |
| RDP to migrated VM fails | NSG not attached to migrated VM NIC |
| Migrated VM has different IP than source | Expected behavior - DHCP assigns new Azure IP at cutover |

---

### [Port Reference](./port-reference.md)
Complete port requirements for all phases of the migration.

---

## How to Use This Reference

Each file is organized by issue with the following structure:

- **Symptom** - what you see in the portal, terminal, or logs
- **Root Cause** - what is actually happening
- **Resolution** - exact steps and commands to fix it

If you are hitting an issue during the lab, identify which phase you are in and go to the relevant file. The port reference is useful if connectivity is failing and you need to verify all required ports are open. If validation succeeds but the operation fails, focus on the Root Cause section - many Azure Migrate checks validate connectivity but not full application behavior.
