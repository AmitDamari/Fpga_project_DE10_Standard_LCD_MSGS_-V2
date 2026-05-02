# =============================================================================
# run_pre_board_verification.ps1
# Full pre-board verification gate:
#   1) simulator preflight
#   2) canonical + optional legacy regression
#   3) waveform numeric checks
#   4) critical event extraction
#   5) Quartus netlist compatibility generation
#   6) GTKWave readiness / optional launch
# =============================================================================

param(
    [bool]$IncludeLegacy = $true,
    [bool]$GenerateQuartusNetlist = $true,
    [switch]$LaunchGtkWave,
    [switch]$RequireGtkWave,
    [string]$GtkWaveExe = "gtkwave",
    [string]$GtkWaveSaveFile = "sim/gtkw/tb_fpga_msg_controller_critical.gtkw",
    [string]$FocusVcd = "sim/results/tb_fpga_msg_controller.vcd"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$ROOT = Split-Path -Parent $PSScriptRoot
$RESULTS = Join-Path $ROOT "sim\results"
$REPORT_PATH = Join-Path $RESULTS "pre_board_verification_report.md"
$REG_LOG = Join-Path $RESULTS "pre_board_regression.log"
$WAVE_LOG = Join-Path $RESULTS "pre_board_wave_analysis.log"
$Q_LOG = Join-Path $RESULTS "pre_board_quartus_netlist.log"
$EVENTS_PATH = Join-Path $RESULTS "critical_events_timeline.txt"

$CHECKS = New-Object System.Collections.Generic.List[object]
$startTime = Get-Date

New-Item -ItemType Directory -Force -Path $RESULTS | Out-Null

function Add-Check {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Details
    )

    $CHECKS.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Details = $Details
    }) | Out-Null
}

function Resolve-Executable {
    param([string]$NameOrPath)

    if (Test-Path $NameOrPath) {
        return (Resolve-Path $NameOrPath).Path
    }

    $cmd = Get-Command $NameOrPath -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Save-And-Echo {
    param(
        [string]$Path,
        [object[]]$Lines
    )

    $Lines | Set-Content -Path $Path -Encoding ascii
    $Lines | ForEach-Object { Write-Host $_ }
}

$hasFailure = $false

# -----------------------------------------------------------------------------
# Step 1: Preflight
# -----------------------------------------------------------------------------
$preflight = Join-Path $ROOT "sim\check_sim_env.ps1"
try {
    $null = & $preflight 2>&1
    $preflightExit = $LASTEXITCODE
    if ($preflightExit -eq 0) {
        Add-Check -Name "Simulator preflight" -Status "PASS" -Details "sim/check_sim_env.ps1 passed"
    } else {
        Add-Check -Name "Simulator preflight" -Status "FAIL" -Details "sim/check_sim_env.ps1 exit=$preflightExit"
        $hasFailure = $true
    }
}
catch {
    Add-Check -Name "Simulator preflight" -Status "FAIL" -Details $_.Exception.Message
    $hasFailure = $true
}

# -----------------------------------------------------------------------------
# Step 2: Full regression
# -----------------------------------------------------------------------------
if (-not $hasFailure) {
    if ($IncludeLegacy) {
        $env:RUN_LEGACY = "1"
    } else {
        Remove-Item Env:RUN_LEGACY -ErrorAction SilentlyContinue
    }

    $simRunner = Join-Path $ROOT "sim\run_all_sim.ps1"
    $simOut = & $simRunner 2>&1
    $simExit = $LASTEXITCODE
    Save-And-Echo -Path $REG_LOG -Lines $simOut

    if ($simExit -eq 0) {
        Add-Check -Name "RTL regression" -Status "PASS" -Details "run_all_sim.ps1 passed (legacy=$IncludeLegacy)"
    } else {
        Add-Check -Name "RTL regression" -Status "FAIL" -Details "run_all_sim.ps1 exit=$simExit (legacy=$IncludeLegacy)"
        $hasFailure = $true
    }
}

# -----------------------------------------------------------------------------
# Step 3: Waveform numeric checks
# -----------------------------------------------------------------------------
if (-not $hasFailure) {
    $waveRunner = Join-Path $ROOT "sim\run_wave_analysis.ps1"
    $waveOut = & $waveRunner -SkipRegression 2>&1
    $waveExit = $LASTEXITCODE
    Save-And-Echo -Path $WAVE_LOG -Lines $waveOut

    if ($waveExit -eq 0) {
        Add-Check -Name "Waveform numeric checks" -Status "PASS" -Details "run_wave_analysis.ps1 PASS"
    } else {
        Add-Check -Name "Waveform numeric checks" -Status "FAIL" -Details "run_wave_analysis.ps1 exit=$waveExit"
        $hasFailure = $true
    }
}

# -----------------------------------------------------------------------------
# Step 4: Extract critical event timeline
# -----------------------------------------------------------------------------
if (-not $hasFailure) {
    $extractor = Join-Path $ROOT "sim\extract_vcd_events.ps1"
    if (Test-Path $extractor) {
        $eventOut = & $extractor
        $eventOut | Set-Content -Path $EVENTS_PATH -Encoding ascii
        Add-Check -Name "Event timeline extraction" -Status "PASS" -Details "critical_events_timeline.txt generated"
    } else {
        Add-Check -Name "Event timeline extraction" -Status "WARN" -Details "sim/extract_vcd_events.ps1 not found"
    }
}

# -----------------------------------------------------------------------------
# Step 5: Quartus netlist compatibility
# -----------------------------------------------------------------------------
if (-not $hasFailure -and $GenerateQuartusNetlist) {
    $qRunner = Join-Path $ROOT "sim\run_quartus_questa_sim.ps1"
    $qOut = & $qRunner -GenerateQuartusNetlist -NetlistOnly 2>&1
    $qExit = $LASTEXITCODE
    Save-And-Echo -Path $Q_LOG -Lines $qOut

    if ($qExit -eq 0) {
        Add-Check -Name "Quartus netlist compatibility" -Status "PASS" -Details "run_quartus_questa_sim.ps1 -GenerateQuartusNetlist -NetlistOnly passed"
    } else {
        Add-Check -Name "Quartus netlist compatibility" -Status "FAIL" -Details "run_quartus_questa_sim.ps1 exit=$qExit"
        $hasFailure = $true
    }
}

# -----------------------------------------------------------------------------
# Step 6: GTKWave readiness and optional launch
# -----------------------------------------------------------------------------
$gtkExeResolved = Resolve-Executable -NameOrPath $GtkWaveExe
$savePath = Join-Path $ROOT $GtkWaveSaveFile
$vcdPath = Join-Path $ROOT $FocusVcd

if ($gtkExeResolved) {
    Add-Check -Name "GTKWave executable" -Status "PASS" -Details $gtkExeResolved
} else {
    if ($RequireGtkWave) {
        Add-Check -Name "GTKWave executable" -Status "FAIL" -Details "gtkwave not found in PATH and GtkWaveExe path not valid"
        $hasFailure = $true
    } else {
        Add-Check -Name "GTKWave executable" -Status "WARN" -Details "gtkwave not found in PATH; set -GtkWaveExe to full path"
    }
}

if (Test-Path $savePath) {
    Add-Check -Name "GTKWave savefile" -Status "PASS" -Details $savePath
} else {
    Add-Check -Name "GTKWave savefile" -Status "FAIL" -Details "$savePath missing"
    $hasFailure = $true
}

if (Test-Path $vcdPath) {
    Add-Check -Name "Focus VCD artifact" -Status "PASS" -Details $vcdPath
} else {
    Add-Check -Name "Focus VCD artifact" -Status "FAIL" -Details "$vcdPath missing"
    $hasFailure = $true
}

if ($LaunchGtkWave) {
    if ($gtkExeResolved -and (Test-Path $savePath) -and (Test-Path $vcdPath)) {
        Start-Process -FilePath $gtkExeResolved -ArgumentList @($vcdPath, "-a", $savePath)
        Add-Check -Name "GTKWave launch" -Status "PASS" -Details "Launched GTKWave with focus VCD and critical savefile"
    } else {
        Add-Check -Name "GTKWave launch" -Status "FAIL" -Details "Cannot launch due to missing executable/savefile/VCD"
        $hasFailure = $true
    }
} else {
    Add-Check -Name "GTKWave launch" -Status "PASS" -Details "Skipped (use -LaunchGtkWave to open interactive waveform view)"
}

$endTime = Get-Date
$duration = New-TimeSpan -Start $startTime -End $endTime

$overall = if ($hasFailure) { "FAIL" } else { "PASS" }

$report = @()
$report += "# Pre-Board Verification Report"
$report += ""
$report += "- Start: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
$report += "- End: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
$report += "- Duration: $([int]$duration.TotalMinutes)m $($duration.Seconds)s"
$report += "- Overall: **$overall**"
$report += ""
$report += "## Check Results"
$report += "| Check | Status | Details |"
$report += "|---|---|---|"
foreach ($c in $CHECKS) {
    $report += "| $($c.Name) | $($c.Status) | $($c.Details) |"
}
$report += ""
$report += "## Artifacts"
$report += "- Regression log: sim/results/pre_board_regression.log"
$report += "- Wave analysis log: sim/results/pre_board_wave_analysis.log"
$report += "- Wave analysis report: sim/results/wave_analysis_report.md"
$report += "- Event timeline: sim/results/critical_events_timeline.txt"
$report += "- Quartus netlist log: sim/results/pre_board_quartus_netlist.log"
$report += "- GTKWave critical savefile: sim/gtkw/tb_fpga_msg_controller_critical.gtkw"
$report += ""
$report += "## GTKWave Open Command"
$report += "- .\\sim\\run_pre_board_verification.ps1 -LaunchGtkWave"

$report | Set-Content -Path $REPORT_PATH -Encoding ascii
Write-Host "Pre-board report: $REPORT_PATH" -ForegroundColor Cyan

if ($hasFailure) {
    exit 1
}

exit 0
