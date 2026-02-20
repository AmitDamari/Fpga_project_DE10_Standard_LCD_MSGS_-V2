// (C) 2001-2021 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other
// software and tools, and its AMPP partner logic functions, and any output
// files from any of the foregoing (including device programming or simulation
// files), and any associated documentation or information are expressly subject
// to the terms and conditions of the Intel Program License Subscription
// Agreement, Intel FPGA IP License Agreement, or other applicable
// license agreement, including, without limitation, that your use is for the
// sole purpose of programming logic devices manufactured by Intel and sold by
// Intel or its authorized distributors.  Please refer to the applicable
// agreement for further details.

// ------------------------------------------------------------------------------
//| Avalon Streaming Error Adapter
// ------------------------------------------------------------------------------
// Generated for soc_system_mm_interconnect_0 avalon_st_adapter (34-bit data)

`timescale 1ns / 100ps

module soc_system_mm_interconnect_0_avalon_st_adapter_error_adapter_0
(
  // Interface: in
  output reg         in_ready,
  input              in_valid,
  input [33: 0]      in_data,
  // Interface: out
  input              out_ready,
  output reg         out_valid,
  output reg [33: 0] out_data,
  output reg [0:0]   out_error,
  // Interface: clk
  input              clk,
  // Interface: reset
  input              reset_n
);

  // ---------------------------------------------------------------------
  //| Pass-through Mapping
  // ---------------------------------------------------------------------
  always_comb begin
    in_ready  = out_ready;
    out_valid = in_valid;
    out_data  = in_data;
  end

  // ---------------------------------------------------------------------
  //| Error Mapping (no input error → output error = 0)
  // ---------------------------------------------------------------------
  always_comb begin
    out_error = 1'b0;
  end

endmodule
