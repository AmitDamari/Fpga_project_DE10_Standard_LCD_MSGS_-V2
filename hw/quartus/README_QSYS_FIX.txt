INSTRUCTIONS TO FIX QSYS (SOC_SYSTEM.QSYS)

The automated update of soc_system.qsys failed validation (XML error).
Please perform the following steps in Platform Designer (Qsys) to finish the design:

1. Open Platform Designer and load 'soc_system.qsys'.
2. If you see 'fsm_status_pio' or 'timer_status_pio' with errors (Red X), delete them.
3. Add a new 'PIO (Parallel I/O)' INTEL FPGA IP component:
   - Name: fsm_status_pio
   - Width: 8 bits
   - Direction: Input
   - Connections:
     - clk -> clk_0.clk
     - reset -> clk_0.clk_in_reset
     - s1 -> mm_bridge_0.m0 (Base Address: 0x00006000)
   - Export: Double-click external_connection column to export.
     - Rename export to: fsm_status_pio_external_connection

4. Add another 'PIO' component:
   - Name: timer_status_pio
   - Width: 8 bits
   - Direction: Input
   - Connections:
     - clk -> clk_0.clk
     - reset -> clk_0.clk_in_reset
     - s1 -> mm_bridge_0.m0 (Base Address: 0x00007000)
   - Export: Double-click external_connection column to export.
     - Rename export to: timer_status_pio_external_connection

5. Click 'Generate HDL' (bottom right) -> 'Generate'.
6. Once finished, exit Platform Designer.
7. Run the provided build script: 'powershell .\hw\quartus\build_fpga.ps1'
