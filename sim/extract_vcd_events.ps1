param(
    [string]$VcdPath = "sim/results/tb_fpga_msg_controller.vcd",
    [int]$MaxEvents = 120
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $VcdPath)) {
    Write-Error "VCD not found: $VcdPath"
    exit 1
}

$ids = @{}
$defsDone = $false
$scopeStack = New-Object System.Collections.Generic.List[string]
$time = 0L
$fsm = $null
$timeout = $null
$sec = $null
$pulse = $null
$events = New-Object System.Collections.Generic.List[object]

Get-Content $VcdPath | ForEach-Object {
    $line = $_

    if (-not $defsDone) {
        if ($line -match '^\$scope\s+\w+\s+(\S+)\s+\$end$') {
            $scopeStack.Add($matches[1])
            return
        } elseif ($line -match '^\$upscope\s+\$end$') {
            if ($scopeStack.Count -gt 0) {
                $scopeStack.RemoveAt($scopeStack.Count - 1)
            }
            return
        }

        $inTopTb = ($scopeStack.Count -eq 1 -and $scopeStack[0] -eq 'tb_fpga_msg_controller')

        if ($inTopTb -and $line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+fsm_state(?:\s|\[|$)') {
            $ids.fsm = $matches[1]
        } elseif ($inTopTb -and $line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+timeout_flag(?:\s|\[|$)') {
            $ids.timeout = $matches[1]
        } elseif ($inTopTb -and $line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+seconds_remaining(?:\s|\[|$)') {
            $ids.sec = $matches[1]
        } elseif ($inTopTb -and $line -match '^\$var\s+\w+\s+\d+\s+(\S+)\s+btn_pulse(?:\s|\[|$)') {
            $ids.pulse = $matches[1]
        } elseif ($line -match '^\$enddefinitions\s+\$end$') {
            $defsDone = $true
        }
        return
    }

    if ($line -match '^#(\d+)$') {
        $time = [int64]$matches[1]
        return
    }

    if ($line -match '^b([01xXzZ]+)\s+(\S+)$') {
        $bits = $matches[1].ToLower()
        $id = $matches[2]

        if ($id -eq $ids.fsm) {
            $val = if ($bits -match '^[01]+$') { [Convert]::ToInt32($bits, 2) } else { -1 }
            if ($fsm -ne $val) {
                $fsm = $val
                $events.Add([PSCustomObject]@{ t_ps = $time; kind = 'fsm_state'; value = $val })
            }
        } elseif ($id -eq $ids.sec) {
            $val = if ($bits -match '^[01]+$') { [Convert]::ToInt32($bits, 2) } else { -1 }
            if ($sec -ne $val) {
                $sec = $val
                $events.Add([PSCustomObject]@{ t_ps = $time; kind = 'seconds_remaining'; value = $val })
            }
        } elseif ($id -eq $ids.pulse) {
            if ($pulse -ne $bits) {
                $pulse = $bits
                if ($bits -match '1') {
                    $events.Add([PSCustomObject]@{ t_ps = $time; kind = 'btn_pulse'; value = $bits })
                }
            }
        }
        return
    }

    if ($line -match '^([01xXzZ])(\S+)$') {
        $val = $matches[1].ToLower()
        $id = $matches[2]

        if ($id -eq $ids.timeout) {
            if ($timeout -ne $val) {
                $timeout = $val
                $events.Add([PSCustomObject]@{ t_ps = $time; kind = 'timeout_flag'; value = $val })
            }
        }
    }
}

$fsmNames = @{ 0 = 'INIT'; 1 = 'IDLE'; 2 = 'HOME'; 3 = 'MSG'; 4 = 'SLEEP' }
$events = $events | Sort-Object t_ps | Select-Object -First $MaxEvents

$events | ForEach-Object {
    $ms = [Math]::Round($_.t_ps / 1000000000.0, 3)
    if ($_.kind -eq 'fsm_state') {
        $name = if ($fsmNames.ContainsKey([int]$_.value)) { $fsmNames[[int]$_.value] } else { 'UNK' }
        "{0,8} ms | {1,-18} | {2} ({3})" -f $ms, $_.kind, $name, $_.value
    } else {
        "{0,8} ms | {1,-18} | {2}" -f $ms, $_.kind, $_.value
    }
}
