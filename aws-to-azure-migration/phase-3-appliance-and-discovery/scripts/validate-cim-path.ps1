# Run this on the Azure Migrate discovery appliance VM BEFORE triggering
# discovery in the Azure portal.
#
# What this script does:
#   - Opens a CIM/WMI session from the appliance to the EC2 over WinRM
#   - Runs the same queries Azure Migrate's discovery service uses internally
#   - Confirms the full data path works before you start discovery
#
# Why this matters:
#   The appliance configuration manager validation only checks TCP connectivity
#   on port 5985. It does NOT validate the full WMI/CIM session. Discovery
#   can fail with Error 951 even when validation passes. This script catches
#   those failures before you waste time waiting for discovery to fail.
#
# Success indicator:
#   Both queries return data — OS info and computer name/domain details.
#   If the EC2 appears in the discovered machines list by HOSTNAME (not IP),
#   discovery is working correctly.

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2PublicIP
)

Write-Host "=== Validating Full CIM/WMI Discovery Path ===" -ForegroundColor Cyan
Write-Host "Target: $EC2PublicIP" -ForegroundColor White
Write-Host "`nEnter EC2 Windows credentials when prompted." -ForegroundColor Yellow
Write-Host "(Username: Administrator)" -ForegroundColor White

# Prompt for credentials
$cred = Get-Credential -Message "Enter EC2 Administrator credentials" -UserName "Administrator"

Write-Host "`n[1/3] Opening CIM session to EC2 over WinRM port 5985..." -ForegroundColor Yellow

try {
    $opt = New-CimSessionOption -Protocol Wsman
    $session = New-CimSession `
        -ComputerName $EC2PublicIP `
        -Port 5985 `
        -Credential $cred `
        -SessionOption $opt `
        -Authentication Basic `
        -ErrorAction Stop

    Write-Host "[OK] CIM session established successfully" -ForegroundColor Green

    # Query 1 — Operating system details
    Write-Host "`n[2/3] Querying Win32_OperatingSystem..." -ForegroundColor Yellow
    $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem -ErrorAction Stop
    Write-Host "[OK] OS Query succeeded:" -ForegroundColor Green
    Write-Host "     OS: $($os.Caption)" -ForegroundColor White
    Write-Host "     Version: $($os.Version)" -ForegroundColor White
    Write-Host "     Architecture: $($os.OSArchitecture)" -ForegroundColor White

    # Query 2 — Computer system details (hostname, domain)
    Write-Host "`n[3/3] Querying Win32_ComputerSystem..." -ForegroundColor Yellow
    $cs = Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem -ErrorAction Stop
    Write-Host "[OK] Computer System Query succeeded:" -ForegroundColor Green
    Write-Host "     Hostname: $($cs.Name)" -ForegroundColor White
    Write-Host "     Domain: $($cs.Domain)" -ForegroundColor White
    Write-Host "     RAM: $([math]::Round($cs.TotalPhysicalMemory/1GB, 2)) GB" -ForegroundColor White

    # Clean up session
    Remove-CimSession $session

    Write-Host "`n=== Validation PASSED ===" -ForegroundColor Green
    Write-Host "Both WMI queries returned data successfully." -ForegroundColor White
    Write-Host "You can now trigger discovery in the Azure Migrate portal." -ForegroundColor White
    Write-Host "`nExpected hostname in discovered machines list: $($cs.Name)" -ForegroundColor Cyan

} catch {
    Write-Host "`n=== Validation FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nCommon causes:" -ForegroundColor Yellow
    Write-Host "  - WinRM not configured on EC2 (run configure-winrm-ec2.ps1)" -ForegroundColor White
    Write-Host "  - UAC token filtering not fixed (LocalAccountTokenFilterPolicy)" -ForegroundColor White
    Write-Host "  - Port 5985 not open in AWS Security Group" -ForegroundColor White
    Write-Host "  - Wrong credentials entered" -ForegroundColor White
    Write-Host "  - HTTPS WinRM listener present with invalid cert (run fix-winrm-listener.ps1)" -ForegroundColor White
    Write-Host "`nDo not proceed with discovery until both queries return data." -ForegroundColor Red
}
