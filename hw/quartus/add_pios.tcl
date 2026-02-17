package require -exact qsys 14.0

# Open existing system
load_system soc_system.qsys

# ---------------------------------------------------------
# Add fsm_status_pio (8-bit Input @ 0x6000)
# ---------------------------------------------------------
if {[lsearch [get_instances] fsm_status_pio] == -1} {
    send_message info "Adding fsm_status_pio..."
    add_instance fsm_status_pio altera_avalon_pio
    set_instance_parameter_value fsm_status_pio width 8
    set_instance_parameter_value fsm_status_pio direction Input
    
    # Connections
    add_connection clk_0.clk fsm_status_pio.clk
    add_connection clk_0.clk_reset fsm_status_pio.reset
    add_connection mm_bridge_0.m0 fsm_status_pio.s1
    set_connection_parameter_value mm_bridge_0.m0/fsm_status_pio.s1 baseAddress 0x6000
    
    # Export conduit
    add_interface fsm_status_pio_external_connection conduit end
    set_interface_property fsm_status_pio_external_connection EXPORT_OF fsm_status_pio.external_connection
} else {
    send_message info "fsm_status_pio already exists."
}

# ---------------------------------------------------------
# Add timer_status_pio (8-bit Input @ 0x7000)
# ---------------------------------------------------------
if {[lsearch [get_instances] timer_status_pio] == -1} {
    send_message info "Adding timer_status_pio..."
    add_instance timer_status_pio altera_avalon_pio
    set_instance_parameter_value timer_status_pio width 8
    set_instance_parameter_value timer_status_pio direction Input
    
    # Connections
    add_connection clk_0.clk timer_status_pio.clk
    add_connection clk_0.clk_reset timer_status_pio.reset
    add_connection mm_bridge_0.m0 timer_status_pio.s1
    set_connection_parameter_value mm_bridge_0.m0/timer_status_pio.s1 baseAddress 0x7000
    
    # Export conduit
    add_interface timer_status_pio_external_connection conduit end
    set_interface_property timer_status_pio_external_connection EXPORT_OF timer_status_pio.external_connection
} else {
    send_message info "timer_status_pio already exists."
}

# Save and exit
save_system soc_system.qsys
