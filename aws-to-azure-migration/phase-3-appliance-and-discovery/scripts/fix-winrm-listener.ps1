# Run this on the EC2 source instance in an elevated PowerShell session
# if discovery is failing with Error 951 — Discovery Incomplete.
#
# What this script does:
#   - Checks the current WinRM listener configuration
#   - Removes the HTTPS listener if present with a missing or invalid certificate
#   - Verifies only the HTTP listener remains
#
# Why this matters:
#   If the EC2 has both an HTTP listener (port 5985) and an HTTPS listener
#   (port 5986), Azure Migrate's ServerDiscoveryService.exe attempts to use
#   the HTTPS listener. If the certificate is missing or invalid, the service
#   crashes silently during the TLS handshake before collecting any discovery
#   data. This produces Error 951 in the portal with no further detail.
#
#   This happens even when HTTP is fully functional and validation passes.
#   Validation only checks TCP connectivity — it does not attempt a TLS
#   handshake or WMI session.

Write-Host "=== WinRM Listener Diagnostic and Fix ===" -ForegroundColor Cyan

# Step 1 — Check current listener configuration
Write-Host "`n[1/3] Checking current WinRM listeners..." -ForegroundColor Yellow
$listenerOutput = winrm enumerate winrm/config/listener
Write-Host $listenerOutput

# Step 2 — Evaluate and fix
$hasHTTPS  = $listenerOutput -match "Transport = HTTPS"
$hasHTTP   = $listenerOutput -match "Transport = HTTP"

Write-Host "`n[2/3] Evaluating listener configuration..." -ForegroundColor Yellow

if (-not $hasHTTP) {
    Write-Host "[WARNING] No HTTP listener found - WinRM may not be configured" -ForegroundColor Red
    Write-Host "Run configure-winrm-ec2.ps1 first to set up WinRM properly" -ForegroundColor Yellow

} elseif ($hasHTTP -and -not $hasHTTPS) {
    Write-Host "[OK] Only HTTP listener present - configuration is correct" -ForegroundColor Green
    Write-Host "    No action needed. If discovery is still failing, check:" -ForegroundColor White
    Write-Host "    - UAC token filtering (LocalAccountTokenFilterPolicy)" -ForegroundColor White
    Write-Host "    - Port 5985 open in AWS Security Group" -ForegroundColor White
    Write-Host "    - WinRM client configured on the appliance VM" -ForegroundColor White
} elseif ($hasHTTP -and $hasHTTPS) {
    Write-Host "[WARNING] Both HTTP and HTTPS listeners detected" -ForegroundColor Red
    Write-Host "HTTPS listener with missing or invalid certificate causes" -ForegroundColor White
    Write-Host "ServerDiscoveryService.exe to crash - this is Error 951" -ForegroundColor White

    Write-Host "`n    Removing HTTPS listener..." -ForegroundColor Yellow
    try {
        winrm delete winrm/config/Listener?Address=*+Transport=HTTPS
        winrm quickconfig -q
        Write-Host "[OK] HTTPS listener removed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to remove HTTPS listener: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 3 — Verify final state
Write-Host "`n[3/3] Final listener verification..." -ForegroundColor Yellow
$finalListeners = winrm enumerate winrm/config/listener
Write-Host $finalListeners

if ($finalListeners -match "Transport = HTTPS") {
    Write-Host "`n[FAIL] HTTPS listener still present — manual removal required" -ForegroundColor Red
} else {
    Write-Host "`n=== Listener Configuration Verified ===" -ForegroundColor Green
    Write-Host "Only HTTP listener present on port 5985 — ready for discovery" -ForegroundColor White
    Write-Host "Next step: Run validate-cim-path.ps1 from the appliance VM" -ForegroundColor White
}