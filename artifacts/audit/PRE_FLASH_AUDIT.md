# PRE_FLASH_AUDIT
Date: 2026-05-02
Scope: Phase 5-10 (HPS software, Quartus build/timing/resources, docs parity, lab checklist, risks, executive summary)

## Phase 5 - HPS Software Audit
- [MED] HPS app hard-codes LW bridge PIO base addresses; any Qsys rebase will silently break register mapping. Consider generating a Qsys header or validating all PIO bases at startup. See [sw/hps_app/main.c](sw/hps_app/main.c#L22-L24) and [sw/hps_app/main.c](sw/hps_app/main.c#L111-L115).
- [LOW] `button_addr` is mapped and logged but never read; this looks like a stale mapping or a missed use of the raw button PIO. See [sw/hps_app/main.c](sw/hps_app/main.c#L46) and [sw/hps_app/main.c](sw/hps_app/main.c#L110-L116).
- [LOW] `MSG_COUNT` duplicates the message table size; future edits to the table can desync bounds checks. Consider deriving the count or adding a static assert. See [sw/hps_app/main.c](sw/hps_app/main.c#L34) and [sw/hps_app/messages.h](sw/hps_app/messages.h#L6).

## Phase 6 - Quartus Build / Timing / Resources
- [OK] Quartus compilation successful; assembler reports 0 errors with 1 warning. See [hw/quartus/output_files/DE10_Standard_GHRD.asm.rpt](hw/quartus/output_files/DE10_Standard_GHRD.asm.rpt).
- [OK] CLOCK_50 timing clean: setup +9.514 ns, hold +0.241 ns. See [hw/quartus/output_files/DE10_Standard_GHRD.sta.rpt](hw/quartus/output_files/DE10_Standard_GHRD.sta.rpt).
- [OK] HPS DDR3 pre-calibration paths positive after false-path constraints applied. See [hw/quartus/DE10_Standard_GHRD.sdc](hw/quartus/DE10_Standard_GHRD.sdc).
- [INFO] Resource usage: ALMs 3,033 / 41,910 (7%). See [hw/quartus/output_files/DE10_Standard_GHRD.fit.summary](hw/quartus/output_files/DE10_Standard_GHRD.fit.summary).
- [INFO] soc_system.rbf regenerated 2026-05-02 17:13. See [hw/quartus/output_files/soc_system.rbf](hw/quartus/output_files/soc_system.rbf).

## Phase 7 - Docs vs Code Parity
- [MED] Requirements still specify a 50 ms default debounce window, but RTL now uses 20 ms. Update requirement text to match implementation. See [docs/requirements.md](docs/requirements.md) and [hw/rtl/button_debouncer.v](hw/rtl/button_debouncer.v).
- [MED] Verification report performance evidence references 50 ms debounce validation; update evidence notes and rerun if needed. See [docs/verification_report.md](docs/verification_report.md).
- [OK] Architecture doc describes 20 ms debounce and matches RTL. See [docs/architecture.md](docs/architecture.md).

## Phase 8 - Lab Bring-Up Checklist (Printable)
- [ ] [INFO] Board visually inspected (no damage, heatsink secure).
- [ ] [INFO] SD card image verified/inserted (if used).
- [ ] [INFO] MSEL/jumper settings confirm desired FPGA configuration mode (JTAG).
- [ ] [INFO] USB-Blaster/JTAG connected to host.
- [ ] [INFO] UART console connected (HPS serial).
- [ ] [INFO] LCD and any external peripherals cabled and powered.
- [ ] [INFO] 5V power supply connected; power switch OFF.
- [ ] [INFO] Power ON; power LED and FPGA DONE LED observed.
- [ ] [INFO] Program FPGA with soc_system.rbf (Quartus Programmer).
- [ ] [INFO] HPS boots to Linux prompt; login successful.
- [ ] [INFO] HPS app launched without errors.
- [ ] [INFO] Button presses update LCD messages and HEX/LED status.
- [ ] [INFO] Idle timeout transitions to SLEEP and wakes on button.
- [ ] [INFO] Basic latency feel check (<50 ms) observed.
- [ ] [INFO] Logs captured (console output and app run notes).
- [ ] [INFO] Shutdown procedure completed cleanly.

## Phase 9 - Top-10 Risk Register
- [HIGH] Hard-coded HPS LW bridge PIO bases can break if Qsys changes; mitigate with auto-generated headers or startup validation. See [sw/hps_app/main.c](sw/hps_app/main.c).
- [MED] Requirements and verification docs still cite 50 ms debounce; mitigate by updating docs and evidence notes. See [docs/requirements.md](docs/requirements.md) and [docs/verification_report.md](docs/verification_report.md).
- [MED] End-to-end latency still lacks hardware measurement artifact; mitigate with scope/logic analyzer capture on board. See [docs/verification_report.md](docs/verification_report.md).
- [MED] False-path constraints on HPS DDR3 pre-cal paths could mask misapplied constraints; mitigate by cross-checking against Intel guidance and post-cal timing. See [hw/quartus/DE10_Standard_GHRD.sdc](hw/quartus/DE10_Standard_GHRD.sdc).
- [LOW] HPS app has no watchdog/service restart; mitigate with systemd service or watchdog.
- [LOW] SD card image drift between lab and repo; mitigate with checksum and a known-good backup.
- [LOW] JTAG/USB driver or cable issues can block lab bring-up; mitigate with pre-checks and spares.
- [LOW] LCD cabling/backlight issues can block demo; mitigate with spare cable and pinout check.
- [LOW] Assembler warning (NUM_PARALLEL_PROCESSORS) can slow rebuilds; mitigate by setting the variable. See [hw/quartus/output_files/DE10_Standard_GHRD.asm.rpt](hw/quartus/output_files/DE10_Standard_GHRD.asm.rpt).
- [LOW] Regression evidence may be stale after latest compile; mitigate by re-running pre-board verification. See [sim/run_pre_board_verification.ps1](sim/run_pre_board_verification.ps1).

## Phase 10 - Executive Summary + GO/NO-GO Verdict
- [INFO] Verdict: GO-WITH-RISK.
- [INFO] Action 1: Update requirements and verification report to reflect 20 ms debounce and refreshed evidence.
- [INFO] Action 2: Re-run pre-board verification and archive logs for this build.
- [INFO] Action 3: Execute the lab bring-up checklist and complete a full functional smoke test.
- [INFO] Action 4: Capture a quick end-to-end latency measurement artifact on hardware.
- [INFO] Action 5: Add a lightweight startup validation for HPS PIO base addresses.
- [INFO] ETA to demo-ready: 4 hours.
