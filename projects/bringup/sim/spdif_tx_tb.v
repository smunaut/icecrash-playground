/*
 * spdif_tx_tb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2020  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none
`timescale 1ns / 100ps

module spdif_tx_tb;

	// Signals
	// -------

	reg  [15:0] audio_val = 16'h0000;
	wire        audio_ack;
	wire        spdif;

	reg rst = 1'b1;
	reg clk = 1'b0;


	// DUT
	// ---

	// Encoder
	spdif_tx #(
		// Approximate 6.144 MHz clock from 25.125 MHz
		// (we get 6.137 which is 0.1% off)
		//.ACC_STEP (131),
		.ACC_STEP (132),
		.ACC_FRAC (  5)
	) spdif_I (
		.spdif      (spdif),
		.spdif_tick (),
		.audio_l    ({2'b00, audio_val, 6'b000000}),
		.audio_r    ({2'b00, audio_val, 6'b000000}),
		.ack        (audio_ack),
		.valid      (1'b1),
		.clk        (clk),
		.rst        (rst)
	);


	// Data source
	// -----------

	// Triangle wave generator (750 Hz at 48 ksps)
	always @(posedge clk)
		if (audio_ack)
			audio_val <= audio_val + 16'd1024;


	// Test bench
	// ----------

	// Setup recording
	initial begin
		$dumpfile("spdif_tx_tb.vcd");
		$dumpvars(0,spdif_tx_tb);
	end

	// Reset pulse
	initial begin
		# 200 rst = 0;
		# 10000000 $finish;
	end

	// Clocks
	always #19.9 clk = !clk;	// 25.125 MHz

endmodule // spdif_tx_tb
