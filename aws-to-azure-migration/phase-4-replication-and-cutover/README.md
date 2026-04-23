# Phase 4 - Replication & Cutover

This phase covers the replication and cutover process using Azure Migrate and Azure Site Recovery. The EC2 instance is prepared for replication, its disk is synchronized to Azure, and a final cutover is performed to create a fully functional Azure VM.

By the end of this phase, the source workload has been successfully replicated, tested, and migrated into Azure.

---

## What This Phase Covers

| Step | What Happens |
|---|---|
| Install mobility service | Agent installed manually on the EC2 |
| Register with replication appliance | Mobility service connects to the replication appliance over ports 443 and 9443 |
| Enable replication | Azure Migrate begins initial disk sync from EC2 to Azure |
| Troubleshoot private IP issue | Config files patched if agent hardcodes the appliance private IP |
| Monitor replication | Wait for status to reach Protected |
| Run test migration | Temporary VM created to verify the replicated disk boots correctly |
| Continuous replication | Disk changes are continuously synced from EC2 to Azure until cutover |
| Perform cutover | Final VM created in the target resource group |
| Verify migrated VM | RDP into migrated VM and confirm hostname and OS |

> **Important:** During testing, the mobility agent may attempt to communicate with the replication appliance using its private IP address instead of the public IP. This breaks replication in a cross-cloud scenario and must be corrected before replication can succeed.

---

## Prerequisites

- Phase 3 complete - EC2 discovered by hostname
- Assessment shows **Ready for Azure**
- Replication appliance registered and healthy
- EC2 public IP and replication appliance public IP available
- RDP access confirmed to the replication appliance VM

---

## File Structure

```
phase-4-replication-and-cutover/
├── scripts/
│   ├── add-hosts-entry.ps1       # DNS override — maps appliance hostname to public IP for cross-cloud communication
│   └── fix-private-ip-config.ps1 # Patches hardcoded private IP in agent config files
└── README.md
```

---

## Replication Flow Overview

Replication is handled by the Azure Site Recovery (ASR) mobility service running on the EC2 instance. The agent sends disk data to the replication appliance, which then forwards it to Azure.

This creates a continuous synchronization pipeline:
EC2 → Mobility Agent → Replication Appliance → Azure

Cutover uses the replicated disk to create a new Azure VM in the target resource group.

---

## Step 1 - Download the Mobility Service Installer

The mobility service installer is not downloaded directly from the appliance. Instead, Azure Migrate provides a Microsoft download link during replication setup.

1. In Azure portal → **Azure Migrate → Migration and modernization** → click **Replicate**
2. Select your source machine and proceed through the replication setup
3. When prompted for mobility service installation, download the installer from the Microsoft link provided
4. Download the **DRInstaller** zip file
5. Extract the zip and navigate to the `Agents` folder
6. Locate the installer:
   ```
   Microsoft-ASR_UA_9.66.7567.1_Windows_GA_20Sep2025_release.exe
   ```
   > The version number in the filename may differ depending on when you download it. Use whatever version is current in your appliance.


---

## Step 2 - Copy Files to the EC2

Transfer the mobility service installer to the EC2 instance.

- The mobility service installer `.exe`


**Method - RDP file transfer:**
1. RDP into the EC2 instance
2. Use local resource sharing or clipboard transfer
3. Copy the installer to a local folder (e.g., `C:\MobilityInstaller`)

> **Note:** Direct file transfer between two RDP sessions may fail. If needed, download the files to your local machine and transfer them to the EC2 instance, or download them directly from the appliance manager within the EC2 browser session.

---

## Step 3 - Install the Mobility Service on the EC2

On the EC2 instance:

1. Navigate to `C:\MobilityInstaller` (or wherever you copied the files)
2. Right-click the `.exe` installer and run as Administrator
3. Follow the installation wizard

During installation:
- The mobility agent installs locally
- A **registration string** is generated

Copy this registration string — it is required to complete registration with the replication appliance.

After installation completes, go back to **Azure portal → Azure Migrate → Replicating Machines** and click **Retry**.

This triggers Azure Migrate to re-check the machine. Since the mobility service is already installed manually, the replication appliance skips the push installation step and proceeds directly to replication setup.

> In cross-cloud scenarios without private connectivity, manual installation is required because the replication appliance cannot reach the EC2 instance over its private IP.

---

## Step 4 - Enable Replication in Azure Migrate

Replication is orchestrated by Azure Site Recovery (ASR), which uses the mobility service to stream disk data from the EC2 instance to Azure.

1. In Azure Migrate → **Migration and modernization** → click **Replicate**
2. Under *Are your machines virtualized?* select **Yes, with another cloud provider**
3. Select your replication appliance
4. Select your EC2 instance from the discovered machines list
5. Configure target settings:
   - Resource group: `rg-migrate-target-[yourname]`
   - Replication storage account: `stmigrate[yourname]`
   - Virtual network: `vnet-migrate-[yourname]`
   - Subnet: `snet-migrate`
6. Set OS type to **Windows**
7. Click **Replicate**

Once replication is enabled, Azure Migrate begins the **initial synchronization**, copying the full disk from the EC2 instance to Azure. After the initial sync completes, **continuous replication** begins, syncing ongoing changes until cutover.

---

## Step 5 - Troubleshooting Replication Issues

Two common issues were encountered during replication setup in this project. Both are specific to cross-cloud communication and are documented with scripts for repeatable fixes.

---

### Issue A - DNS Resolution Failure During Registration

**Symptom:**
```
ConfiguratorConfigurationFailedWithDNSissue - Exit code 2
```

The mobility agent attempts to resolve the replication appliance by hostname during registration. The EC2 instance is outside the Azure network and has no access to Azure private DNS, so it cannot resolve the replication appliance hostname.

**Fix - run on the EC2:**

```powershell
# Get the replication appliance hostname
# Run on the replication appliance VM:
hostname

# Then on the EC2:
.\scripts\add-hosts-entry.ps1 `
    -AppliancePublicIP "replication-appliance-public-ip" `
    -ApplianceHostname "replication-appliance-hostname"
```

Retry registration after the hosts file entry is added.

---

### Issue B - Mobility Agent Hardcodes Private Azure IP (Undocumented)

**Symptom:**
Agent log shows connection attempts to `10.1.x.x:443` (the appliance private Azure IP) instead of the public IP. Replication fails to initialize. The hosts file fix alone does not resolve this.

**Root cause:**
During installation, the mobility agent writes the replication appliance IP directly into multiple JSON configuration files. If the appliance registered itself using its private Azure IP, that IP gets hardcoded into the agent config on the EC2. The agent bypasses DNS entirely and connects directly to the hardcoded IP - which is unreachable from AWS without a VPN.

> **Note:** This behavior is not documented by Microsoft and can be difficult to identify. It is separate from DNS resolution issues and is not fixed by modifying the hosts file.

**Fix — run on the EC2:**

```powershell
.\scripts\fix-private-ip-config.ps1 `
    -PrivateIP "10.1.1.x" `
    -PublicIP "replication-appliance-public-ip"
```

The script:
1. Scans all ASR config files for the hardcoded private IP
2. Replaces it with the replication appliance public IP
3. Verifies no private IP instances remain
4. Restarts the InMage Scout and svagents services
5. Watches the agent log for successful connections to the public IP

After the fix, connection attempts in the log should show the public IP on port 443 instead of the private IP.

This fix ensures that all replication traffic is routed through the appliance public IP, allowing communication between AWS and Azure without requiring a VPN or private connectivity.

> **Key Insight:** Cross-cloud migrations require explicit handling of DNS and IP resolution. Services designed for intra-cloud communication may default to private addressing, which must be overridden when no private connectivity exists.

---

## Step 6 - Monitor Replication Progress

Replication progress reflects the state of disk synchronization between the EC2 instance and Azure. 

In Azure Migrate → **Migration and modernization** → **Replicating machines**

Watch for these status transitions:

| Status | What It Means |
|---|---|
| Initial replication in progress | Full disk copy underway - 30–45 min for 30GB |
| Protected | Initial sync complete, delta sync running - ready for test migration |
| Critical / Warning | An error occurred - click the machine for details |

> Do not proceed to test migration until status reaches **Protected**.

---

## Step 7 - Run a Test Migration

A test migration creates a temporary VM from the replicated disk in an isolated network. This validates that the disk is bootable, the OS loads correctly, and the system is usable before committing to final cutover.

1. In the replicating machines list, click your EC2 instance
2. Click **Test migration**
3. Select the VNet: `vnet-migrate-[yourname]`
4. Click **Test migration**

Azure creates the test VM in 5–10 minutes.

**Verify the test VM:**
1. Navigate to `rg-migrate-target-[yourname]` in the portal
2. Create a public IP and attach it to the test VM's NIC via the portal
3. RDP in using the original Administrator credentials from Phase 1
4. Confirm the Windows desktop loads
5. Check the hostname matches your EC2 hostname from Phase 3 (e.g., EC2AMAZ-XXXXXXX)

> **AWS system info overlay:** AWS Windows instances include a desktop overlay showing instance metadata such as instance ID and private IP. This overlay persists after migration because it is part of the original Windows image. The displayed networking details will not match the Azure environment - this is expected behavior.

**Clean up the test VM:**
1. Return to Azure Migrate → replicating machine
2. Click **Clean up test migration**
3. Confirm - this deletes the test VM

---

## Step 8 - Perform Cutover

1. In the replicating machines list, click your EC2 instance
2. Click **Migrate**
3. Under *Shut down machines before migration* select **No** (lab only - in production, shut down the source to prevent split-brain)
4. Click **Migrate**

Azure finalizes the last delta synchronization and creates the target VM from the replicated disk. This takes 5–10 minutes. Cutover uses the latest replicated state of the disk, including all changes captured during continuous replication.

---

## Step 9 - Attach Public IP and Verify

The migrated VM lands in `rg-migrate-target-[yourname]` with no public IP attached by default. By default, the migrated VM is deployed without external access for security reasons.

**Attach a public IP via the portal:**
1. Go to `rg-migrate-target-[yourname]`
2. Click the VM's **Network Interface**
3. Click **IP configurations**
4. Click the IP config → Associate a public IP address
5. Create a new Standard SKU public IP
6. Save

**Attach the NSG:**
1. On the Network Interface → click **Network security group**
2. Associate `nsg-migrate-target-[yourname]` from the target resource group

**RDP and verify:**
1. Get the public IP from the portal
2. RDP in using `Administrator` and the password from Phase 1 `terraform.tfvars`
3. Confirm:

| Checkpoint | Expected |
|---|---|
| Windows desktop loads | ✅ |
| Hostname in System Properties | Matches your EC2 hostname from Phase 3 (e.g., EC2AMAZ-XXXXXXX) |
| OS version | Windows Server 2022 Datacenter |
| AWS overlay visible | Expected - artifact of cross-cloud migration |

The migration is complete - the AWS EC2 workload is now fully operational as an Azure VM.

---

## Estimated Cost

Costs in this phase are driven primarily by the replication appliance and are incurred only during active replication and testing.

| Resource | Estimated Cost |
|---|---|
| Replication appliance VM (Standard_D16s_v3) | ~$0.77/hour |
| Discovery appliance VM (Standard_E2s_v3) | ~$0.13/hour |
| Replication data transfer | Minimal for 30GB |
| Target VM post-cutover (Standard_B2s) | ~$0.04/hour |
| **Total for replication phase (~2 hours)** | **~$2.00–3.00** |

> Destroy all resources immediately after verification. See teardown instructions in Phase 2.

---

## Troubleshooting

**Replication stuck at 0%**

Verify the storage account `stmigrate<yourname>` is in the same subscription and region as the Azure Migrate project.

Also confirm the mobility service is running on the EC2:

```powershell
# Run on the EC2
Get-Service -Name "InMage*", "svagents"
# Both should show Running
```

---

**RDP to migrated VM fails**

The NSG may not be attached to the migrated VM’s network interface. By default, the VM is created without inbound access for security reasons. Go to the portal → VM → Networking → attach `nsg-migrate-target-[yourname]` to the network interface.

Also confirm the public IP is attached and the VM is in a Running state.

---

**Migrated VM has a different IP than the source**

This is expected. When migrating between clouds, the VM is assigned a new IP address by Azure DHCP at cutover.

In production scenarios, any dependencies on the original IP (such as DNS records, application configurations, or firewall rules) must be updated accordingly.

---

**Replication appliance not communicating with EC2**

If replication does not start or fails intermittently, verify that the EC2 instance can reach the replication appliance over ports 443 and 9443 using its public IP.

Cross-cloud replication requires outbound connectivity from AWS to Azure — private IP communication will not work without a VPN or private link.

---

## Migration Outcome

> **Result:** The EC2 workload has been successfully migrated from AWS to Azure using Azure Migrate and Azure Site Recovery, with full validation of replication, boot, and connectivity.

## Next Phase

The migration is now complete - the workload has been successfully moved from AWS to Azure and validated.

Phase 5 consolidates all troubleshooting scenarios encountered during this project into a dedicated reference guide, including discovery failures, replication issues, and cross-cloud connectivity challenges.

**[Phase 5 — Troubleshooting Reference →](../phase-5-troubleshooting/README.md)**
