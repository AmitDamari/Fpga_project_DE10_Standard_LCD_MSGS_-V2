# =============================================================================
# run_sim.tcl — ModelSim / QuestaSim simulation runner
# Project: DE10-Standard LCD Message System
#
# Usage from ModelSim transcript:
#   cd <workspace_root>
#   do sim/scripts/run_sim.tcl
#
# Or from command line:
#   vsim -do sim/scripts/run_sim.tcl -c
# =============================================================================

# --- Workspace root (relative to where vsim is launched) ---
set ROOT [file normalize [file dirname [file dirname [info script]]]]
set RTL  "$ROOT/hw/rtl"
set TBH  "$ROOT/hw/sim/testbenches"

# --- Results directory ---
file mkdir "$ROOT/sim/results"

# =============================================================================
# Helper: compile + simulate one testbench
# =============================================================================
proc run_tb {name tb_file rtl_files} {
    global ROOT

    puts ""
    puts "=================================================================="
    puts "  $name"
    puts "=================================================================="

    # Create & map a fresh work library
    if {[file exists work]} { vdel -all -lib work }
    vlib work
    vmap work work

    # Compile RTL files
    foreach f $rtl_files {
        if {[catch {vlog -sv $f} err]} {
            puts "  ERROR compiling $f: $err"
            return 0
        }
    }

    # Compile testbench
    if {[catch {vlog -sv $tb_file} err]} {
        puts "  ERROR compiling $tb_file: $err"
        return 0
    }

    # Get module name from file name (strip path and extension)
    set module [file rootname [file tail $tb_file]]

    # Run simulation
    vsim -quiet -lib work $module
    add wave -r *
    run -all
    puts "  Done: $name"
    return 1
}

# =============================================================================
# PHASE 1 — Unit tests
# =============================================================================

run_tb "button_debouncer (unit)" \
    "$TBH/tb_button_debouncer.v" \
    [list "$RTL/button_debouncer.v"]

run_tb "button_edge_detector" \
    "$TBH/tb_button_edge_detector.v" \
    [list "$RTL/button_edge_detector.v"]

run_tb "idle_timer" \
    "$TBH/tb_idle_timer.v" \
    [list "$RTL/idle_timer.v"]

run_tb "hex_display" \
    "$TBH/tb_hex_display.v" \
    [list "$RTL/hex_display.v"]

# =============================================================================
# PHASE 2 — Integration test
# =============================================================================

run_tb "fpga_msg_controller (integration)" \
    "$TBH/tb_fpga_msg_controller.v" \
    [list \
        "$RTL/fpga_msg_controller.v" \
        "$RTL/button_debouncer.v" \
        "$RTL/button_edge_detector.v" \
        "$RTL/idle_timer.v" \
        "$RTL/hex_display.v" \
    ]

puts ""
puts "=================================================================="
puts "  All simulations complete."
puts "  Check transcript above for PASS/FAIL results."
puts "=================================================================="
