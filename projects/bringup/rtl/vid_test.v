/*
 * vid_tgen.v
 *
 * vim: ts=4 sw=4
 *
 * Video Timing Generator
 *
 * Copyright (C) 2019-2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_test (
	// Video out
	output wire [23:0] out_data,
	output wire        out_hsync,
	output wire        out_vsync,
	output wire        out_de,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// Timing gen
	wire tg_hsync;
	wire tg_vsync;
	wire tg_active;
	wire tg_h_first;
	wire tg_h_last;
	wire tg_v_first;
	wire tg_v_last;


	// Timing generator
	// ----------------

	vid_tgen #(
		.H_WIDTH  ( 12),
		.H_FP     ( 16),
		.H_SYNC   ( 96),
		.H_BP     ( 48),
		.H_ACTIVE (640),
		.V_WIDTH  ( 12),
		.V_FP     ( 10),
		.V_SYNC   (  2),
		.V_BP     ( 33),
		.V_ACTIVE (480)
	) tgen_I (
		.vid_hsync   (tg_hsync),
		.vid_vsync   (tg_vsync),
		.vid_active  (tg_active),
		.vid_h_first (tg_h_first),
		.vid_h_last  (tg_h_last ),
		.vid_v_first (tg_v_first),
		.vid_v_last  (tg_v_last),
		.clk         (clk),
		.rst         (rst)
	);


	assign out_data  = 24'h000000;
	assign out_hsync = tg_hsync;
	assign out_vsync = tg_vsync;
	assign out_de    = tg_active;

endmodule // vid_test
