# Port Reference

Complete port requirements for all phases of the AWS to Azure migration. All ports were validated through real troubleshooting during this lab.

> **Important:** Successful migration requires ports to be open at both the network layer (AWS Security Group / Azure NSG) and the OS layer (Windows Firewall). Most discovery and replication failures occur when one layer is configured but the other is not.

---

## EC2 Instance - AWS Security Group

| Port | Protocol | Direction | Purpose | Phase |
|------|----------|-----------|---------|-------|
| 443 | TCP | Inbound | HTTPS - Azure Migrate appliance communication | Discovery & Replication |
| 3389 | TCP | Inbound | RDP - admin access for verification and troubleshooting | All phases |
| 5985 | TCP | Inbound | WinRM HTTP - OS-level discovery via CIM/WMI (appliance → EC2) | Discovery |
| 5986 | TCP | Inbound | WinRM HTTPS (optional) - remove if misconfigured or unused | Discovery |
| 445 | TCP | Inbound | SMB - mobility service push installation (appliance → EC2) | Replication |
| 135 | TCP | Inbound | WMI RPC - required alongside WinRM for discovery | Discovery |
| 9443 | TCP | Outbound | ASR replication data - mobility agent streams data to appliance | Replication |
---

## EC2 Instance - Windows Firewall

The AWS Security Group and Windows Firewall are independent. Both must be configured - opening the Security Group is not sufficient if Windows Firewall restricts the port.

| Port | Display Group / Rule Name | Phase |
|------|--------------------------|-------|
| 5985 | Windows Remote Management | Discovery |
| 443 | Configured by ASR installer | Replication |
| 9443 | ASR Replication 9443 (manual rule) | Replication |

Configure WinRM firewall rules:

```powershell
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Enabled True
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -RemoteAddress Any
```

> **Key Insight:** `winrm quickconfig` enables WinRM but restricts access to the local subnet by default. This must be expanded to allow remote connections from the Azure appliance.

---

## Replication Appliance VM — Azure NSG

| Port | Protocol | Direction | Purpose | Source |
|------|----------|-----------|---------|--------|
| 443 | TCP | Inbound | HTTPS - mobility service registration and control communication | EC2 public IP |
| 9443 | TCP | Inbound | Replication data channel - mobility agent streams disk data to appliance | EC2 public IP |
| 3389 | TCP | Inbound | RDP - admin access for configuration and troubleshooting | Your IP |

---

## Discovery Appliance VM — Azure NSG

| Port | Protocol | Direction | Purpose | Source |
|------|----------|-----------|---------|--------|
| 443 | TCP | Inbound | HTTPS - Azure Migrate service communication (optional, typically outbound-initiated) | Azure service tags |
| 3389 | TCP | Inbound | RDP -cd moc admin access for configuration and troubleshooting | Your IP |

---

## Summary by Phase

Ports must be validated before starting each phase. Opening ports after failures occur can lead to inconsistent states and require re-validation or restart of the migration workflow.

### Phase 3 — Discovery
Open before starting discovery:

| Port | Where |
|------|-------|
| 5985 | EC2 Security Group + Windows Firewall |
| 135 | EC2 Security Group |
| 443 | EC2 Security Group |
| 3389 | EC2 Security Group + Appliance NSG |

### Phase 4 — Replication
Open before enabling replication:

| Port | Where |
|------|-------|
| 445 | EC2 Security Group |
| 9443 | EC2 Security Group + Windows Firewall + Replication Appliance NSG |
| 443 | Replication Appliance NSG (inbound from EC2) |

---

## Common Port-Related Errors

| Error | Likely Blocked Port | Where to Check |
|---|---|---|
| Discovery Incomplete / Error 951 | 5985 (WinRM) | EC2 SG + Windows Firewall scope |
| Mobility service push fails (Error 322008) | 445 (SMB) | EC2 Security Group |
| Mobility registration DNS failure | 443 (HTTPS) | Replication Appliance NSG |
| Replication stuck at 0% | 9443 | EC2 SG + Windows Firewall |
| Appliance not communicating with EC2 | 443 or 9443 | EC2 SG + Windows Firewall |

---

## Quick Connectivity Tests

Run these from the **replication appliance VM** to verify EC2 ports are reachable:

```powershell
# Test all required ports from the appliance
$ec2IP = "<EC2_PUBLIC_IP>"
$ports = @(443, 445, 5985, 9443)

foreach ($port in $ports) {
    $result = Test-NetConnection -ComputerName $ec2IP -Port $port
    $status = if ($result.TcpTestSucceeded) { "OPEN" } else { "BLOCKED" }
    Write-Host "Port $port : $status" -ForegroundColor $(if ($result.TcpTestSucceeded) { "Green" } else { "Red" })
}
```
