param(
    [Parameter(Mandatory = $true)]
    [string]$SampleId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("KEY0", "KEY1", "KEY2", "KEY3")]
    [string]$KeyId,

    [Parameter(Mandatory = $true)]
    [double]$LatencyMs,

    [string]$Tool = "scope",
    [string]$Confidence = "HIGH",
    [string]$Notes = "",
    [switch]$KeepTemplateRows
)

$ErrorActionPreference = "Stop"

$csvPath = ".\\artifacts\\hardware\\latency_samples.csv"
$outDir = Split-Path -Parent $csvPath
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if (-not (Test-Path $csvPath)) {
    "sample_id,key_id,latency_ms,tool,confidence,notes" | Set-Content -Path $csvPath -Encoding ASCII
}

if ($Notes -match "replace_with_real_measurement") {
    Write-Error "Notes cannot contain placeholder marker text. Use real measurement notes."
}

# Remove seeded template rows unless explicitly requested to keep them.
if (-not $KeepTemplateRows) {
    $existing = @()
    if (Test-Path $csvPath) {
        $existing = Import-Csv -Path $csvPath
    }

    if ($existing.Count -gt 0) {
        $filtered = @($existing | Where-Object { $_.notes -notmatch "replace_with_real_measurement" })
        if ($filtered.Count -ne $existing.Count) {
            $filtered | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "Removed placeholder template rows from latency CSV." -ForegroundColor Yellow
        }
    }
}

$row = [PSCustomObject]@{
    sample_id  = $SampleId
    key_id     = $KeyId
    latency_ms = $LatencyMs
    tool       = $Tool
    confidence = $Confidence
    notes      = $Notes
}

$row | Export-Csv -Path $csvPath -NoTypeInformation -Append
Write-Host ("Added latency sample {0} ({1}, {2} ms) to {3}" -f $SampleId, $KeyId, $LatencyMs, $csvPath) -ForegroundColor Green
