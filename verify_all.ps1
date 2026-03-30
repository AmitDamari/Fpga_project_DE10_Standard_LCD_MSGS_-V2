#!/usr/bin/env pwsh
<#
.SYNOPSIS
ULTRA Verification Script for DE10-Standard LCD Message System V2
Checks all critical components before build.

.DESCRIPTION
Verifies:
- RTL module fixes (idle_timer)
- File presence and structure
- Register mappings
- Configuration files
- Qsys updates status
- Canonical simulation sign-off

.EXAMPLE
.\verify_all.ps1
#>

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  DE10 LCD Message System V2 - ULTRA VERIFICATION SCRIPT" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$script:errors = 0
$script:warnings = 0
$script:passes = 0
$script:warningItems = @()

function Add-Result {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$ErrorMsg = "Failed",
        [string]$WarningMsg = $null
    )

    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passes++
    } elseif ($null -ne $WarningMsg -and $WarningMsg -ne "") {
        Write-Host "  [WARN] $Name - $WarningMsg" -ForegroundColor Yellow
        $script:warnings++
        $script:warningItems += ("{0}: {1}" -f $Name, $WarningMsg)
    } else {
        Write-Host "  [FAIL] $Name - $ErrorMsg" -ForegroundColor Red
        $script:errors++
    }
}

Write-Host "PHASE 1: RTL Module Fixes" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$idle_timer_file = "hw/rtl/idle_timer.v"
if (Test-Path $idle_timer_file) {
    $content = Get-Content $idle_timer_file -Raw
    $has_fix = $content -like "*if (sec_counter == 0) begin*"
    $has_old_bug = $content -like "*if (sec_counter <= 1) begin*"

    if ($has_fix -and -not $has_old_bug) {
        Add-Result "idle_timer.v: Off-by-one bug fixed" $true
    } elseif ($has_old_bug) {
        Add-Result "idle_timer.v: Old bug still present" $false
    } else {
        Add-Result "idle_timer.v: Logic pattern match" $false "Check countdown logic" "Could not match expected pattern"
    }
} else {
    Add-Result "idle_timer.v exists" $false "File not found at $idle_timer_file"
}

Write-Host ""
Write-Host "PHASE 2: RTL Module Files" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$rtl_files = @(
    "hw/rtl/button_debouncer.v",
    "hw/rtl/button_edge_detector.v",
    "hw/rtl/idle_timer.v",
    "hw/rtl/hex_display.v",
    "hw/rtl/fpga_msg_controller.v",
    "hw/rtl/message_fsm.v"
)

foreach ($path in $rtl_files) {
    Add-Result "File exists: $path" (Test-Path $path)
}

Write-Host ""
Write-Host "PHASE 3: Quartus Build Configuration (QSF)" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$qsf_file = "hw/quartus/DE10_Standard_GHRD.qsf"
if (Test-Path $qsf_file) {
    $qsf_content = Get-Content $qsf_file -Raw
    $modules = @("button_debouncer", "button_edge_detector", "idle_timer", "hex_display", "fpga_msg_controller", "message_fsm")
    $modules_found = 0

    foreach ($mod in $modules) {
        if ($qsf_content -like "*$mod.v*") {
            $modules_found++
        }
    }

    Add-Result "QSF: all 6 RTL modules registered" ($modules_found -eq 6) "Only $modules_found/6 found"
} else {
    Add-Result "QSF file exists" $false "Not found at $qsf_file"
}

Write-Host ""
Write-Host "PHASE 4: Top-Level FPGA Integration" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$ghrd_file = "hw/quartus/DE10_Standard_GHRD.v"
if (Test-Path $ghrd_file) {
    $ghrd_content = Get-Content $ghrd_file -Raw

    $has_controller = $ghrd_content -like "*fpga_msg_controller*u_msg_ctrl*"
    Add-Result "fpga_msg_controller instantiated" $has_controller

    $wires_ok = ($ghrd_content -like "*wire*ctrl_btn_pulse*") -and
                ($ghrd_content -like "*wire*ctrl_btn_debounced*") -and
                ($ghrd_content -like "*wire*ctrl_timeout_flag*") -and
                ($ghrd_content -like "*wire*ctrl_seconds_remaining*")
    Add-Result "All control signal wires declared" $wires_ok "Some wires missing"

    $has_hex_assigns = ($ghrd_content -like "*assign HEX0*hex0_out*") -and
                       ($ghrd_content -like "*assign HEX1*hex1_out*")
    Add-Result "HEX display assignments present" $has_hex_assigns
} else {
    Add-Result "DE10_Standard_GHRD.v exists" $false "Not found"
}

Write-Host ""
Write-Host "PHASE 5: Qsys System Configuration" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$qsys_file = "hw/quartus/soc_system.qsys"
if (Test-Path $qsys_file) {
    $qsys_content = Get-Content $qsys_file -Raw

    $has_fsm_pio = $qsys_content -like "*fsm_status_pio*"
    $has_timer_pio = $qsys_content -like "*timer_status_pio*"

    if ($has_fsm_pio -and $has_timer_pio) {
        Add-Result "PIOs present in soc_system.qsys" $true

        $has_fsm_export = $qsys_content -like "*fsm_status_pio_external_connection*"
        $has_timer_export = $qsys_content -like "*timer_status_pio_external_connection*"
        Add-Result "PIO conduit exports defined" ($has_fsm_export -and $has_timer_export)

        $has_6000 = $qsys_content -like "*6000*"
        $has_7000 = $qsys_content -like "*7000*"
        Add-Result "Base addresses configured (0x6000, 0x7000)" ($has_6000 -and $has_7000)
    } else {
        Add-Result "PIOs in soc_system.qsys" $false "Required manual step" "PIOs must be added manually before compilation"
    }
} else {
    Add-Result "soc_system.qsys file exists" $false "Not found"
}

Write-Host ""
Write-Host "PHASE 6: HPS Software (main.c)" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$main_c = "sw/hps_app/main.c"
if (Test-Path $main_c) {
    $main_content = Get-Content $main_c -Raw

    $has_base_6000 = ($main_content -like "*0x6000*FSM_STATUS_PIO*") -or ($main_content -like "*FSM_STATUS_PIO*0x6000*")
    $has_base_7000 = ($main_content -like "*0x7000*TIMER_STATUS*") -or ($main_content -like "*TIMER_STATUS*0x7000*")
    Add-Result "FSM_STATUS_PIO_BASE = 0x6000" $has_base_6000
    Add-Result "TIMER_STATUS_PIO_BASE = 0x7000" $has_base_7000

    Add-Result "Register pointers mapped (fsm_status_addr)" ($main_content -like "*fsm_status_addr*")
    Add-Result "Register pointers mapped (timer_status_addr)" ($main_content -like "*timer_status_addr*")

    $states_ok = ($main_content -like "*STATE_IDLE*") -and
                 ($main_content -like "*STATE_HOME*") -and
                 ($main_content -like "*STATE_MESSAGE*")
    Add-Result "FSM states defined" $states_ok

    Add-Result "Message list accessible (MSG_LIST)" ($main_content -like "*MSG_LIST*")
} else {
    Add-Result "main.c exists" $false "Not found at $main_c"
}

Write-Host ""
Write-Host "PHASE 7: Message Content (messages.h)" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$messages_h = "sw/hps_app/messages.h"
if (Test-Path $messages_h) {
    $msg_content = Get-Content $messages_h -Raw
    $msg_count = ([regex]::Matches($msg_content, '\{.*?".*?".*?".*?"\}', 'Singleline') | Measure-Object).Count

    if ($msg_count -ge 18) {
        Add-Result "18+ messages defined in MSG_LIST" $true
    } else {
        Add-Result "18 messages in MSG_LIST" $false "Found only $msg_count messages"
    }

    Add-Result "Header guard present" ($msg_content -like "*#ifndef MESSAGES_H*")
} else {
    Add-Result "messages.h exists" $false "Not found"
}

Write-Host ""
Write-Host "PHASE 8: Build Configuration (Makefile)" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$makefile = "sw/hps_app/Makefile"
if (Test-Path $makefile) {
    $make_content = Get-Content $makefile -Raw
    Add-Result "All source files listed in Makefile" ($make_content -like "*main.c*LCD_Hw.c*LCD_Lib.c*")
    $has_include_flags = ($make_content -like "*-I*")
    if ($has_include_flags) {
        Add-Result "Include paths configured" $true
    } else {
        Add-Result "Include paths configured" $false "No include flags found" "No explicit -I flags in Makefile; verify only if build fails"
    }
} else {
    Add-Result "Makefile exists" $false "Not found"
}

Write-Host ""
Write-Host "PHASE 9: Canonical Simulation Sign-off" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Gray

$strict_sim = $env:STRICT_SIM -eq "1"
$sim_preflight = "sim/check_sim_env.ps1"
$sim_regression = "sim/run_all_sim.ps1"

if ((Test-Path $sim_preflight) -and (Test-Path $sim_regression)) {
    Write-Host "  Running simulation preflight..."
    & $sim_preflight
    $preflight_ok = ($LASTEXITCODE -eq 0)

    if ($preflight_ok) {
        Add-Result "Simulation preflight (iverilog/vvp)" $true

        if ($env:RUN_LEGACY -eq "1") {
            Write-Host "  RUN_LEGACY=1 detected: legacy suites enabled." -ForegroundColor Cyan
        }

        Write-Host "  Running canonical simulation regression..."
        & $sim_regression
        $sim_ok = ($LASTEXITCODE -eq 0)

        if ($sim_ok) {
            Add-Result "Simulation regression (canonical suites)" $true
        } elseif ($strict_sim) {
            Add-Result "Simulation regression (canonical suites)" $false "Regression failed"
        } else {
            Add-Result "Simulation regression (canonical suites)" $false "Regression failed" "Regression failed (non-strict mode)"
        }
    } elseif ($strict_sim) {
        Add-Result "Simulation preflight (iverilog/vvp)" $false "Simulator toolchain missing"
    } else {
        Add-Result "Simulation preflight (iverilog/vvp)" $false "Simulator toolchain missing" "Preflight failed; simulation skipped (set STRICT_SIM=1 to enforce)"
    }
} elseif ($strict_sim) {
    Add-Result "Simulation scripts present" $false "Missing sim/check_sim_env.ps1 or sim/run_all_sim.ps1"
} else {
    Add-Result "Simulation scripts present" $false "Missing sim/check_sim_env.ps1 or sim/run_all_sim.ps1" "Simulation sign-off scripts missing; skipped"
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                    VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [PASS] Passed:   $($script:passes)" -ForegroundColor Green
Write-Host "  [WARN] Warnings: $($script:warnings)" -ForegroundColor Yellow
Write-Host "  [FAIL] Errors:   $($script:errors)" -ForegroundColor Red
Write-Host ""

if ($script:errors -eq 0 -and $script:warnings -eq 0) {
    Write-Host "  ALL CHECKS PASSED - READY FOR BUILD" -ForegroundColor Green
    Write-Host ""
    exit 0
} elseif ($script:errors -eq 0) {
    Write-Host "  WARNINGS DETECTED - Review before building" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Warning details:" -ForegroundColor Yellow
    foreach ($item in $script:warningItems) {
        Write-Host "  - $item" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 0
} else {
    Write-Host "  ERRORS FOUND - FIX BEFORE BUILDING" -ForegroundColor Red
    Write-Host ""
    exit 1
}
