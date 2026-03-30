param(
    [string]$LatencyCsvPath = ".\\artifacts\\hardware\\latency_samples.csv",
    [double]$LatencyTargetMs = 50.0
)

$ErrorActionPreference = "Stop"

Write-Host "" 
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Board Sign-off Runner" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path ".\\verify_all.ps1")) {
    Write-Error "verify_all.ps1 not found in workspace root."
}

Write-Host "[1/3] Running strict pre-demo verification..." -ForegroundColor Yellow
$env:STRICT_SIM = "1"
& .\\verify_all.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Strict verification failed. Stop and resolve before board sign-off."
}

Write-Host "" 
Write-Host "[2/3] Running latency summary..." -ForegroundColor Yellow
if (-not (Test-Path ".\\scripts\\hardware\\latency_summary.ps1")) {
    Write-Error "Missing scripts/hardware/latency_summary.ps1"
}

& .\\scripts\\hardware\\latency_summary.ps1 -CsvPath $LatencyCsvPath -TargetMs $LatencyTargetMs
$latencyExit = $LASTEXITCODE

Write-Host "" 
Write-Host "[3/3] Generating sign-off report..." -ForegroundColor Yellow
if (-not (Test-Path ".\\scripts\\hardware\\generate_signoff_report.ps1")) {
    Write-Error "Missing scripts/hardware/generate_signoff_report.ps1"
}
& .\\scripts\\hardware\\generate_signoff_report.ps1 -LatencyCsvPath $LatencyCsvPath -LatencyTargetMs $LatencyTargetMs

Write-Host ""
if ($latencyExit -eq 0) {
    Write-Host "Board sign-off runner complete. Latency summary met target (or data marked valid pass)." -ForegroundColor Green
} else {
    Write-Host "Board sign-off runner complete, but latency summary did not meet target or data is not valid yet." -ForegroundColor Yellow
}

Write-Host "Artifacts:" -ForegroundColor Cyan
Write-Host "- artifacts/hardware/latency_samples.csv"
Write-Host "- artifacts/hardware/signoff_report.md"
Write-Host "- artifacts/hardware/demo_checklist_log.md"

if ($latencyExit -ne 0) {
    Write-Host "Latency validation failed. Board sign-off is NOT complete." -ForegroundColor Red
    exit 1
}

exit 0
