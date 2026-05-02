# =============================================================================
# run_quartus_questa_sim.ps1
# Runs canonical simulation suites using Quartus 21.1 bundled Questa (questa_fse).
# Optional: generate Quartus EDA simulation netlist before running RTL suites.
# =============================================================================

param(
    [string]$QuestaExe = "C:\intelFPGA_lite\21.1\questa_fse\win64\vsim.exe",
    [switch]$IncludeLegacy,
    [switch]$GenerateQuartusNetlist,
    [switch]$NetlistOnly
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$ROOT = Split-Path -Parent $PSScriptRoot
$RESULTS = Join-Path $ROOT "sim\results"
$RUN_TCL = Join-Path $ROOT "sim\scripts\run_sim.tcl"
$QUARTUS_DIR = Join-Path $ROOT "hw\quartus"
$QSF_PATH = Join-Path $QUARTUS_DIR "DE10_Standard_GHRD.qsf"

New-Item -ItemType Directory -Force -Path $RESULTS | Out-Null

function Invoke-QuartusNetlistGeneration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$QuartusDir
    )

    $quartusEda = "C:\intelFPGA_lite\21.1\quartus\bin64\quartus_eda.exe"
    if (-not (Test-Path $quartusEda)) {
        Write-Host "ERROR: quartus_eda.exe not found at $quartusEda" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $QSF_PATH)) {
        Write-Host "ERROR: Missing QSF file at $QSF_PATH" -ForegroundColor Red
        exit 1
    }

    # quartus_eda may append EDA assignments into QSF; preserve and restore file byte-for-byte.
    $qsfBackupPath = [System.IO.Path]::Combine($env:TEMP, ("DE10_Standard_GHRD.qsf.backup.{0}.tmp" -f [System.Guid]::NewGuid().ToString("N")))
    Copy-Item -Path $QSF_PATH -Destination $qsfBackupPath -Force

    Write-Host "Generating Quartus EDA simulation netlist (questa_oem/verilog)..." -ForegroundColor Cyan
    Push-Location $QuartusDir
    try {
        & $quartusEda DE10_Standard_GHRD -c DE10_Standard_GHRD --simulation --tool=questa_oem --format=verilog --output_directory=sim\eda_questa
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: quartus_eda simulation netlist generation failed (exit $LASTEXITCODE)." -ForegroundColor Red
            exit 1
        }
    }
    finally {
        Pop-Location
        Copy-Item -Path $qsfBackupPath -Destination $QSF_PATH -Force
        Remove-Item -Path $qsfBackupPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $RUN_TCL)) {
    Write-Host "ERROR: Missing run script: $RUN_TCL" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $QuestaExe)) {
    $vsimCmd = Get-Command "vsim" -ErrorAction SilentlyContinue
    if ($vsimCmd) {
        $QuestaExe = $vsimCmd.Source
    } else {
        Write-Host "ERROR: Questa executable not found." -ForegroundColor Red
        Write-Host "Looked for: $QuestaExe" -ForegroundColor Red
        Write-Host "Install/enable Quartus 21.1 Questa FSE or provide -QuestaExe path." -ForegroundColor Yellow
        exit 1
    }
}

if ($IncludeLegacy) {
    $env:RUN_LEGACY = "1"
    Write-Host "Legacy suites enabled (RUN_LEGACY=1)." -ForegroundColor Cyan
} else {
    Remove-Item Env:RUN_LEGACY -ErrorAction SilentlyContinue
}

if ($GenerateQuartusNetlist) {
    Invoke-QuartusNetlistGeneration -QuartusDir $QUARTUS_DIR
}

if ($NetlistOnly) {
    if (-not $GenerateQuartusNetlist) {
        Write-Host "-NetlistOnly requested without -GenerateQuartusNetlist; generating netlist now." -ForegroundColor Cyan
        $GenerateQuartusNetlist = $true

        Invoke-QuartusNetlistGeneration -QuartusDir $QUARTUS_DIR
    }

    Write-Host "Netlist-only mode complete. Skipping Questa execution." -ForegroundColor Green
    Write-Host "Expected output: hw/quartus/sim/eda_questa/DE10_Standard_GHRD.vo" -ForegroundColor Green
    exit 0
}

Write-Host "Running canonical suites in Questa: $QuestaExe" -ForegroundColor Cyan
Push-Location $ROOT
try {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $QuestaExe -c -do $RUN_TCL 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
}
finally {
    $ErrorActionPreference = "Stop"
    Pop-Location
}

$logPath = Join-Path $RESULTS "questa_regression.log"
$output | Set-Content -Path $logPath -Encoding ascii
$output | ForEach-Object { Write-Host $_ }

if ($exitCode -ne 0) {
    $combined = $output -join "`n"
    if ($combined -match "Unable to checkout a license") {
        Write-Host "ERROR: Questa license checkout failed." -ForegroundColor Red
        Write-Host "Set LM_LICENSE_FILE to a valid Questa/Quartus license or run with -GenerateQuartusNetlist -NetlistOnly." -ForegroundColor Yellow
        Write-Host "Log: $logPath" -ForegroundColor Yellow
        exit 2
    }

    Write-Host "ERROR: Questa returned non-zero exit code: $exitCode" -ForegroundColor Red
    Write-Host "Log: $logPath" -ForegroundColor Yellow
    exit $exitCode
}

$combined = $output -join "`n"
$failRegex = "SOME TESTS FAILED|FAIL Test \d|\[FAIL\]|FAILURES DETECTED|\[PULSE WIDTH ERROR\]|(^|[^a-z])assert(?:ion)?([^a-z]|$)|\*\*\* SOME TESTS FAILED \*\*\*"
$hasFailures = [regex]::IsMatch($combined, $failRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

if ($hasFailures) {
    Write-Host "ERROR: Failure markers detected in Questa transcript." -ForegroundColor Red
    Write-Host "Log: $logPath" -ForegroundColor Yellow
    exit 1
}

$passBanners = [regex]::Matches(
    $combined,
    "\*\*\* ALL TESTS PASSED \*\*\*",
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
).Count

Write-Host "Questa regression completed successfully." -ForegroundColor Green
Write-Host "Detected PASS banners: $passBanners" -ForegroundColor Green
Write-Host "Log: $logPath" -ForegroundColor Green
exit 0
