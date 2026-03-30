# Quick Verification of Critical Fixes
# Run this directly in PowerShell

Write-Host "====== DE10 LCD Message System V2 - VERIFICATION ======`n" -ForegroundColor Cyan

# Check 1: idle_timer fix
Write-Host "[**] CHECKING: idle_timer.v off-by-one bug fix" -ForegroundColor Yellow
$timer = Select-String -Path hw/rtl/idle_timer.v -Pattern "if \(sec_counter == 0\)"
if ($timer) {
    Write-Host "[✅] PASS: idle_timer.v fix IS applied (line $($timer.LineNumber))" -ForegroundColor Green
} else {
    Write-Host "[❌] FAIL: idle_timer.v fix NOT found" -ForegroundColor Red
}

# Check 2: RTL files exist
Write-Host "`n[**] CHECKING: RTL module files" -ForegroundColor Yellow
$rtl = @("button_debouncer.v", "button_edge_detector.v", "idle_timer.v", "hex_display.v", "fpga_msg_controller.v")
$rtl_ok = $true
foreach ($f in $rtl) {
    if (Test-Path "hw/rtl/$f") {
        Write-Host "  [✅] hw/rtl/$f" -ForegroundColor Green
    } else {
        Write-Host "  [❌] hw/rtl/$f MISSING" -ForegroundColor Red
        $rtl_ok = $false
    }
}

# Check 3: QSF registers modules
Write-Host "`n[**] CHECKING: Quartus QSF configuration" -ForegroundColor Yellow
$qsf_file = Get-Content hw/quartus/DE10_Standard_GHRD.qsf -Raw
$modules_ok = $true
foreach ($mod in $rtl) {
    $modname = $mod.Replace(".v", "")
    if ($qsf_file -like "*$modname*") {
        Write-Host "  [✅] $modname registered" -ForegroundColor Green
    } else {
        Write-Host "  [❌] $modname NOT in QSF" -ForegroundColor Red
        $modules_ok = $false
    }
}

# Check 4: Top-level instantiation
Write-Host "`n[**] CHECKING: Top-level integration" -ForegroundColor Yellow
$ghrd = Get-Content hw/quartus/DE10_Standard_GHRD.v -Raw
if ($ghrd -like "*fpga_msg_controller*u_msg_ctrl*") {
    Write-Host "  [✅] fpga_msg_controller instantiated" -ForegroundColor Green
} else {
    Write-Host "  [❌] fpga_msg_controller NOT instantiated" -ForegroundColor Red
}

# Check 5: PIO connections in GHRD
Write-Host "`n[**] CHECKING: PIO signal connections" -ForegroundColor Yellow
$pio_matches = Select-String -Path hw/quartus/DE10_Standard_GHRD.v -Pattern "fsm_status_pio_external|timer_status_pio_external"
if ($pio_matches.Count -ge 2) {
    Write-Host "  [✅] PIO exports connected ($($pio_matches.Count) matches)" -ForegroundColor Green
} else {
    Write-Host "  [⚠️]  PIO exports found: $($pio_matches.Count)/2 (may need manual qsys update)" -ForegroundColor Yellow
}

# Check 6: main.c register mapping
Write-Host "`n[**] CHECKING: HPS software configuration" -ForegroundColor Yellow
$main = Get-Content sw/hps_app/main.c -Raw
$reg_ok = 0
if ($main -like "*FSM_STATUS_PIO_BASE*0x6000*" -or $main -like "*0x6000*FSM_STATUS_PIO*") {
    Write-Host "  [✅] FSM_STATUS_PIO_BASE = 0x6000" -ForegroundColor Green
    $reg_ok++
} else {
    Write-Host "  [❌] FSM_STATUS_PIO_BASE NOT found" -ForegroundColor Red
}

if ($main -like "*TIMER_STATUS_PIO_BASE*0x7000*" -or $main -like "*0x7000*TIMER_STATUS_PIO*") {
    Write-Host "  [✅] TIMER_STATUS_PIO_BASE = 0x7000" -ForegroundColor Green
    $reg_ok++
} else {
    Write-Host "  [❌] TIMER_STATUS_PIO_BASE NOT found" -ForegroundColor Red
}

# Check 7: soc_system.qsys PIOs
Write-Host "`n[**] CHECKING: soc_system.qsys PIOs (CRITICAL)" -ForegroundColor Yellow
$qsys = Get-Content hw/quartus/soc_system.qsys -Raw
if ($qsys -like "*fsm_status_pio*" -and $qsys -like "*timer_status_pio*") {
    Write-Host "  [✅] Both PIOs present in soc_system.qsys" -ForegroundColor Green
} else {
    Write-Host "  [⚠️]  PIOs NOT in soc_system.qsys - MANUAL STEP REQUIRED" -ForegroundColor Yellow
    Write-Host "         → Follow ULTRA_PLAN_BUILD_GUIDE.md PHASE 2" -ForegroundColor Yellow
    Write-Host "         → Add PIOs via Platform Designer before compilation" -ForegroundColor Yellow
}

Write-Host "`n====== VERIFICATION COMPLETE ======`n" -ForegroundColor Cyan
Write-Host "See ULTRA_PLAN_BUILD_GUIDE.md for complete build instructions" -ForegroundColor Cyan

# Check 8: Simulation preflight + canonical regression
Write-Host "`n[**] CHECKING: Simulation preflight + canonical regression" -ForegroundColor Yellow
if ((Test-Path "sim/check_sim_env.ps1") -and (Test-Path "sim/run_all_sim.ps1")) {
    & .\sim\check_sim_env.ps1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Preflight passed; running canonical simulation suites..." -ForegroundColor Green
        & .\sim\run_all_sim.ps1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Canonical simulation regression passed" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Canonical simulation regression failed" -ForegroundColor Red
        }
    } else {
        Write-Host "  [WARN] Preflight failed; simulation regression skipped" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WARN] Simulation scripts not found; skipping" -ForegroundColor Yellow
}
