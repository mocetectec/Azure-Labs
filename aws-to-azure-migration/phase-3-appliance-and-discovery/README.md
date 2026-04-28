# Phase 3 - Appliance Registration, Discovery & Assessment

By this phase, all infrastructure is already deployed. The EC2 instance is running in AWS and both Azure resource groups are in place from Phases 1 and 2. Phase 3 is where the migration workflow begins. In this phase, the Azure Migrate appliances are registered, connectivity between AWS and Azure is validated, and discovery is performed against the source EC2 instance.

This phase bridges the gap between infrastructure provisioning and actual migration by establishing communication between the environments and confirming that the source machine can be successfully assessed.

> **Important:** Discovery depends on both network connectivity and OS-level configuration. Even if ports are open, discovery will fail if WinRM, WMI, or authentication settings are not configured correctly.

🎥 **Video walkthrough:** [AWS to Azure Migration — Phase 3](https://www.loom.com/share/7f06a976f4d749ebb0cfe5ec8485f32a)
---

## What This Phase Covers

| Step | What Happens |
|---|---|
| Register migration appliance | Discovery appliance is bound to the Azure Migrate project using a registration key |
| Configure appliance manager | Azure Migrate appliance configuration manager is used to complete registration and configure discovery settings |
| Register replication appliance | Replication appliance is registered separately for disk replication workflows |
| Complete WinRM configuration | EC2 `user_data` provides baseline setup - additional WMI/CIM and authentication settings are configured manually |
| Add EC2 credentials | Windows credentials added to the discovery appliance |
| Validate discovery path | CIM/WMI connectivity is tested from the appliance to the EC2 instance to confirm authentication and remote management access |
| Start discovery | Appliance connects to EC2 over WinRM and collects inventory |
| Run assessment | Azure Migrate evaluates readiness and recommends VM sizing |

---

## Prerequisites

- Phase 1 - EC2 running, accessible via RDP
- Phase 2 - Azure staging infrastructure deployed, both resource groups confirmed
- RDP access confirmed to both appliance VMs in Azure

---

## File Structure

This phase relies on PowerShell scripts to complete configuration and validate connectivity between the Azure appliance and the AWS EC2 instance.

```
phase-3-appliance-and-discovery/
├── scripts/
│   ├── configure-winrm-ec2.ps1       # Completes WinRM config not covered by user_data
│   ├── configure-winrm-appliance.ps1  # Configures WinRM client on the appliance
│   ├── validate-cim-path.ps1          # Validates the full discovery data path
│   └── fix-winrm-listener.ps1         # Removes HTTPS listener if present (Error 951 fix)
└── README.md
```

> No Terraform files in this phase — all infrastructure was provisioned in Phases 1 and 2. This phase focuses entirely on configuration, validation, and migration workflow execution.

---

## WinRM - What's Already Done vs What Still Needs Configuration

The EC2 `user_data` block runs automatically on first boot and handles the baseline WinRM setup:

```powershell
# Handled automatically by user_data at EC2 launch
net user Administrator "${var.admin_password}"   # Sets admin password
winrm quickconfig -force                          # Enables WinRM service
winrm set winrm/config/service/auth @{Basic="true"}       # Enables Basic auth
winrm set winrm/config/service @{AllowUnencrypted="true"}  # Allows HTTP
```

The following still require manual configuration before discovery will succeed:

>Azure Migrate discovery relies on WinRM and WMI/CIM to collect information from the source machine. Even if network ports are open, discovery will fail if these OS-level configurations are incomplete or misconfigured.

| Setting | Why It's Still Needed |
|---|---|
| `LocalAccountTokenFilterPolicy = 1` | Not configured by default - required to allow remote WMI/CIM queries using local Administrator credentials. Without it, discovery fails silently (Error 951). |
| `MaxEnvelopeSizekb = 8192` | Default WinRM limit may be too low for large WMI responses collected during discovery |
| Windows Firewall remote address | `winrm quickconfig` restricts access to local subnet by default - must allow remote connections from the Azure appliance |
| HTTPS listener check | Invalid or incomplete HTTPS listeners can cause the Azure Migrate discovery service to crash (common cause of silent failures) |
| Appliance VM WinRM client | Required for outbound connectivity from the appliance to the EC2 instance — must be configured separately |

> **Key Insight:** Successful discovery depends on three layers working together:
> 1. Network connectivity (ports open)
> 2. WinRM configuration (remote management enabled)
> 3. WMI/CIM access (authentication and system policies correctly configured)

---

## Step 1 — Complete WinRM Configuration on the EC2

RDP into the EC2 instance, open PowerShell as Administrator, and run `configure-winrm-ec2.ps1` from the scripts folder.

This script completes the OS-level configuration required for Azure Migrate discovery that is not handled by EC2 `user_data`::

```powershell
# What the script does (can also run these manually):

# Fix UAC token filtering — required for remote WMI/CIM to work
Set-ItemProperty `
    HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
    -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord -Force

# Increase envelope size
winrm set winrm/config '@{MaxEnvelopeSizekb="8192"}'

# Open WinRM through Windows Firewall to any remote address
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Enabled True
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -RemoteAddress Any

Restart-Service WinRM

# Verify only HTTP listener exists
winrm enumerate winrm/config/listener
```

> **Expected output:** One listener — HTTP on port 5985. If an HTTPS listener appears, run `fix-winrm-listener.ps1` before proceeding.

---

## Step 2 - Configure WinRM Configuration on the Appliance VM

RDP into the **discovery appliance VM**, open PowerShell as Administrator, and run `configure-winrm-appliance.ps1`:

```powershell
# Allow unencrypted traffic on the WinRM client
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# Trust all remote hosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Verify
winrm get winrm/config/client
```

---

## Discovery and Assessment Workflow
Once WinRM and connectivity are fully validated, the remaining steps follow the standard Azure Migrate workflow.

1. Register both the migration appliance and replication appliance in the Azure portal
2. Add Windows credentials for the EC2 instance
   
   <img width="1082" height="327" alt="image" src="https://github.com/user-attachments/assets/6b265cd4-c953-46c0-8b91-9baf3ee4ef0c" />

3. Configure the discovery source using the EC2 public IP

    <img width="1082" height="441" alt="image" src="https://github.com/user-attachments/assets/1ad88a8d-4057-4815-953b-b321f11c1f8d" />
   
4. Start discovery and wait for the machine to appear

   <img width="1557" height="307" alt="image" src="https://github.com/user-attachments/assets/5bc2e362-30fe-47dd-b132-8c80ce82f72b" />

5. Run an assessment to evaluate Azure readiness and recommended sizing

> The Azure Migrate appliance configuration manager is used throughout this process to register appliances, manage credentials, and monitor discovery progress.

---

## Validate the Full Discovery Path

Before triggering discovery in the portal, validate the complete CIM/WMI data path from the appliance. This is the same query the discovery service runs internally - if this fails, discovery will fail with Error 951.

Run from the **discovery appliance VM**:

```powershell
.\scripts\validate-cim-path.ps1 -EC2PublicIP "your-ec2-public-ip"
```

Enter the EC2 Administrator credentials when prompted.

**Both queries must return data before proceeding:**

```
[OK] CIM session established successfully
[OK] OS Query succeeded:
     OS: Microsoft Windows Server 2022 Datacenter
[OK] Computer System Query succeeded:
     Hostname: EC2AMAZ-XXXXXXX
```

If either query fails, the error output identifies the specific blocker. Do not start discovery until both pass.

---

## Discovery Success Indicators

| What you see | What it means |
|---|---|
| Hostname (EC2AMAZ-XXXXXXX) | Discovery successful — WMI completed |
| IP address only | WMI incomplete — fix WinRM configuration |

<img width="1397" height="211" alt="image" src="https://github.com/user-attachments/assets/b6a37afa-3113-4fba-87e4-c8988028ec85" />


---

## Assessment

After discovery completes, an assessment is run to evaluate:

- Azure readiness
- Recommended VM size
- Estimated monthly cost

A successful result should show:
- **Ready for Azure**
- A performance-based VM recommendation

<img width="1132" height="366" alt="image" src="https://github.com/user-attachments/assets/3c9ffde0-214a-437f-b2b6-a81b5472818d" />

Any “Ready with Conditions” or “Not Ready” results include specific remediation steps.

---

## Troubleshooting

This phase introduced the most failure points in the project. The issues below were encountered during discovery and validation and are documented with their root causes and fixes.

### Error 951 - Discovery Incomplete

Validation passes, but the EC2 appears by IP only or discovery never completes.

**Root cause:**
WinRM connectivity succeeds, but `ServerDiscoveryService.exe` crashes during WMI/CIM session initialization. This indicates an OS-level configuration issue, not a network issue.

**Fix (in order):**
1. Verify `LocalAccountTokenFilterPolicy = 1` on the EC2
2. Run `fix-winrm-listener.ps1` — remove HTTPS listener if present
3. Run `validate-cim-path.ps1` from the appliance — both queries must return data
4. Refresh appliance services in the portal → revalidate → restart discovery

### WinRM firewall exception limits access to local subnet

`winrm quickconfig` enables WinRM but restricts access to the local subnet by default.

**Fix (run on EC2):**

```powershell
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Enabled True
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -RemoteAddress Any
Restart-Service WinRM
```

### Replication appliance CPU validation failed

**Root cause:**
The Azure Site Recovery installer validates **physical CPU cores**, not vCPUs. Due to hyperthreading, more vCPUs are required to meet the minimum core requirement.

**Fix:**
- Resize the VM to `Standard_D16s_v3` or similar
- Request a vCPU quota increase if necessary

**Verify inside the VM:**

```powershell
Get-CimInstance Win32_Processor | Select NumberOfLogicalProcessors, NumberOfCores
```

---

## Next Phase

Once assessment shows **Ready for Azure** proceed to:

**[Phase 4 — Replication and Cutover](../phase-4-replication-and-cutover/README.md)**
