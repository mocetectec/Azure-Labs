# Replication Issues

Issues encountered during mobility service installation, replication, and cutover in a cross-cloud environment without private connectivity.

---

## Issue 1 — Mobility Agent Hardcodes Private Azure IP in Config Files

**Phase:** 4 (replication)

**Symptom:**

The mobility service installs and registers successfully, but replication fails to initialize. The agent log shows connection attempts to `10.1.x.x:443` — the replication appliance's **private** Azure IP — instead of its public IP. A hosts file entry alone does not fix this.

**Root Cause:**

During installation, the mobility agent writes the replication appliance IP address directly into several JSON configuration files on the EC2. If the appliance registered using its private Azure IP (`10.1.x.x`), that private IP gets hardcoded into the agent config.

The agent then connects **directly to the raw IP** — it does not perform a DNS lookup. This means a hosts file entry cannot override it. The config files must be patched directly.

This behavior bypasses DNS entirely, which is why modifying the hosts file does not resolve the issue.

> **Note:** This behavior is not documented by Microsoft and can be difficult to diagnose. It occurs because the mobility agent uses static configuration values instead of performing DNS resolution.

**Resolution:**

Run on the **EC2 instance** using the script from Phase 4:

```powershell
.\scripts\fix-private-ip-config.ps1 `
    -PrivateIP "10.1.1.x" `
    -PublicIP "replication-appliance-public-ip"
```

The script:
1. Scans all ASR config files for the hardcoded private IP
2. Replaces every instance with the replication appliance public IP
3. Verifies no private IP instances remain
4. Restarts InMage Scout Application Service and svagents
5. Watches the agent log for connection attempts to confirm the fix worked

**Verify the fix:**

After the services restart, check the active agent log:

```powershell
$log = Get-ChildItem "C:\Program Files (x86)\Microsoft Azure Site Recovery\agent" `
    -Filter "svagents_curr_*.log" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

Get-Content $log -Tail 30
```

Connection attempts should show the **public IP** on port 443. If you still see the private IP, re-run the script and verify the services restarted successfully.

---

## Issue 2 — Replication Stuck at 0%

**Phase:** 4 (replication)

**Symptom:**

Replication is configured and shows as active in the portal but the percentage synced stays at 0% and no data is being transferred. The status does not progress to Protected.

**Root Cause:**

Two common causes:

1. **Mobility service not running on the EC2** — if the InMage services stopped or failed to start after installation, replication cannot proceed
2. **Storage account misconfigured** — the replication cache storage account must be Standard tier, StorageV2 kind, and LRS replication in the same subscription and region as the Azure Migrate project

Replication at 0% typically indicates that the replication pipeline has been configured but data transfer has not started, usually due to service or connectivity issues.

**Resolution:**

**Check mobility services on the EC2:**

```powershell
Get-Service -Name "InMage*", "svagents"
# Both should show: Status = Running
```

If either service is stopped:

```powershell
Start-Service -Name "InMage Scout Application Service"
Start-Service -Name "svagents"
Get-Service -Name "InMage*", "svagents"
```

**Check the storage account:**

```powershell
az storage account show `
    --name stmigrate[yourname] `
    --resource-group rg-migrate-source-[yourname] `
    --query "{tier:sku.tier, kind:kind, replication:sku.name}"
```

Expected output:
```json
{
  "tier": "Standard",
  "kind": "StorageV2",
  "replication": "Standard_LRS"
}
```

If the storage account is misconfigured, destroy and redeploy Phase 2 with the correct values.

---

## Issue 3 — Replication Appliance Not Communicating with EC2

**Phase:** 4 (replication)

**Symptom:**

Replication is configured but the appliance shows connectivity errors to the source machine. The portal shows warnings or errors on the replicating machine. The mobility agent log shows connection failures.

Replication traffic originates from the EC2 instance and must reach the replication appliance over its public IP.

**Root Cause:**

The replication appliance communicates with the mobility service on the EC2 over ports 443 and 9443. If either port is blocked — at the AWS Security Group level or the Windows Firewall level — replication data cannot flow.

This is separate from the discovery ports. Discovery uses WinRM (5985). Replication uses 443 and 9443.

**Resolution:**

**Verify ports are open in the AWS Security Group:**

```powershell
aws ec2 describe-security-groups `
    --group-ids <your-sg-id> `
    --query "SecurityGroups[].IpPermissions[?FromPort==`443` || FromPort==`9443`]"
```

Both ports should appear as inbound rules. If missing, add them via Terraform or the AWS console.

**Verify Windows Firewall on the EC2:**

```powershell
# Check if ports are accessible from the appliance
Test-NetConnection -ComputerName <EC2_PUBLIC_IP> -Port 443
Test-NetConnection -ComputerName <EC2_PUBLIC_IP> -Port 9443
# Both should return TcpTestSucceeded = True
```

If blocked at the OS level:

```powershell
New-NetFirewallRule -DisplayName "ASR Replication 443" `
    -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
New-NetFirewallRule -DisplayName "ASR Replication 9443" `
    -Direction Inbound -Protocol TCP -LocalPort 9443 -Action Allow
```

---

## Issue 4 — RDP to Migrated VM Fails After Cutover

**Phase:** 4 (post-cutover verification)

**Symptom:**

The migrated VM appears in `rg-migrate-target-[yourname]` and shows as Running, but RDP connection attempts fail or time out.

**Root Cause:**

Two common causes:

1. **NSG not attached** — the `nsg-migrate-target-[yourname]` NSG was pre-created in Terraform but must be manually attached to the migrated VM's network interface after cutover. Azure Migrate does not automatically attach custom NSGs created outside the migration workflow.
2. **No public IP** — the migrated VM is created without a public IP by default. RDP requires a public IP attached to the NIC.

**Resolution:**

**Attach the NSG via the portal:**

1. Go to `rg-migrate-target-[yourname]` → click the migrated VM
2. Click **Networking** in the left panel
3. Click the network interface name
4. Click **Network security group** → Associate
5. Select `nsg-migrate-target-[yourname]`
6. Save

**Attach a public IP via the portal:**

1. On the network interface → click **IP configurations**
2. Click the IP config name
3. Under Public IP address → click Associate
4. Create a new Standard SKU public IP
5. Save

After both are attached, retrieve the public IP and retry RDP:

```powershell
az network public-ip show `
    --resource-group rg-migrate-target-[yourname] `
    --name pip-migrated-vm `
    --query ipAddress -o tsv
```

Use the original Administrator credentials from Phase 1 `terraform.tfvars`.

---

## Issue 5 — Migrated VM Has a Different IP Than the Source

**Phase:** 4 (post-cutover verification)

**Symptom:**

After cutover, the migrated VM in Azure has a different IP address than the source EC2 instance in AWS.

**Root Cause:**

This is **expected behavior**, not an error. The source EC2 had an IP address assigned by AWS DHCP within the AWS VPC (10.0.1.x). The migrated VM in Azure receives a new IP address assigned by Azure DHCP within the Azure VNet (10.1.1.x).

IP addresses do not migrate between clouds. Only the disk contents and OS state are replicated.

This change affects any system that depends on static IP addressing, including firewall rules, DNS records, and application configuration.

**Resolution:**

No action needed to resolve the IP change itself — it is correct behavior.

If applications or services depend on the source IP address, update the relevant DNS records or application configuration files to point to the new Azure IP after cutover.

```powershell
# Get the new private IP of the migrated VM
az vm show `
    --resource-group rg-migrate-target-[yourname] `
    --name <migrated-vm-name> `
    --show-details `
    --query privateIps -o tsv
```

> In a production migration, IP address changes should be planned and communicated before cutover. Update DNS TTLs in advance to minimize the impact of the change.

## Key Takeaways

- Replication relies on outbound connectivity from AWS to Azure
- DNS does not resolve across clouds without explicit configuration
- Some components (like the mobility agent) may bypass DNS entirely
- Validation success does not guarantee replication success
- Post-cutover networking must be configured manually in Azure