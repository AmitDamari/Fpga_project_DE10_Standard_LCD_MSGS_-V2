# PRE_FLASH_AUDIT
Date: 2026-05-02
Scope: Phase 5 (HPS Software Audit), Phase 6 (Quartus build, timing, resources)

## Phase 5 - HPS Software Audit
- [MED] HPS app hard-codes LW bridge PIO base addresses; any Qsys rebase will silently break register mapping. Consider generating a Qsys header or validating all PIO bases at startup. See [sw/hps_app/main.c](sw/hps_app/main.c#L22-L24) and [sw/hps_app/main.c](sw/hps_app/main.c#L111-L115).
- [LOW] `button_addr` is mapped and logged but never read; this looks like a stale mapping or a missed use of the raw button PIO. See [sw/hps_app/main.c](sw/hps_app/main.c#L46) and [sw/hps_app/main.c](sw/hps_app/main.c#L110-L116).
- [LOW] `MSG_COUNT` duplicates the message table size; future edits to the table can desync bounds checks. Consider deriving the count or adding a static assert. See [sw/hps_app/main.c](sw/hps_app/main.c#L34) and [sw/hps_app/messages.h](sw/hps_app/messages.h#L6).

## Phase 6 - Quartus Build / Timing / Resources
- [BLOCKER] Timing Analyzer report contains negative setup and hold slack (e.g., -0.763 setup, -0.777 hold). Resolve or formally constrain/waive these paths before flashing. See [hw/quartus/output_files/DE10_Standard_GHRD.sta.rpt](hw/quartus/output_files/DE10_Standard_GHRD.sta.rpt#L24-L37).
- [LOW] Assembler warning: NUM_PARALLEL_PROCESSORS not set; can slow builds on shared machines. See [hw/quartus/output_files/DE10_Standard_GHRD.asm.rpt](hw/quartus/output_files/DE10_Standard_GHRD.asm.rpt#L94).
- [INFO] Resource usage is low (ALMs 7%, RAM blocks 1%, DSP 0%, pins 68%). See [hw/quartus/output_files/DE10_Standard_GHRD.fit.summary](hw/quartus/output_files/DE10_Standard_GHRD.fit.summary#L8-L14).
