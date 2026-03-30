# DE10-Standard LCD Message System V2 - Architecture

## 1. System Partitioning

The design uses a hybrid SoC partition where FPGA fabric owns real-time control and HPS performs LCD rendering.

- FPGA (control authority): debouncing, edge detection, idle timeout, UI FSM transitions, and HEX status outputs.
- HPS (renderer/observer): reads FPGA status registers and renders LCD content for current state/index.

This partition keeps timing-critical behavior deterministic in hardware and removes OS scheduling jitter from control transitions.

## 2. Functional Data Flow

1. KEY[3:0] inputs (active-LOW) enter `button_debouncer.v` and are synchronized/filtered.
2. Debounced active-HIGH levels feed `button_edge_detector.v` to produce one-cycle press pulses.
3. Press pulses drive:
	- `idle_timer.v` reset path (any pulse resets timeout countdown).
	- `message_fsm.v` transition path (button-driven navigation across UI states).
4. `message_fsm.v` exports:
	- FSM state (`INIT/IDLE/HOME/MSG/SLEEP`).
	- Message index for LCD content selection.
5. `fpga_msg_controller.v` aggregates timer/FSM/status and drives HEX outputs.
6. SoC wrapper exports packed status through Avalon PIOs:
	- `fsm_status_pio`: [7:5]=state, [4:0]=msg_index.
	- `timer_status_pio`: [0]=timeout, [4:1]=seconds remaining.
7. HPS app (`main.c`) polls these registers and renders the corresponding LCD frame.

## 3. RTL Modules

- `hw/rtl/button_debouncer.v`: 2-FF synchronizer + stability counter, default 50 ms window.
- `hw/rtl/button_edge_detector.v`: rising-edge one-shot pulse generation.
- `hw/rtl/idle_timer.v`: parameterized countdown, timeout assert/clear behavior.
- `hw/rtl/message_fsm.v`: 5-state Verilog FSM with timeout priority and index wrap-around.
- `hw/rtl/hex_display.v`: active-LOW 7-segment encoder.
- `hw/rtl/fpga_msg_controller.v`: integration wrapper and status/HEX aggregation.

## 4. SoC Interface Contract

Lightweight H2F bridge base: `0xFF200000`

- `button_pio` at `0x5000` (legacy raw buttons, input).
- `fsm_status_pio` at `0x6000` (8-bit input).
- `timer_status_pio` at `0x7000` (8-bit input).

Contract assumptions:

- Register packing is stable and verified by simulation contract tests.
- HPS must decode state/index exactly according to bit assignments above.

## 5. Timing and Ownership Rules

- Control transitions must originate in FPGA FSM logic.
- HPS must not override FSM transitions; it may only render based on observed hardware state.
- Timer reset source is OR of button pulse events.

## 6. Build/Integration Notes

- Platform Designer system is defined in `hw/quartus/soc_system.qsys`.
- Top-level SoC wiring is in `hw/quartus/DE10_Standard_GHRD.v`.
- Quartus source inclusion is controlled by `hw/quartus/DE10_Standard_GHRD.qsf`.

## 7. Verification Linkage

- Functional requirements are defined in `docs/requirements.md`.
- Requirement-to-test mapping and sign-off evidence live in `docs/verification_report.md`.
