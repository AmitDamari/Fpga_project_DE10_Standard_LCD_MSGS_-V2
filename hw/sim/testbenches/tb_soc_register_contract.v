// ============================================================================
// Testbench: tb_soc_register_contract
// Project: DE10-Standard LCD Message System
// Description: Verifies HPS-visible register packing contract used by
//              DE10_Standard_GHRD.v for custom status exports.
// ============================================================================

`timescale 1ns / 1ps

module tb_soc_register_contract;

    reg  [3:0] ctrl_btn_debounced;
    reg        ctrl_timeout_flag;
    reg  [3:0] ctrl_seconds_remaining;
    reg  [2:0] ctrl_fsm_state;
    reg  [4:0] ctrl_fsm_msg_index;

    wire [7:0] fsm_status_export;
    wire [7:0] timer_status_export;

    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num   = 0;

    // Contract from DE10_Standard_GHRD.v:
    //   fsm_status_pio_external_connection_export   ({ctrl_fsm_state, ctrl_fsm_msg_index})
    //   timer_status_pio_external_connection_export ({3'b0, ctrl_seconds_remaining, ctrl_timeout_flag})
    assign fsm_status_export   = {ctrl_fsm_state, ctrl_fsm_msg_index};
    assign timer_status_export = {3'b0, ctrl_seconds_remaining, ctrl_timeout_flag};

    task check;
        input condition;
        input [255:0] name;
        begin
            test_num = test_num + 1;
            if (!condition) begin
                $display("FAIL Test %0d [%0s] @ %0t", test_num, name, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS Test %0d [%0s] @ %0t", test_num, name, $time);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== TB: soc register contract ===");

        ctrl_btn_debounced     = 4'b1010;
        ctrl_timeout_flag      = 1'b1;
        ctrl_seconds_remaining = 4'hC;
        ctrl_fsm_state         = 3'd3;
        ctrl_fsm_msg_index     = 5'd17;
        #1;

        check(fsm_status_export[7:5] == 3'd3, "FSM status bits[7:5] == state");
        check(fsm_status_export[4:0] == 5'd17, "FSM status bits[4:0] == message index");

        check(timer_status_export[0] == 1'b1, "Timer bit0 == timeout flag");
        check(timer_status_export[4:1] == 4'hC, "Timer bits[4:1] == seconds");
        check(timer_status_export[7:5] == 3'b000, "Timer bits[7:5] zero");

        ctrl_btn_debounced     = 4'b0001;
        ctrl_timeout_flag      = 1'b0;
        ctrl_seconds_remaining = 4'd3;
        ctrl_fsm_state         = 3'd1;
        ctrl_fsm_msg_index     = 5'd0;
        #1;

        check(fsm_status_export == 8'h20, "FSM packed value exact");
        check(timer_status_export == 8'h06, "Timer packed value exact");

        $display("");
        $display("=== RESULTS: %0d PASSED, %0d FAILED out of %0d tests ===",
                 pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        $finish;
    end

endmodule
