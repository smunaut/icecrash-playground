/*
 * vid_test.v
 *
 * vim: ts=4 sw=4
 *
 * Video test top-level
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
	wire tg_hsync_0;
	wire tg_vsync_0;
	wire tg_active_0;
	wire tg_h_first_0;
	wire tg_h_last_0;
	wire tg_v_first_0;
	wire tg_v_last_0;

	// Position
	reg [11:0] pos_x_0;
	reg [11:0] pos_y_0;


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
		.vid_hsync   (tg_hsync_0),
		.vid_vsync   (tg_vsync_0),
		.vid_active  (tg_active_0),
		.vid_h_first (tg_h_first_0),
		.vid_h_last  (tg_h_last_0),
		.vid_v_first (tg_v_first_0),
		.vid_v_last  (tg_v_last_0),
		.clk         (clk),
		.rst         (rst)
	);


	// Position counter
	// ----------------

	always @(posedge clk)
	begin
		// X
		pos_x_0 <= (pos_x_0 + tg_active_0) & {12{~tg_h_last_0}};

		// Y
		if (tg_h_last_0 & tg_active_0)
			pos_y_0 <= (pos_y_0 + 1) & {12{~tg_v_last_0}};
	end


	// Some dumb pattern
	// -----------------

	assign out_data[23:16] = pos_x_0[7:0];                         // R
	assign out_data[15: 8] = {8{~|pos_x_0[3:0] | ~|pos_y_0[3:0]}}; // G
	assign out_data[ 7: 0] = pos_y_0[7:0];                         // B
	assign out_hsync = tg_hsync_0;
	assign out_vsync = tg_vsync_0;
	assign out_de    = tg_active_0;

endmodule // vid_test
