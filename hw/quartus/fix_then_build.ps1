# Powershell script to fix Qsys and build the FPGA project

$QUARTUS_PATH = "C:\intelFPGA_lite\21.1\quartus"
$QSYS_SCRIPT = "$QUARTUS_PATH\sopc_builder\bin\qsys-script.exe"
$QSYS_GEN = "$QUARTUS_PATH\sopc_builder\bin\qsys-generate.exe"
$QUARTUS_SH = "$QUARTUS_PATH\bin64\quartus_sh.exe"

# 1. Apply Qsys Fix (Add PIOs via Tcl)
Write-Host "Applying Qsys Fix (Adding PIOs)..." -ForegroundColor Cyan
if (Test-Path $QSYS_SCRIPT) {
    & $QSYS_SCRIPT --script=add_pios.tcl --system-file=soc_system.qsys
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Qsys Fix Applied Successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Qsys Fix FAILED. Exit code: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Error: qsys-script.exe not found at $QSYS_SCRIPT" -ForegroundColor Red
    exit 1
}

# 2. Generate Qsys HDL
Write-Host "Regenerating Qsys HDL..." -ForegroundColor Cyan
if (Test-Path $QSYS_GEN) {
    & $QSYS_GEN soc_system.qsys --synthesis=VERILOG
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Qsys Generation Successful." -ForegroundColor Green
    }
    else {
        Write-Host "Qsys Generation FAILED. Exit code: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Error: qsys-generate.exe not found at $QSYS_GEN" -ForegroundColor Red
    exit 1
}

# 3. Compile Quartus Project
Write-Host "Starting Quartus Compilation (this may take 10-30 minutes)..." -ForegroundColor Cyan
if (Test-Path $QUARTUS_SH) {
    & $QUARTUS_SH --flow compile DE10_Standard_GHRD
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Quartus Compilation Successful! Bitstream: DE10_Standard_GHRD.sof" -ForegroundColor Green
    }
    else {
        Write-Host "Quartus Compilation FAILED. Exit code: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Error: quartus_sh.exe not found at $QUARTUS_SH" -ForegroundColor Red
    exit 1
}
