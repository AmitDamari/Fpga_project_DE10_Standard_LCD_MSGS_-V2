# Demo Checklist Log

Date: 2026-03-30 22:49:36
Operator: pending
Board: DE10-Standard
Bitstream: pending
HPS App Build: pending

## Execution Results

- [x] Strict pre-demo verification gate executed (`STRICT_SIM=1`, `verify_all.ps1`)
- [x] Canonical simulation suites passed (8/8)
- [ ] FPGA programmed successfully
- [ ] HPS app launched successfully
- [ ] IDLE screen visible
- [ ] IDLE -> HOME transition confirmed
- [ ] HOME -> MSG transition confirmed
- [ ] MSG next/previous navigation confirmed
- [ ] KEY0 back navigation confirmed
- [ ] Timeout -> SLEEP confirmed
- [ ] Wake from SLEEP confirmed

## Observations

- Pre-demo software/simulation gate is green.
- Current warning is non-critical: Makefile has no explicit `-I` include flags.
- Sign-off report and parity artifacts were refreshed after strict verification.

## Issues

- Hardware-only evidence pending: real board latency samples not captured yet.
- Board dry-run steps remain open until physical test execution.

## Next On Hardware

1. Program FPGA and run HPS app.
2. Complete the unchecked board behavior items above.
3. Replace template latency rows with real measurements.
4. Re-run scripts/hardware/run_board_signoff.ps1.

## Artifact Links

- Latency CSV: artifacts/hardware/latency_samples.csv
- Sign-off report: artifacts/hardware/signoff_report.md
- Optional captures:


