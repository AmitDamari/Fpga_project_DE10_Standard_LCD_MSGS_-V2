param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [double]$TargetMs = 50.0
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV not found: $CsvPath"
}

$rows = Import-Csv -Path $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
    Write-Error "CSV has no data rows."
}

$samples = @()
$placeholderDetected = $false
foreach ($r in $rows) {
    if (-not $r.latency_ms) { continue }
    if ($r.notes -and ($r.notes -match "replace_with_real_measurement")) {
        $placeholderDetected = $true
    }
    $v = 0.0
    if ([double]::TryParse($r.latency_ms, [ref]$v)) {
        $samples += $v
    }
}

if ($samples.Count -eq 0) {
    Write-Error "No valid numeric latency_ms values found."
}

$measure = $samples | Measure-Object -Average -Minimum -Maximum
$mean = [math]::Round($measure.Average, 3)
$min  = [math]::Round($measure.Minimum, 3)
$max  = [math]::Round($measure.Maximum, 3)
$allZero = ($samples | Where-Object { $_ -ne 0 }).Count -eq 0

$overTarget = @($samples | Where-Object { $_ -gt $TargetMs })
$pass = ($max -le $TargetMs)

Write-Host ""
Write-Host "================ Latency Summary ================" -ForegroundColor Cyan
Write-Host ("Samples: {0}" -f $samples.Count)
Write-Host ("Target : <= {0} ms" -f $TargetMs)
Write-Host ("Mean   : {0} ms" -f $mean)
Write-Host ("Min    : {0} ms" -f $min)
Write-Host ("Max    : {0} ms" -f $max)
Write-Host ("Over target count: {0}" -f $overTarget.Count)

if ($placeholderDetected -or $allZero) {
    Write-Host "RESULT: INVALID (template or synthetic sample data detected)" -ForegroundColor Yellow
    Write-Host "Replace placeholder rows with real board measurements before sign-off." -ForegroundColor Yellow
    exit 1
}

if ($pass) {
    Write-Host "RESULT: PASS (max latency within target)" -ForegroundColor Green
    exit 0
}

Write-Host "RESULT: FAIL (max latency exceeds target)" -ForegroundColor Red
Write-Host "Consider checking HPS load and LCD update path for jitter sources." -ForegroundColor Yellow
exit 1
