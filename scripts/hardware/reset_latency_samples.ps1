$ErrorActionPreference = "Stop"

$csvPath = ".\\artifacts\\hardware\\latency_samples.csv"
$outDir = Split-Path -Parent $csvPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

"sample_id,key_id,latency_ms,tool,confidence,notes" | Set-Content -Path $csvPath -Encoding ASCII
Write-Host ("Reset latency CSV to header-only template at {0}" -f $csvPath) -ForegroundColor Green
