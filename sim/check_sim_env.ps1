# =============================================================================
# check_sim_env.ps1 — Simulation environment preflight
# Verifies required simulator tools are available before running regressions.
# =============================================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Simulation Environment Preflight" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$missing = @()

$iverilogCmd = Get-Command "iverilog" -ErrorAction SilentlyContinue
if ($iverilogCmd) {
    Write-Host "[OK] iverilog found: $($iverilogCmd.Source)" -ForegroundColor Green
    & iverilog -V 2>$null | Select-Object -First 1 | ForEach-Object { Write-Host "     $_" }
} else {
    Write-Host "[MISSING] iverilog" -ForegroundColor Red
    $missing += "iverilog"
}

$vvpCmd = Get-Command "vvp" -ErrorAction SilentlyContinue
if ($vvpCmd) {
    Write-Host "[OK] vvp found: $($vvpCmd.Source)" -ForegroundColor Green
    & vvp -V 2>$null | Select-Object -First 1 | ForEach-Object { Write-Host "     $_" }
} else {
    Write-Host "[MISSING] vvp" -ForegroundColor Red
    $missing += "vvp"
}

Write-Host ""
if ($missing.Count -eq 0) {
    Write-Host "Preflight PASSED: simulator toolchain is ready." -ForegroundColor Green
    Write-Host "Run next: .\\sim\\run_all_sim.ps1" -ForegroundColor Green
    exit 0
}

Write-Host "Preflight FAILED: missing required tools: $($missing -join ', ')" -ForegroundColor Red
Write-Host "Install Icarus Verilog from: https://bleyer.org/icarus/" -ForegroundColor Yellow
Write-Host "Then add its bin directory to PATH (example: C:\iverilog\bin)." -ForegroundColor Yellow
Write-Host "Optional for current shell:" -ForegroundColor Cyan
Write-Host '  $env:Path += ";C:\iverilog\bin"' -ForegroundColor Cyan
exit 1
