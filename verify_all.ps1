#!/usr/bin/env pwsh
<#
.SYNOPSIS
ULTRA Verification Script for DE10-Standard LCD Message System V2
Checks all critical components before build

.DESCRIPTION
Verifies:
- RTL module fixes (idle_timer)
- File presence and structure
- Register mappings
- Configuration files
- Qsys updates status

.EXAMPLE
.\verify_all.ps1
#>

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  DE10 LCD Message System V2 - ULTRA VERIFICATION SCRIPT       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$script:errors = 0
$script:warnings = 0
$script:passes = 0

function Test-Item {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$ErrorMsg = "Failed",
        [string]$WarningMsg = $null
    )
    
    if ($Condition) {
        Write-Host "  [✅] $Name" -ForegroundColor Green
        $script:passes++
    } elseif ($null -ne $WarningMsg -and $WarningMsg -ne "") {
        Write-Host "  [⚠️]  $Name - $WarningMsg" -ForegroundColor Yellow
        $script:warnings++
    } else {
        Write-Host "  [❌] $Name - $ErrorMsg" -ForegroundColor Red
        $script:errors++
    }
}

# ============================================================================
# CHECK 1: idle_timer.v Fix
# ============================================================================
Write-Host "PHASE 1: RTL Module Fixes" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$idle_timer_file = "hw/rtl/idle_timer.v"
if (Test-Path $idle_timer_file) {
    $content = Get-Content $idle_timer_file -Raw
    
    # Check for the fixed condition
    $has_fix = $content -like "*if (sec_counter == 0) begin*"
    $has_old_bug = $content -like "*if (sec_counter <= 1) begin*"
    
    if ($has_fix -and -not $has_old_bug) {
        Test-Item "idle_timer.v: Off-by-one bug FIXED" $true
    } elseif ($has_old_bug) {
        Test-Item "idle_timer.v: Old bug still present (FIX NOT APPLIED)" $false
    } else {
        Test-Item "idle_timer.v: Logic unclear (verify manually)" $false "Check countdown logic"
    }
} else {
    Test-Item "idle_timer.v: File exists" $false "File not found at $idle_timer_file"
}

# ============================================================================
# CHECK 2: RTL Files Presence
# ============================================================================
Write-Host ""
Write-Host "PHASE 2: RTL Module Files" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$rtl_files = @(
    ("button_debouncer.v", "hw/rtl/button_debouncer.v"),
    ("button_edge_detector.v", "hw/rtl/button_edge_detector.v"),
    ("idle_timer.v", "hw/rtl/idle_timer.v"),
    ("hex_display.v", "hw/rtl/hex_display.v"),
    ("fpga_msg_controller.v", "hw/rtl/fpga_msg_controller.v")
)

foreach ($item in $rtl_files) {
    $name = $item[0]
    $path = $item[1]
    Test-Item "File: $name" (Test-Path $path)
}

# ============================================================================
# CHECK 3: Quartus QSF Configuration
# ============================================================================
Write-Host ""
Write-Host "PHASE 3: Quartus Build Configuration (QSF)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$qsf_file = "hw/quartus/DE10_Standard_GHRD.qsf"
if (Test-Path $qsf_file) {
    $qsf_content = Get-Content $qsf_file -Raw
    
    $modules = @("button_debouncer", "button_edge_detector", "idle_timer", "hex_display", "fpga_msg_controller")
    $modules_found = 0
    
    foreach ($mod in $modules) {
        if ($qsf_content -like "*$mod.v*") {
            $modules_found++
        }
    }
    
    Test-Item "QSF: All 5 RTL modules registered" ($modules_found -eq 5) "Only $modules_found/5 found"
} else {
    Test-Item "QSF file exists" $false "Not found at $qsf_file"
}

# ============================================================================
# CHECK 4: Top-Level Integration
# ============================================================================
Write-Host ""
Write-Host "PHASE 4: Top-Level FPGA Integration" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$ghrd_file = "hw/quartus/DE10_Standard_GHRD.v"
if (Test-Path $ghrd_file) {
    $ghrd_content = Get-Content $ghrd_file -Raw
    
    # Check for controller instantiation
    $has_controller = $ghrd_content -like "*fpga_msg_controller*u_msg_ctrl*"
    Test-Item "fpga_msg_controller instantiated" $has_controller
    
    # Check for wire declarations
    $has_ctrl_btn_pulse = $ghrd_content -like "*wire*ctrl_btn_pulse*"
    $has_ctrl_debounced = $ghrd_content -like "*wire*ctrl_btn_debounced*"
    $has_ctrl_timeout = $ghrd_content -like "*wire*ctrl_timeout_flag*"
    $has_ctrl_seconds = $ghrd_content -like "*wire*ctrl_seconds_remaining*"
    
    $wires_ok = $has_ctrl_btn_pulse -and $has_ctrl_debounced -and $has_ctrl_timeout -and $has_ctrl_seconds
    Test-Item "All control signal wires declared" $wires_ok "Some wires missing"
    
    # Check for HEX assignments
    $has_hex_assigns = $ghrd_content -like "*assign HEX0*hex0_out*" -and `
                       $ghrd_content -like "*assign HEX1*hex1_out*"
    Test-Item "HEX display assignments present" $has_hex_assigns
    
} else {
    Test-Item "DE10_Standard_GHRD.v exists" $false "Not found"
}

# ============================================================================
# CHECK 5: Qsys System Configuration
# ============================================================================
Write-Host ""
Write-Host "PHASE 5: Qsys System Configuration" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$qsys_file = "hw/quartus/soc_system.qsys"
if (Test-Path $qsys_file) {
    $qsys_content = Get-Content $qsys_file -Raw
    
    # Check for PIOs
    $has_fsm_pio = $qsys_content -like "*fsm_status_pio*"
    $has_timer_pio = $qsys_content -like "*timer_status_pio*"
    
    if ($has_fsm_pio -and $has_timer_pio) {
        Test-Item "PIOs present in soc_system.qsys" $true
        
        # Check for exports
        $has_fsm_export = $qsys_content -like "*fsm_status_pio_external_connection*"
        $has_timer_export = $qsys_content -like "*timer_status_pio_external_connection*"
        
        Test-Item "PIO conduit exports defined" ($has_fsm_export -and $has_timer_export)
        
        # Check for correct addresses
        $has_6000 = $qsys_content -like "*6000*" -or $qsys_content -like "*x6000*"
        $has_7000 = $qsys_content -like "*7000*" -or $qsys_content -like "*x7000*"
        
        Test-Item "Base addresses configured (0x6000, 0x7000)" ($has_6000 -and $has_7000)
    } else {
        Test-Item "PIOs in soc_system.qsys" $false "REQUIRED MANUAL STEP - Add PIOs via Platform Designer" `
            "PIOs MUST be added manually to soc_system.qsys before compilation"
    }
} else {
    Test-Item "soc_system.qsys file exists" $false "Not found"
}

# ============================================================================
# CHECK 6: HPS Software Configuration
# ============================================================================
Write-Host ""
Write-Host "PHASE 6: HPS Software (main.c)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$main_c = "sw/hps_app/main.c"
if (Test-Path $main_c) {
    $main_content = Get-Content $main_c -Raw
    
    # Check register definitions
    $has_base_6000 = $main_content -like "*0x6000*FSM_STATUS_PIO*" -or `
                     $main_content -like "*FSM_STATUS_PIO*0x6000*"
    $has_base_7000 = $main_content -like "*0x7000*TIMER_STATUS*" -or `
                     $main_content -like "*TIMER_STATUS*0x7000*"
    
    Test-Item "FSM_STATUS_PIO_BASE = 0x6000" $has_base_6000
    Test-Item "TIMER_STATUS_PIO_BASE = 0x7000" $has_base_7000
    
    # Check register mapping
    $has_fsm_addr = $main_content -like "*fsm_status_addr*"
    $has_timer_addr = $main_content -like "*timer_status_addr*"
    
    Test-Item "Register pointers mapped (fsm_status_addr)" $has_fsm_addr
    Test-Item "Register pointers mapped (timer_status_addr)" $has_timer_addr
    
    # Check FSM implementation
    $has_state_idle = $main_content -like "*STATE_IDLE*"
    $has_state_home = $main_content -like "*STATE_HOME*"
    $has_state_msg = $main_content -like "*STATE_MESSAGE*"
    
    Test-Item "FSM states defined" ($has_state_idle -and $has_state_home -and $has_state_msg)
    
    # Check message array
    $has_msg_list = $main_content -like "*MSG_LIST*"
    Test-Item "Message list accessible (MSG_LIST)" $has_msg_list
    
} else {
    Test-Item "main.c exists" $false "Not found at $main_c"
}

# ============================================================================
# CHECK 7: Messages Header
# ============================================================================
Write-Host ""
Write-Host "PHASE 7: Message Content (messages.h)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$messages_h = "sw/hps_app/messages.h"
if (Test-Path $messages_h) {
    $msg_content = Get-Content $messages_h -Raw
    
    # Check for 18 messages
    $msg_count = ([regex]::Matches($msg_content, '\{.*?".*?".*?".*?"\}', 'Singleline') | Measure-Object).Count
    
    if ($msg_count -ge 18) {
        Test-Item "18+ messages defined in MSG_LIST" $true
    } else {
        Test-Item "18 messages in MSG_LIST" $false "Found only $msg_count messages"
    }
    
    # Check for message guard
    $has_ifdef = $msg_content -like "*#ifndef MESSAGES_H*"
    Test-Item "Header guard present" $has_ifdef
    
} else {
    Test-Item "messages.h exists" $false "Not found"
}

# ============================================================================
# CHECK 8: Makefile
# ============================================================================
Write-Host ""
Write-Host "PHASE 8: Build Configuration (Makefile)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$makefile = "sw/hps_app/Makefile"
if (Test-Path $makefile) {
    $make_content = Get-Content $makefile -Raw
    
    # Check for source files
    $has_sources = $make_content -like "*main.c*LCD_Hw.c*LCD_Lib.c*"
    Test-Item "All source files listed in Makefile" $has_sources
    
    # Check for includes
    $has_includes = $make_content -like "*-I*" -or $make_content -like "*.h*"
    Test-Item "Include paths configured" $has_includes
    
} else {
    Test-Item "Makefile exists" $false "Not found"
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         VERIFICATION SUMMARY                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ✅ Passed:  $($script:passes)" -ForegroundColor Green
Write-Host "  ⚠️  Warning: $($script:warnings)" -ForegroundColor Yellow
Write-Host "  ❌ Errors:   $($script:errors)" -ForegroundColor Red
Write-Host ""

if ($script:errors -eq 0 -and $script:warnings -eq 0) {
    Write-Host "  🚀 ALL CHECKS PASSED - READY FOR BUILD" -ForegroundColor Green
    Write-Host ""
    exit 0
} elseif ($script:errors -eq 0) {
    Write-Host "  🟡 WARNINGS DETECTED - Review before building" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ⚠️  Critical warnings:" -ForegroundColor Yellow
    Write-Host "  • soc_system.qsys PIOs MUST be added manually via Platform Designer" -ForegroundColor Yellow
    Write-Host "  • Follow ULTRA_PLAN_BUILD_GUIDE.md PHASE 2 before compilation" -ForegroundColor Yellow
    Write-Host ""
    exit 0
} else {
    Write-Host "  ❌ ERRORS FOUND - FIX BEFORE BUILDING" -ForegroundColor Red
    Write-Host ""
    exit 1
}
