# Run this on the EC2 source instance in an elevated PowerShell session.
# Adds the replication appliance hostname to the EC2 hosts file, mapping
# it to the appliance's public IP.
#
# Why this is needed:
#   The mobility service agent resolves the replication appliance by hostname
#   during registration. The EC2 is in AWS and has no knowledge of Azure
#   private DNS - it cannot resolve Azure VM hostnames. Adding a manual
#   hosts file entry forces the resolution to the public IP.
#
# Usage:
#   .\add-hosts-entry.ps1 -AppliancePublicIP "20.x.x.x" -ApplianceHostname "repl-yourname"

param(
    [Parameter(Mandatory=$true)]
    [string]$AppliancePublicIP,

    [Parameter(Mandatory=$true)]
    [string]$ApplianceHostname
)

$hostsPath = "C:\Windows\System32\drivers\etc\hosts"

Write-Host "=== Adding Replication Appliance Hosts File Entry ===" -ForegroundColor Cyan
Write-Host "Appliance Public IP : $AppliancePublicIP" -ForegroundColor White
Write-Host "Appliance Hostname  : $ApplianceHostname" -ForegroundColor White

# Check if entry already exists
$currentHosts = Get-Content $hostsPath
$entryExists = $currentHosts | Where-Object { $_ -match $ApplianceHostname }

if ($entryExists) {
    Write-Host "`n[INFO] Entry for $ApplianceHostname already exists in hosts file:" -ForegroundColor Yellow
    Write-Host "    $entryExists" -ForegroundColor White
    Write-Host "    No action taken - remove the existing entry manually if the IP has changed" -ForegroundColor Yellow
} else {
    # Add the entry
    $entry = "$AppliancePublicIP $ApplianceHostname"
    Add-Content -Path $hostsPath -Value $entry
    Write-Host "`n[OK] Entry added successfully" -ForegroundColor Green
    Write-Host "    $entry" -ForegroundColor White
}

# Verify final hosts file state
Write-Host "`n=== Verifying Hosts File ===" -ForegroundColor Cyan
$finalHosts = Get-Content $hostsPath
Write-Host ($finalHosts | Where-Object { $_ -notmatch "^#" -and $_ -match "\S" })

# Test resolution
Write-Host "`n=== Testing Hostname Resolution ===" -ForegroundColor Cyan
try {
    $resolved = Resolve-DnsName $ApplianceHostname -ErrorAction Stop
    Write-Host "[OK] $ApplianceHostname resolves to: $($resolved.IPAddress)" -ForegroundColor Green

    if ($resolved.IPAddress -eq $AppliancePublicIP) {
        Write-Host "[OK] Resolved IP matches the public IP - hosts file entry is working" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Resolved IP does not match expected public IP $AppliancePublicIP" -ForegroundColor Red
        Write-Host "    Check for conflicting DNS entries or existing hosts file entries" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERROR] Could not resolve $ApplianceHostname - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Hosts File Entry Complete ===" -ForegroundColor Cyan
Write-Host "Next step: Retry mobility service registration on the EC2" -ForegroundColor White
