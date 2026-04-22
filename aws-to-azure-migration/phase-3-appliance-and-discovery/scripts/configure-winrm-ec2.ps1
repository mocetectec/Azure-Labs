# configure-winrm-ec2.ps1
# Run this on the EC2 source instance in an elevated PowerShell session
# before starting discovery in Azure Migrate.
#
# What this script does:
#   - Enables and configures WinRM for remote management
#   - Allows unencrypted HTTP traffic on port 5985
#   - Enables Basic and Negotiate authentication
#   - Fixes UAC token filtering for local Administrator accounts
#   - Verifies only the HTTP listener exists (removes HTTPS if present)

Write-Host "=== Configuring WinRM on EC2 Source Instance ===" -ForegroundColor Cyan

# Step 1 - Enable WinRM and apply baseline config
Write-Host "`n[1/6] Enabling WinRM..." -ForegroundColor Yellow
winrm quickconfig -force

# Step 2 - Allow unencrypted HTTP traffic
# Required for Azure Migrate appliance to communicate over port 5985
Write-Host "`n[2/6] Allowing unencrypted HTTP traffic..." -ForegroundColor Yellow
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Step 3 - Enable authentication methods
Write-Host "`n[3/6] Enabling Basic and Negotiate authentication..." -ForegroundColor Yellow
winrm set winrm/config/service/auth '@{Basic="true"; Negotiate="true"}'

# Step 4 -  Increase envelope size
# Azure Migrate default can be too low for large WMI responses
Write-Host "`n[4/6] Setting envelope size to 8192kb..." -ForegroundColor Yellow
winrm set winrm/config '@{MaxEnvelopeSizekb="8192"}'

# Step 5 -  Fix UAC token filtering for local Administrator accounts
# Without this, remote WMI/CIM queries fail silently even with correct credentials
# This is the root cause of Error 951 - Discovery Incomplete
Write-Host "`n[5/6] Fixing UAC token filtering for local admin accounts..." -ForegroundColor Yellow
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$currentValue = Get-ItemProperty $regPath -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue

if ($currentValue.LocalAccountTokenFilterPolicy -eq 1) {
    Write-Host "LocalAccountTokenFilterPolicy already set to 1 - skipping" -ForegroundColor Green
} else {
    Set-ItemProperty $regPath -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord -Force
    Write-Host "LocalAccountTokenFilterPolicy set to 1" -ForegroundColor Green
}

# Step 6 - Restart WinRM to apply all changes
Write-Host "`n[6/6] Restarting WinRM service..." -ForegroundColor Yellow
Restart-Service WinRM

# Step 7 - Verify listener configuration
# Only the HTTP listener on port 5985 should exist
# An HTTPS listener with a missing or invalid certificate causes
# ServerDiscoveryService.exe to crash silently (Error 951)
Write-Host "`n=== Verifying WinRM Listener Configuration ===" -ForegroundColor Cyan
$listeners = winrm enumerate winrm/config/listener
Write-Host $listeners

if ($listeners -match "Transport = HTTPS") {
    Write-Host "`n[WARNING] HTTPS listener detected removing..." -ForegroundColor Red
    winrm delete winrm/config/Listener?Address=*+Transport=HTTPS
    winrm quickconfig -q
    Write-Host "    HTTPS listener removed successfully" -ForegroundColor Green
    Write-Host "    Re-verifying listeners..." -ForegroundColor Yellow
    winrm enumerate winrm/config/listener
} else { 
    Write-Host "`n[OK] Only HTTP listener present - configuration is correct" -ForegroundColor Green
}

# Step 8 - Open WinRM through Windows Firewall
Write-Host "`n=== Configuring Windows Firewall ===" -ForegroundColor Cyan
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Enabled True -ErrorAction SilentlyContinue
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -RemoteAddress Any -ErrorAction SilentlyContinue
Write-Host "[OK] Windows Firewall rules updated for WinRM" -ForegroundColor Green

Write-Host "`n=== WinRM Configuration Complete ===" -ForegroundColor Cyan
Write-Host "Next step: Run configure-winrm-appliance.ps1 on the discovery appliance VM" -ForegroundColor White