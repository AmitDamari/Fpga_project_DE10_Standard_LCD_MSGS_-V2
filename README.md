# DE10-Standard LCD Message System V2

This project implements an updated message display system for the Terasic DE10-Standard FPGA board. It migrates critical system control logic (button debouncing, edge detection, and idle timing) from the HPS software to the FPGA fabric for improved responsiveness and robustness.

## Project Architecture

The system uses a hybrid FPGA + HPS architecture:
*   **FPGA Logic**: Handles real-time tasks independently of the OS.
    *   **50ms Debouncer**: Filters button noise (Schmitt trigger synchronization + counter-based stability check).
    *   **Idle Timer**: Maintains a 15-second inactivity timeout countdown.
    *   **HEX Display Driver**: Outputs system status (Timer, Last Button, Timeout Flag) to onboard 7-segment displays.
*   **HPS Software**: Runs the high-level application logic.
    *   Reads clean, debounced button events from FPGA registers (via LW Bridge).
    *   Manages LCD content and message navigation.
    *   Implements the main state machine (IDLE, HOME, MESSAGE states).

### Hardware Components
*   `button_debouncer.v`: Parameterized debouncer module.
*   `idle_timer.v`: Programmable countdown timer with enable/reset.
*   `hex_display.v`: BCD-to-7-segment decoder.
*   `fpga_msg_controller.v`: Top-level wrapper integrating all FPGA modules.
*   `DE10_Standard_GHRD.v`: Top-level system instantiation connecting RTL to HPS via Qsys.

### Software Components
*   `main.c`: Updated application code reading PIO registers (0x6000, 0x7000).
*   `Makefile`: Build script for cross-compilation or on-board compilation.

## Register Map

The HPS communicates with the FPGA via the Lightweight H2F Bridge (Base: 0xFF200000).

| PIO Name | Offset | Width | Direction | Description |
| :--- | :--- | :--- | :--- | :--- |
| `button_pio` | `0x5000` | 4-bit | Input | (Original) Raw button inputs. |
| `fsm_status_pio` | `0x6000` | 8-bit | Input | Bits [3:0]: **Debounced Button State** (Active-HIGH). |
| `timer_status_pio` | `0x7000` | 8-bit | Input | Bit [0]: **Timeout Flag** (1=Expired). Bits [4:1]: **Seconds Remaining** (BCD). |

## Build Instructions

### 1. Build FPGA System (Windows)
We have provided an automated PowerShell script to fix Qsys and compile the design.
1.  Open PowerShell in the project root.
2.  Run:
    ```powershell
    .\hw\quartus\fix_then_build.ps1
    ```
    This script will:
    *   Fix `soc_system.qsys` by adding the required PIOs.
    *   Regenerate the HDL.
    *   Compile the Quartus project to generate `DE10_Standard_GHRD.sof`.

3.  Program the FPGA using Quartus Programmer.

### 2. Build HPS Software (Linux/Board)
1.  Copy `sw/hps_app` to the DE10 board.
2.  Compile the application:
    ```bash
    cd sw/hps_app
    make
    ```
3.  Run the application:
    ```bash
    ./lcd_msg_app
    ```

## Notes
*   If Qsys generation fails, refer to `hw/quartus/README_QSYS_FIX.txt` for manual repair instructions.
*   The `build_fpga.ps1` script is an alternative if you have already fixed Qsys manually.
