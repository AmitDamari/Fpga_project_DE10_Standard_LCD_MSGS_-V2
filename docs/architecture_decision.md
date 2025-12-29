# Architecture Decision: Nios II to HPS Pivot

## Date
2025-12-29

## Status
DECIDED - Pivot to HPS hybrid architecture

## Context
Originally planned to use Nios II soft-core processor on FPGA fabric
to control ST7565 LCD via SPI through GPIO headers.

## Discovery
The LCD module on DE10-Standard is physically connected to:
- **LTC Header** (Linear Technology Connector)
- **HPS side** of the board (not FPGA GPIO)
- Uses **HPS SPI** controller

The pushbuttons (KEY[0-3]) are connected to:
- **FPGA pins** (not directly accessible from HPS)

## Decision
Use **hybrid FPGA-HPS architecture**:
1. FPGA: Handle button debouncing, expose state via LW H2F bridge
2. HPS: Run FSM, control LCD using original Terasic drivers

## Consequences
### Positive
- LCD drivers work unchanged (Terasic code)
- Utilize existing hardware connections
- Learn HPS-FPGA bridge communication

### Negative
- More complex architecture
- Need cross-compiler for ARM
- Two compilation flows (Quartus + ARM GCC)

## Alternatives Considered
1. **External LCD on GPIO** - Rejected (no spare LCD module)
2. **Pure HPS** - Rejected (buttons on FPGA side)
3. **Reroute LCD to FPGA** - Rejected (hardware modification)

## References
- DE10-Standard User Manual
- Terasic hps_lcd demo code
