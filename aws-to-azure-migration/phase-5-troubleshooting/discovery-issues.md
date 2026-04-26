# Appliance and Discovery Issues

Issues encountered during appliance registration, WinRM configuration, and EC2 discovery in a cross-cloud environment without private connectivity.

---

## Issue 1 — Error 951 — Discovery Incomplete

**Phase:** 3 (discovery)

**Symptom:**

- Appliance configuration manager shows "Discovery Incomplete"
- Azure portal shows Error ID 951
- Revalidation of the discovery source shows "Validation successful"
- EC2 instance appears in the discovered machines list by IP address only — not hostname

**Root Cause:**

Error 951 is not documented in Microsoft's official error tables. The actual cause is that `ServerDiscoveryService.exe` on the appliance establishes a WinRM TCP connection on port 5985 successfully — which is why validation passes — but crashes during WMI/CIM session initialization before collecting any discovery data.

The root cause is **UAC token filtering**. Windows strips elevated privileges from remote connections using local Administrator accounts by default. Even when the Administrator account has full local admin rights, UAC removes the elevated token from the remote session, causing WMI queries to fail silently or return access denied.

Validation only checks TCP connectivity. Discovery requires a full authenticated WMI/CIM session — these are not the same thing. This is why validation can succeed while discovery fails — they test different layers of the communication stack.

**Resolution:**

Run on the **EC2 instance** in an elevated PowerShell session:

```powershell
# Fix UAC token filtering
Set-ItemProperty `
    HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
    -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord -Force

# Verify
Get-ItemProperty `
    HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
    -Name LocalAccountTokenFilterPolicy
# Should return: LocalAccountTokenFilterPolicy = 1
```

No reboot required. The change takes effect immediately for new WinRM connections.

Also verify only the HTTP listener exists on port 5985:

```powershell
winrm enumerate winrm/config/listener
# Should show only one listener: Transport = HTTP, Port = 5985
# If HTTPS listener is present, run fix-winrm-listener.ps1
```

After applying the fix:
1. Go to Azure portal → Azure Migrate → your project → Appliances
2. Click **Refresh services** on the appliance
3. Revalidate the discovery source
4. Click **Start discovery**

**Success indicator:**

The EC2 instance appears in the discovered machines list by **hostname** (e.g., `EC2AMAZ-XXXXXXX`) instead of IP address. Hostname = WMI completed successfully.

---

## Issue 2 — WinRM Firewall Exception Limits Access to Local Subnet

**Phase:** 3 (discovery)

**Symptom:**

RDP to the EC2 works correctly. The appliance validation on port 5985 fails or times out. WinRM is configured on the EC2 but connectivity from the appliance is blocked.

**Root Cause:**

`winrm quickconfig` enables WinRM and creates a Windows Firewall exception — but by default, that exception restricts WinRM to the **local subnet only**. The Azure Migrate appliance is in Azure, not on the same subnet as the EC2, so it is blocked at the OS firewall level even when the AWS Security Group is open. This creates a false-positive scenario where network-level access appears correct, but OS-level access is still blocked.

This means two separate firewall layers must both be configured:
1. **AWS Security Group** — cloud-level firewall (port 5985 inbound)
2. **Windows Firewall** — OS-level firewall (WinRM exception scope)

Opening the Security Group is not sufficient if Windows Firewall restricts the scope.

**Resolution:**

Run on the **EC2 instance** in an elevated PowerShell session:

```powershell
# Open WinRM in Windows Firewall to any remote address
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Enabled True
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -RemoteAddress Any
Restart-Service WinRM
```

Also confirm port 5985 is open inbound in the AWS Security Group. Both must be configured — fixing one without the other still blocks traffic.

Verify connectivity from the appliance VM:

```powershell
# Run on the appliance VM
Test-NetConnection -ComputerName <EC2_PUBLIC_IP> -Port 5985
# TcpTestSucceeded should return True
```

---

## Issue 3 — Replication Appliance CPU Validation Failed

**Phase:** 3 (replication appliance setup)

**Symptom:**

```
Memory and CPU validation failed. The server has only 4 CPU cores.
We recommend 8 cores.
```

The Azure Site Recovery installer shows this error even though the VM has 8 vCPUs.

**Root Cause:**

The ASR replication appliance installer validates against **physical CPU cores**, not logical vCPUs. Azure VMs use hyperthreading — meaning 8 vCPUs equals 4 physical cores. The installer requires a minimum of 8 physical cores, which means the appliance VM must have at least 16 vCPUs. This requirement is enforced by the Azure Site Recovery installer, not Terraform or Azure VM deployment.

| vCPUs | Physical Cores | Validation Result |
|---|---|---|
| 8 vCPUs | 4 physical cores | FAILS |
| 16 vCPUs | 8 physical cores | PASSES |

**Resolution:**

1. Request a vCPU quota increase if needed (see Azure Migrate / Portal Issues — Issue 3)
2. Resize or redeploy the replication appliance using **Standard_D16s_v3** (16 vCPUs)
3. Verify the physical core count inside the VM before re-running the installer:

```powershell
Get-CimInstance Win32_Processor | Select NumberOfLogicalProcessors, NumberOfCores
# NumberOfLogicalProcessors = 16
# NumberOfCores = 8
```

Re-run the ASR installer after confirming the core count.

---

## Issue 4 — DNS Resolution Failure During Mobility Service Registration

**Phase:** 3–4 (mobility service registration)

**Symptom:**

The mobility service installs successfully on the EC2 but registration fails:

```
Running registration prerequisites    Failed
Configuring connection settings       Skipped
Performing registration               Skipped
```

The log at `C:\ProgramData\ASRSetupLogs\ASRUnifiedAgentConfigurator.log` shows:

```
WriteErrorsToJsonFile: Error name: ConfiguratorConfigurationFailedWithDNSissue
Exit code returned by command: 2
```

**Root Cause:**

The mobility agent attempts to resolve the replication appliance by **hostname** during registration. The EC2 is in AWS and has no knowledge of Azure private DNS — it cannot resolve Azure VM hostnames. Registration fails even though IP connectivity exists and the appliance is reachable.

DNS resolution does not cross cloud boundaries without a VPN or ExpressRoute. Even when IP connectivity exists, hostname-based communication will fail unless explicitly configured.

**Resolution:**

**Step 1 — Get the replication appliance hostname:**

Run on the **replication appliance VM**:

```powershell
hostname
# Returns something like: repl-name
```

**Step 2 — Get the replication appliance public IP:**

```powershell
# Run on your local machine
terraform output replication_appliance_public_ip
# Or find it in the Azure portal → VM → Overview → Public IP
```

**Step 3 — Add a hosts file entry on the EC2:**

```powershell
# Run on the EC2 instance
.\scripts\add-hosts-entry.ps1 `
    -AppliancePublicIP "20.x.x.x" `
    -ApplianceHostname "repl-name"
```

Or manually:

```powershell
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" `
    -Value "20.x.x.x repl-name"

# Verify resolution
Resolve-DnsName repl-name
```

**Step 4 — Retry registration:**

```powershell
cd "C:\Program Files (x86)\Microsoft Azure Site Recovery\agent"
.\UnifiedAgentConfigurator.exe `
    /CSEndPoint <REPLICATION_APPLIANCE_PUBLIC_IP> `
    /PassphraseFilePath C:\MobilityInstaller\connection.passphrase
```

All three registration steps should now show **Successful**.

## Key Takeaways

- Discovery requires more than open ports — it requires full OS-level authentication via WMI/CIM
- WinRM configuration must be validated beyond `winrm quickconfig`
- Windows Firewall and AWS Security Groups must both be configured
- DNS does not function across cloud boundaries without explicit configuration
- Validation success does not guarantee discovery success