# Run all automated checks for Baigong Yaji.
# Usage:  powershell -File tools/run_tests.ps1 [-Snapshot]
param([switch]$Snapshot)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "== [1/3] Import & class cache ==" -ForegroundColor Cyan
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
godot --headless --import --path $root 2>&1 | Out-Null
$impCode = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
if ($impCode -ne 0) { Write-Host "Import failed" -ForegroundColor Red; exit 1 }

Write-Host "== [2/3] Main scene load check ==" -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
$out = godot --headless --quit --path $root 2>&1 | Out-String
$ErrorActionPreference = $prevEAP
if ($out -match "SCRIPT ERROR|Parse Error|Failed to load") {
    Write-Host $out -ForegroundColor Red; exit 1
}
Write-Host "OK"

Write-Host "== [3/3] Unit & simulation tests ==" -ForegroundColor Cyan
$failed = 0
Get-ChildItem -Path (Join-Path $root "tests") -Filter "test_*.gd" | ForEach-Object {
    Write-Host "-- $($_.Name)"
    godot --headless --path $root --script "res://tests/$($_.Name)"
    if ($LASTEXITCODE -ne 0) { $failed++ }
}

if ($Snapshot) {
    Write-Host "== Snapshots ==" -ForegroundColor Cyan
    godot --path $root --script "res://tools/snapshot.gd"
}

if ($failed -gt 0) { Write-Host "$failed test file(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
exit 0
