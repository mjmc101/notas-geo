<#
.SYNOPSIS
    Measures Notas & Avisos battery consumption using Android batterystats.

.DESCRIPTION
    1. Resets battery stats on the connected Android device
    2. Waits while you run the app in the background
    3. Dumps stats and prints a summary: GPS time, wakelocks, CPU, estimated power
    4. Saves a full dump you can upload to Battery Historian for deeper analysis

.PARAMETER Minutes
    How long to let the app run before sampling. Default: 5.
    Use at least 5 minutes for meaningful GPS data.

.EXAMPLE
    .\tools\battery_test.ps1
    .\tools\battery_test.ps1 -Minutes 10
#>
param([int]$Minutes = 5)

$Adb     = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$Package = "com.notasgeo.notas"

# Preflight

if (-not (Test-Path $Adb)) {
    Write-Error "adb not found at: $Adb"
    Write-Error "Install Android SDK Platform Tools and try again."
    exit 1
}

$devices = & $Adb devices 2>&1
if (($devices | Select-String "device$").Count -eq 0) {
    Write-Error "No Android device found. Connect your phone and enable USB debugging."
    exit 1
}

# Reset

Write-Host ""
Write-Host "=== Notas & Avisos - Battery consumption test ===" -ForegroundColor Cyan
Write-Host "Package  : $Package"
Write-Host "Duration : $Minutes minute(s)"
Write-Host ""

& $Adb shell dumpsys batterystats --reset | Out-Null
Write-Host "[1/3] Battery stats reset." -ForegroundColor Green

# Wait

Write-Host ""
Write-Host "Open the app on the device, lock the screen, and leave it running."
Write-Host "The test will sample automatically when the timer expires."
Write-Host ""

for ($remaining = $Minutes * 60; $remaining -gt 0; $remaining -= 15) {
    $mins = [math]::Floor($remaining / 60)
    $secs = $remaining % 60
    Write-Host ("  {0:00}:{1:00} remaining..." -f $mins, $secs)
    Start-Sleep -Seconds ([math]::Min(15, $remaining))
}

# Sample

Write-Host ""
Write-Host "[2/3] Sampling battery stats..." -ForegroundColor Green
$raw = & $Adb shell dumpsys batterystats $Package 2>&1

# Report

Write-Host ""
Write-Host "[3/3] Results" -ForegroundColor Green
Write-Host ("-" * 60)

function Show-Section($label, $lines) {
    if ($lines) {
        Write-Host ""
        Write-Host "  [$label]" -ForegroundColor Yellow
        $lines | ForEach-Object { Write-Host "    $_" }
    }
}

$gpsLines     = $raw | Select-String "gps"               -i | ForEach-Object { $_.Line.Trim() }
$wakeLines    = $raw | Select-String "wake_lock|wakelock" -i | ForEach-Object { $_.Line.Trim() }
$cpuLines     = $raw | Select-String "cpu="              -i | Select-Object -First 6 | ForEach-Object { $_.Line.Trim() }
$powerLines   = $raw | Select-String "power|mah"         -i | Select-Object -First 8 | ForEach-Object { $_.Line.Trim() }
$networkLines = $raw | Select-String "network"           -i | Select-Object -First 4 | ForEach-Object { $_.Line.Trim() }

Show-Section "GPS"       $gpsLines
Show-Section "Wakelocks" $wakeLines
Show-Section "CPU"       $cpuLines
Show-Section "Power"     $powerLines
Show-Section "Network"   $networkLines

if (-not ($gpsLines -or $wakeLines -or $cpuLines -or $powerLines)) {
    Write-Host ""
    Write-Host "  No data found for $Package." -ForegroundColor Red
    Write-Host "  Make sure the app was running during the measurement window."
    Write-Host "  You can inspect the full dump saved below."
}

# Guidance

$threshold = [math]::Round($Minutes * 0.05 * 60)

Write-Host ""
Write-Host ("-" * 60)
Write-Host ""
Write-Host "What to look for:" -ForegroundColor Cyan
Write-Host "  GPS active time  : should be under 5% of the ${Minutes}-min window (approx ${threshold}s)"
Write-Host "  Wakelock duration: foreground service wakelock is expected; others flag issues"
Write-Host "  Estimated power  : under 5 mAh per hour is typical for this type of service"
Write-Host ""
Write-Host "Red flags:" -ForegroundColor Red
Write-Host "  GPS on for over 20% of the time  -> stream accuracy may be too high (check LocationConfig)"
Write-Host "  Many short wakelocks             -> stream interval may be too short"
Write-Host "  CPU spikes every few seconds     -> a timer or stream is firing too often"

# Save full dump

Write-Host ""
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dumpFile = "battery_dump_${timestamp}.txt"
$raw | Out-File -FilePath $dumpFile -Encoding utf8
Write-Host "Full dump saved to: $dumpFile" -ForegroundColor Green
Write-Host "Upload to https://bathist.ef.lc/ for an interactive timeline."
Write-Host ""
