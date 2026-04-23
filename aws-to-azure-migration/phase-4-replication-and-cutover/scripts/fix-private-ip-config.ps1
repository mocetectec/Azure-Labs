# Run this on the EC2 source instance in an elevated PowerShell session.
# Finds and replaces the hardcoded private Azure IP in the mobility agent
# configuration files, then restarts the mobility services.
#
# Why this is needed:
#   During mobility service installation, the agent writes the replication
#   appliance IP address into several JSON configuration files. If the
#   appliance registered itself using its private Azure IP (e.g. 10.1.1.x),
#   that private IP gets hardcoded into the agent config on the EC2. The
#   agent then connects directly to that IP - bypassing DNS entirely, so
#   a hosts file entry cannot fix this.
#
#   Without a VPN between AWS and Azure, the private IP is unreachable
#   and replication fails to initialize. The config files must be patched
#   directly and the mobility services restarted.
#
#   This issue is not documented by Microsoft.
#
# Usage:
#   .\fix-private-ip-config.ps1 -PrivateIP "10.1.1.5" -PublicIP "20.x.x.x"

param(
    [Parameter(Mandatory=$true)]
    [string]$PrivateIP,

    [Parameter(Mandatory=$true)]
    [string]$PublicIP
)

$asrPath     = "C:\Program Files (x86)\Microsoft Azure Site Recovery"
$logPath = Get-ChildItem "$asrPath\agent" -Filter "svagents_curr_*.log" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

Write-Host "=== Mobility Agent Private IP Config Fix ===" -ForegroundColor Cyan
Write-Host "Searching for : $PrivateIP" -ForegroundColor White
Write-Host "Replacing with: $PublicIP" -ForegroundColor White

# Step 1 - Find all config files containing the private IP
Write-Host "`n[1/4] Scanning ASR config files for hardcoded private IP..." -ForegroundColor Yellow

$affectedFiles = Get-ChildItem $asrPath -Recurse `
    -Include "*.conf","*.json","*.ini","*.xml","*.txt" `
    -ErrorAction SilentlyContinue |
    Select-String -Pattern ([regex]::Escape($PrivateIP)) |
    Select-Object -ExpandProperty Path -Unique

if (-not $affectedFiles) {
    Write-Host "[INFO] No files found containing $PrivateIP" -ForegroundColor Yellow
    Write-Host "    Either the IP was already replaced or the path is different" -ForegroundColor White
    Write-Host "    Check the agent log for connection attempts:" -ForegroundColor White
    Write-Host "    Get-Content `"$logPath`" -Tail 20" -ForegroundColor White
    exit 0
}

Write-Host "[FOUND] Files containing $PrivateIP :" -ForegroundColor Red
$affectedFiles | ForEach-Object { Write-Host "    $_" -ForegroundColor White }

# Step 2 - Replace private IP with public IP in all affected files
Write-Host "`n[2/4] Replacing $PrivateIP with $PublicIP in affected files..." -ForegroundColor Yellow

foreach ($file in $affectedFiles) {
    try {
        $content = Get-Content $file -Raw
        $updated = $content -replace ([regex]::Escape($PrivateIP)), $PublicIP
        Set-Content $file -Value $updated
        Write-Host "    [OK] Updated: $file" -ForegroundColor Green
    } catch {
        Write-Host "    [ERROR] Failed to update $file : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 3 - Verify no private IP remains
Write-Host "`n[3/4] Verifying replacement - scanning for remaining instances..." -ForegroundColor Yellow

$remaining = Get-ChildItem $asrPath -Recurse `
    -Include "*.conf","*.json","*.ini","*.xml","*.txt" `
    -ErrorAction SilentlyContinue |
    Select-String -Pattern ([regex]::Escape($PrivateIP))

if ($remaining) {
    Write-Host "[WARNING] Private IP still found in the following files:" -ForegroundColor Red
    $remaining | ForEach-Object { Write-Host "    $($_.Path) line $($_.LineNumber): $($_.Line)" -ForegroundColor White }
} else {
    Write-Host "[OK] No remaining instances of $PrivateIP found" -ForegroundColor Green
}

# Step 4 - Restart mobility services
Write-Host "`n[4/4] Restarting mobility services..." -ForegroundColor Yellow

$services = @("InMage Scout Application Service", "svagents")

foreach ($svc in $services) {
    try {
        Get-Service -Name $svc -ErrorAction Stop | Out-Null
        Restart-Service -Name $svc -Force -ErrorAction Stop
        Start-Sleep -Seconds 5
        $status = (Get-Service -Name $svc).Status
        Write-Host "    [OK] $svc - $status" -ForegroundColor Green
    } catch {
        Write-Host "    [WARNING] Could not restart $svc - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Final - Watch log for successful connections
Write-Host "`n=== Fix Applied ===" -ForegroundColor Cyan
Write-Host "Watching agent log for connection attempts to $PublicIP..." -ForegroundColor White
Write-Host "Press Ctrl+C to stop watching" -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 3

try {
    Get-Content $logPath -Tail 20 -Wait | Where-Object {
        $_ -match $PublicIP -or $_ -match $PrivateIP -or $_ -match "Connected" -or $_ -match "Error"
    } | ForEach-Object {
        if ($_ -match $PrivateIP) {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match $PublicIP) {
            Write-Host $_ -ForegroundColor Green
        } else {
            Write-Host $_ -ForegroundColor White
        }
    }
} catch {
    Write-Host "Log file not found at $logPath" -ForegroundColor Yellow
    Write-Host "Check: Get-ChildItem `"$asrPath\agent`" -Filter `"*.log`"" -ForegroundColor White
}
