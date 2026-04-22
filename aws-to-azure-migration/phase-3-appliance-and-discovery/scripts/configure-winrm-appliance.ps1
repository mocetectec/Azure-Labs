# Run this on the Azure Migrate discovery appliance VM in an elevated
# PowerShell session before starting discovery.
#
# What this script does:
#   - Configures the WinRM client to allow unencrypted connections
#   - Trusts all remote hosts
#   - Verifies the configuration was applied

Write-Host "=== Configuring WinRM Client on Discovery Appliance ===" -ForegroundColor Cyan

# Step 1 — Allow unencrypted traffic on the WinRM client
# By default the appliance WinRM client rejects unencrypted HTTP connections
# even when the EC2 is reachable on port 5985 at the TCP level
Write-Host "`n[1/2] Allowing unencrypted traffic on WinRM client..." -ForegroundColor Yellow
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# Step 2 — Trust all remote hosts
# Required for the appliance to connect to the EC2 public IP
Write-Host "`n[2/2] Setting trusted hosts to wildcard..." -ForegroundColor Yellow
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Verify settings were applied
Write-Host "`n=== Verifying WinRM Client Configuration ===" -ForegroundColor Cyan
winrm get winrm/config/client

Write-Host "`n=== Appliance WinRM Client Configuration Complete ===" -ForegroundColor Cyan
Write-Host "Next step: Run validate-cim-path.ps1 from this appliance to confirm" -ForegroundColor White
Write-Host "the full discovery data path works before triggering discovery." -ForegroundColor White
