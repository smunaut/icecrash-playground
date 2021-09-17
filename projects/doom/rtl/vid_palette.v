/*
 * vid_palette.v
 *
 * Video palette memory
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module vid_palette (
	// Write port
	input  wire [ 7:0] w_addr_0,
	input  wire [23:0] w_data_0,
	input  wire        w_ena_0,

	// Read port
	input  wire [ 7:0] r_addr_0,
	output wire [23:0] r_data_1,

	// Clock
	input wire clk
);

	wire [31:0] w_data_i_0;
	wire [31:0] r_data_i_1;


	SB_RAM40_4K #(
		.WRITE_MODE(0),
		.READ_MODE(0)
	) ebr_lsb_I (
		.RDATA (r_data_i_1[15:0]),
		.RADDR ({3'b000, r_addr_0}),
		.RCLK  (clk),
		.RCLKE (1'b1),
		.RE    (1'b1),
		.WDATA (w_data_i_0[15:0]),
		.WADDR ({3'b000, w_addr_0}),
		.MASK  (16'h0000),
		.WCLK  (clk),
		.WCLKE (w_ena_0),
		.WE    (1'b1)
	);

	SB_RAM40_4K #(
		.WRITE_MODE(0),
		.READ_MODE(0)
	) ebr_msb_I (
		.RDATA (r_data_i_1[31:16]),
		.RADDR ({3'b000, r_addr_0}),
		.RCLK  (clk),
		.RCLKE (1'b1),
		.RE    (1'b1),
		.WDATA (w_data_i_0[31:16]),
		.WADDR ({3'b000, w_addr_0}),
		.MASK  (16'h0000),
		.WCLK  (clk),
		.WCLKE (w_ena_0),
		.WE    (1'b1)
	);

	assign w_data_i_0 = { 8'h00, w_data_0 };
	assign r_data_1 = r_data_i_1[23:0];

endmodule // vid_palette
