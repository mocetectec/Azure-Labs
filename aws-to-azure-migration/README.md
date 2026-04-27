# AWS EC2 to Azure Migration

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-FF9900?style=flat&logo=amazonaws&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)
![Azure Migrate](https://img.shields.io/badge/Azure_Migrate-0078D4?style=flat&logo=microsoftazure&logoColor=white)
![Windows Server](https://img.shields.io/badge/Windows_Server_2022-0078D6?style=flat&logo=windows&logoColor=white)

End-to-end cross-cloud migration of a Windows Server workload from AWS EC2 to Azure using Azure Migrate, Azure Site Recovery, and Terraform.

This project implements the full migration lifecycle - infrastructure provisioning, discovery, assessment, replication, and cutover — and includes detailed troubleshooting of real-world issues encountered in a cross-cloud environment without private connectivity.

🎥 **Video walkthrough:** [AWS to Azure Migration — End-to-End Cross-Cloud Project](https://www.loom.com/share/8b101048501543249deef004c3789955)
---

## Architecture

The diagram below shows the full cross-cloud migration setup between AWS and Azure.

The source environment is hosted in AWS. A Windows Server 2022 EC2 instance runs inside a custom VPC with a public subnet, accessible over the internet.

Azure is divided into two resource groups:

- **Staging (`rg-migrate-source-<yourname>`)**  
  Hosts all migration infrastructure, including:
  - Azure Migrate project
  - Recovery Services Vault
  - Storage account (replication cache)
  - Discovery appliance VM
  - Replication appliance VM

- **Target (`rg-migrate-target-<yourname>`)**  
  Contains the final migrated VM after cutover

Two Azure Migrate appliances are used:

- **Discovery appliance** — collects inventory and performance data from the EC2 instance via WinRM/WMI  
- **Replication appliance** — manages disk replication using Azure Site Recovery

> **Key design decision:** All communication between AWS and Azure occurs over public endpoints — there is no VPN or private connectivity.  
> This simplifies the lab setup but introduces additional complexity around authentication, DNS resolution, and replication connectivity.

<img width="1916" height="1364" alt="image" src="https://github.com/user-attachments/assets/8a09177d-e989-46cf-8974-5b05072e36dd" />


---

## What This Project Demonstrates

- Cross-cloud migration using Azure Migrate and Azure Site Recovery
- Infrastructure as Code on both AWS and Azure using Terraform
- WinRM and WMI configuration for agentless OS-level discovery
- Disk replication using Azure Site Recovery (EBS → Azure managed disks)
- Manual mobility service installation for cross-cloud scenarios without a VPN
- Real-world troubleshooting - 9 documented issues including one not covered in Microsoft's documentation
- Reusable PowerShell scripts for discovery validation and replication fixes

---

## Phase Structure

| Phase | What It Covers | Link |
|---|---|---|
| Phase 1 | AWS source infrastructure - VPC, EC2, security group, IAM | [phase-1-aws-infrastructure](./phase-1-aws-infrastructure/) |
| Phase 2 | Azure staging and target infrastructure - VNet, Migrate project, RSV, storage | [phase-2-azure-infrastructure](./phase-2-azure-infrastructure/) |
| Phase 3 | Appliance registration, WinRM configuration, discovery, assessment | [phase-3-appliance-and-discovery](./phase-3-appliance-and-discovery/) |
| Phase 4 | Mobility service installation, replication, test migration, cutover | [phase-4-replication-and-cutover](./phase-4-replication-and-cutover/) |
| Phase 5 | Phase 5 | Consolidated troubleshooting reference - 9 issues with root causes and fixes | [phase-5-troubleshooting](./phase-5-troubleshooting/) |

---

## Tech Stack

| Category | Tools |
|---|---|
| Infrastructure as Code | Terraform |
| Source cloud | AWS - EC2, VPC, IAM, Security Groups, EBS |
| Target cloud | Azure - Azure Migrate, Azure Site Recovery, Recovery Services Vault, VNet |
| OS | Windows Server 2022 |
| Scripting | PowerShell |
| Migration tool | Azure Migrate |
| Replication engine | Azure Site Recovery (under the hood) |

---

## Key Design Decisions

**Two resource groups — staging and target.**
Migration infrastructure (appliances, storage cache, vault) is kept separate from the final migrated VM. After cutover, the staging environment is destroyed cleanly without touching the workload.

**No VPN between clouds.**
All traffic flows over the public internet using the EC2's public IP. This is the correct setup for a cost-effective migration lab and is what drives most of the real troubleshooting challenges documented in Phase 5.

**Non-overlapping CIDRs.**
AWS VPC uses `10.0.0.0/16`. Azure VNet uses `10.1.0.0/16`. Non-overlapping ranges prevent routing conflicts if connectivity between the environments is added later.

**WinRM automated via user_data.**
The EC2 user data script enables and configures WinRM at first boot so the instance is discovery-ready without manual intervention.

**Manual mobility service installation.**
Push installation from the replication appliance always fails in cross-cloud setups without a VPN — the appliance targets the EC2's private IP, which is unreachable from Azure. Manual mobility service installation is required in this lab setup because there is no private connectivity between AWS and Azure.

---

## Troubleshooting Highlights

Full documentation for every issue is in [Phase 5](./phase-5-troubleshooting/). These issues were encountered during real execution of the migration and are documented in detail. Three issues worth calling out:

**Error 951 — Discovery Incomplete**
Appliance validation passes but discovery fails. Root cause is UAC token filtering blocking remote WMI sessions - not a network issue. Fixed via a single registry key. Documented with root cause, fix, and validation script.

**Mobility service push fails cross-cloud**
The replication appliance uses the EC2's private IP from WMI metadata to push the installer over SMB. Without a VPN, that IP is unreachable from Azure. Manual installation is required for cross-cloud migrations without direct connectivity.

**Mobility agent hardcodes private Azure IP in config files**
After manual installation, the mobility agent writes the replication appliance's private Azure IP directly into JSON config files - bypassing DNS entirely. A hosts file entry cannot fix this. The config files must be patched directly using PowerShell and the mobility services restarted.

---

## Scripts

Reusable PowerShell scripts are included to automate validation and resolve common migration issues:

| Script | Phase | Purpose |
|---|---|---|
| `configure-winrm-ec2.ps1` | Phase 3 | Completes WinRM configuration on the EC2 |
| `configure-winrm-appliance.ps1` | Phase 3 | Configures WinRM client on the appliance VM |
| `validate-cim-path.ps1` | Phase 3 | Validates the full CIM/WMI discovery path before triggering discovery |
| `fix-winrm-listener.ps1` | Phase 3 | Detects and removes invalid HTTPS WinRM listener |
| `add-hosts-entry.ps1` | Phase 4 | Maps replication appliance hostname to public IP in EC2 hosts file |
| `fix-private-ip-config.ps1` | Phase 4 | Patches hardcoded private Azure IP in mobility agent config files |

---

## Estimated Cost

Costs reflect a short-lived lab environment with resources running only during active testing and migration.

| Resource | Estimated Cost |
|---|---|
| EC2 t3.medium (or similar) - Windows Server 2022 | ~$0.08/hour |
| Discovery appliance - Standard_E2s_v3 | ~$0.13/hour |
| Replication appliance - Standard_D16s_v3 | ~$0.77/hour |
| Storage account - replication cache (~30GB LRS) | ~$0.60/day |
| Target VM post-cutover - Standard_B2s | ~$0.04/hour |
| **Total for a full day lab** | **~$8–12** |

> Destroy all resources immediately after completing the lab. See teardown instructions in each phase README.

---

## Prerequisites

- AWS account with programmatic access
- Azure subscription with sufficient vCPU quota
- Terraform installed
- AWS CLI installed and configured
- Azure CLI installed and authenticated
- RDP access capability for Windows VMs

Refer to each phase README for detailed prerequisites and deployment steps.
