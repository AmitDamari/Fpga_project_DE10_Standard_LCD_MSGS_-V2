# =============================================================================
# run_wave_analysis.ps1
# Runs canonical simulations (optional) and performs automated VCD checks.
# Focus VCD: sim/results/tb_fpga_msg_controller.vcd
# =============================================================================

param(
    [string]$VcdPath,
    [string]$ReportPath,
    [switch]$SkipRegression
)

$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent $PSScriptRoot
$RESULTS = Join-Path $ROOT "sim\results"

if ([string]::IsNullOrWhiteSpace($VcdPath)) {
    $VcdPath = Join-Path $RESULTS "tb_fpga_msg_controller.vcd"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $RESULTS "wave_analysis_report.md"
}

function Add-IcarusPathIfPresent {
    $icarusBin = "C:\iverilog\bin"
    if (-not (Test-Path $icarusBin)) {
        return
    }
    $parts = $env:Path -split ';'
    if ($parts -contains $icarusBin) {
        return
    }
    $env:Path = "$icarusBin;" + $env:Path
}

function Get-NormalizedBits {
    param(
        [string]$Bits,
        [int]$Width
    )

    $clean = ($Bits.ToLower() -replace '[^01xz]', '')
    if ($clean.Length -lt $Width) {
        return ("0" * ($Width - $clean.Length)) + $clean
    }
    if ($clean.Length -gt $Width) {
        return $clean.Substring($clean.Length - $Width)
    }
    return $clean
}

function Test-VectorActive {
    param([string]$Bits)
    return ($Bits -match '1')
}

function ConvertTo-BitInteger {
    param([string]$Bits)

    if ($Bits -notmatch '^[01]+$') {
        return $null
    }
    return [Convert]::ToInt32($Bits, 2)
}

Add-IcarusPathIfPresent

if (-not $SkipRegression) {
    $simRunner = Join-Path $ROOT "sim\run_all_sim.ps1"
    Write-Host "Running canonical simulation regression before waveform analysis..." -ForegroundColor Cyan
    & $simRunner
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: canonical regression failed. Waveform analysis aborted." -ForegroundColor Red
        exit 1
    }
}

if (-not (Test-Path $VcdPath)) {
    Write-Host "ERROR: VCD file not found: $VcdPath" -ForegroundColor Red
    exit 1
}

$requiredVcds = @(
    "tb_button_debouncer.vcd",
    "tb_button_edge_detector.vcd",
    "tb_idle_timer.vcd",
    "tb_hex_display.vcd",
    "tb_message_fsm.vcd",
    "tb_fpga_msg_controller.vcd",
    "tb_top_level.vcd"
)

$missingVcds = @()
foreach ($name in $requiredVcds) {
    $p = Join-Path $RESULTS $name
    if (-not (Test-Path $p)) {
        $missingVcds += $name
    }
}

$ids = @{
    clk = $null
    btn_pulse = $null
    timeout_flag = $null
    fsm_state = $null
}

$timescale = "unknown"
$inDefinitions = $true
$currentTime = 0L
$lastTime = 0L

$clkValue = "x"
$btnValue = "0000"
$timeoutValue = "x"

$clkRisingTimes = New-Object System.Collections.Generic.List[long]
$btnPulseIntervals = New-Object System.Collections.Generic.List[object]
$fsmVisited = New-Object System.Collections.Generic.HashSet[int]
$timeoutRiseCount = 0

$btnActive = $false
$btnActiveStart = 0L

$reader = [System.IO.File]::OpenText($VcdPath)
try {
    while ($true) {
        $line = $reader.ReadLine()
        if ($null -eq $line) {
            break
        }

        if ($inDefinitions) {
            if ($line -match '^\$timescale\s*$') {
                $ts = $reader.ReadLine()
                if ($null -ne $ts) {
                    $timescale = $ts.Trim()
                }
                # consume trailing "$end" line in the timescale block
                $null = $reader.ReadLine()
                continue
            }
            if (($null -eq $ids.clk) -and ($line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+clk(?:\s|\[|$)')) {
                $ids.clk = $matches[1]
                continue
            }
            if (($null -eq $ids.btn_pulse) -and ($line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+btn_pulse(?:\s|\[|$)')) {
                $ids.btn_pulse = $matches[1]
                continue
            }
            if (($null -eq $ids.timeout_flag) -and ($line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+timeout_flag(?:\s|\[|$)')) {
                $ids.timeout_flag = $matches[1]
                continue
            }
            if (($null -eq $ids.fsm_state) -and ($line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+fsm_state(?:\s|\[|$)')) {
                $ids.fsm_state = $matches[1]
                continue
            }
            if ($line -match '^\$enddefinitions\s+\$end$') {
                $inDefinitions = $false
                continue
            }
            continue
        }

        if ($line -match '^#(\d+)$') {
            $currentTime = [int64]$matches[1]
            if ($currentTime -gt $lastTime) {
                $lastTime = $currentTime
            }
            continue
        }

        if ($line -match '^b([01xXzZ]+)\s+(\S+)$') {
            $bits = $matches[1]
            $id = $matches[2]

            if ($id -eq $ids.btn_pulse) {
                $old = $btnValue
                $btnValue = Get-NormalizedBits -Bits $bits -Width 4

                $wasActive = Test-VectorActive -Bits $old
                $isActive = Test-VectorActive -Bits $btnValue

                if ((-not $wasActive) -and $isActive) {
                    $btnActive = $true
                    $btnActiveStart = $currentTime
                } elseif ($wasActive -and (-not $isActive)) {
                    $btnPulseIntervals.Add([PSCustomObject]@{
                        Start = $btnActiveStart
                        End = $currentTime
                    })
                    $btnActive = $false
                } elseif ($wasActive -and $isActive -and ($old -ne $btnValue)) {
                    # Treat value change while active as pulse boundary.
                    $btnPulseIntervals.Add([PSCustomObject]@{
                        Start = $btnActiveStart
                        End = $currentTime
                    })
                    $btnActiveStart = $currentTime
                }
                continue
            }

            if ($id -eq $ids.fsm_state) {
                $fsmBits = Get-NormalizedBits -Bits $bits -Width 3
                $fsmInt = ConvertTo-BitInteger -Bits $fsmBits
                if ($null -ne $fsmInt) {
                    $null = $fsmVisited.Add($fsmInt)
                }
                continue
            }

            continue
        }

        if ($line -match '^([01xXzZ])(\S+)$') {
            $value = $matches[1].ToLower()
            $id = $matches[2]

            if ($id -eq $ids.clk) {
                if (($clkValue -ne '1') -and ($value -eq '1')) {
                    $clkRisingTimes.Add($currentTime)
                }
                $clkValue = $value
                continue
            }

            if ($id -eq $ids.timeout_flag) {
                if (($timeoutValue -ne '1') -and ($value -eq '1')) {
                    $timeoutRiseCount++
                }
                $timeoutValue = $value
                continue
            }
        }
    }
}
finally {
    $reader.Close()
}

if ($btnActive) {
    $btnPulseIntervals.Add([PSCustomObject]@{
        Start = $btnActiveStart
        End = $lastTime
    })
}

$clockPeriod = 0L
if ($clkRisingTimes.Count -ge 2) {
    $clockPeriod = $clkRisingTimes[1] - $clkRisingTimes[0]
}

$pulseViolations = @()
if ($clockPeriod -gt 0) {
    foreach ($pulse in $btnPulseIntervals) {
        $width = [int64]($pulse.End - $pulse.Start)
        if ($width -ne $clockPeriod) {
            $pulseViolations += ("start={0} end={1} width={2}" -f $pulse.Start, $pulse.End, $width)
        }
    }
}

$requiredStates = @(1, 2, 3, 4)  # IDLE, HOME, MSG, SLEEP
$missingStates = @()
foreach ($state in $requiredStates) {
    if (-not $fsmVisited.Contains($state)) {
        $missingStates += $state
    }
}

$idsMissing = @()
foreach ($k in $ids.Keys) {
    if ([string]::IsNullOrWhiteSpace($ids[$k])) {
        $idsMissing += $k
    }
}

$analysisPassed = ($idsMissing.Count -eq 0) -and
                  ($missingVcds.Count -eq 0) -and
                  ($clockPeriod -gt 0) -and
                  ($timeoutRiseCount -ge 1) -and
                  ($pulseViolations.Count -eq 0) -and
                  ($missingStates.Count -eq 0)

$stateNames = @{
    0 = "INIT"
    1 = "IDLE"
    2 = "HOME"
    3 = "MSG"
    4 = "SLEEP"
}

$visitedStateNames = @()
foreach ($s in $fsmVisited) {
    if ($stateNames.ContainsKey($s)) {
        $visitedStateNames += ("{0}({1})" -f $stateNames[$s], $s)
    } else {
        $visitedStateNames += ("UNKNOWN({0})" -f $s)
    }
}
$visitedStateNames = $visitedStateNames | Sort-Object

$reportLines = @(
    "# Waveform Analysis Report",
    "",
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Focus VCD: $VcdPath",
    "",
    "## Summary",
    "- Result: $(if ($analysisPassed) { 'PASS' } else { 'FAIL' })",
    "- Timescale: $timescale",
    "- Clock period (from VCD rising edges): $clockPeriod",
    "- timeout_flag rising edges: $timeoutRiseCount",
    "- btn_pulse intervals found: $($btnPulseIntervals.Count)",
    "",
    "## FSM Coverage",
    "- Visited states: $(if ($visitedStateNames.Count -gt 0) { $visitedStateNames -join ', ' } else { 'none' })",
    "- Missing required states (IDLE, HOME, MSG, SLEEP): $(if ($missingStates.Count -gt 0) { $missingStates -join ', ' } else { 'none' })",
    "",
    "## Pulse Width Checks",
    "- Pulse width violations: $($pulseViolations.Count)"
)

if ($pulseViolations.Count -gt 0) {
    $reportLines += "- Violation details:"
    foreach ($v in $pulseViolations) {
        $reportLines += "  - $v"
    }
}

$reportLines += ""
$reportLines += "## Artifact Presence"
$reportLines += "- Missing expected VCD files: $(if ($missingVcds.Count -gt 0) { $missingVcds -join ', ' } else { 'none' })"
$reportLines += ""
$reportLines += "## Parser Signals"
$reportLines += "- Missing required signal identifiers: $(if ($idsMissing.Count -gt 0) { $idsMissing -join ', ' } else { 'none' })"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ReportPath) | Out-Null
$reportLines | Set-Content -Path $ReportPath -Encoding ascii

if ($analysisPassed) {
    Write-Host "Waveform analysis PASS" -ForegroundColor Green
    Write-Host "Report: $ReportPath" -ForegroundColor Green
    exit 0
}

Write-Host "Waveform analysis FAIL" -ForegroundColor Red
Write-Host "Report: $ReportPath" -ForegroundColor Yellow
exit 1
