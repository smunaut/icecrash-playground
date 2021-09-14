/*
 * gamepad_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module gamepad_tb;

	// Signals
	// -------

	wire        gp_sel;
	wire  [1:0] gp_data;
	wire        gp_latch;
	wire        gp_clk;

	wire [63:0] gp_value;

	reg rst = 1'b1;
	reg clk = 1'b0;


	// DUT
	// ---

	gamepad #(
		.DIV        (15),
		.SEL_WIDTH  (1),
		.DATA_WIDTH (2)
	) dut_I (
		.gp_sel   (gp_sel),
		.gp_data  (gp_data),
		.gp_latch (gp_latch),
		.gp_clk   (gp_clk),
		.gp_value (gp_value),
		.ctrl_run (1'b1),
		.clk      (clk),
		.rst      (rst)
	);


	// Test bench
	// ----------

	// Setup recording
	initial begin
		$dumpfile("gamepad_tb.vcd");
		$dumpvars(0,gamepad_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 100000 $finish;
	end

	// Clocks
	always #19.9 clk = !clk;	// 25.125 MHz

endmodule // gamepad_tb
