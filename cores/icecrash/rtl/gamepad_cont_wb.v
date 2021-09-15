/*
 * gamepad_cont_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module gamepad_cont_wb #(
	parameter integer DIV = 150,
	parameter integer SEL_WIDTH = 1,	// Select line width
	parameter integer DATA_WIDTH = 2,	// Number of parallel
	parameter integer REG_WIDTH = 12,	// Shift Register width

	// auto-set
	parameter integer SL = SEL_WIDTH ? (SEL_WIDTH - 1) : 0,				// Sel line left bound
	parameter integer DL = DATA_WIDTH - 1,								// Data in left bound
	parameter integer VL = ((REG_WIDTH * DATA_WIDTH) << SEL_WIDTH) - 1	// Value out left bound
)(
	// Controller
	output reg  [SL:0] gp_sel,
	input  wire [DL:0] gp_data,
	output reg         gp_latch,
	output reg         gp_clk,

	// Wishbone
	input  wire  [3:0] wb_addr,
	input  wire [31:0] wb_wdata,
	output reg  [31:0] wb_rdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output reg         wb_ack,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	// Signals
	// -------

	localparam integer RL = REG_WIDTH - 1;			// Shift Register left bound
	localparam integer N = DATA_WIDTH << SEL_WIDTH;	// Number of game pads

	wire [VL:0] gp_value_flat;
	wire [RL:0] gp_value[0:N-1];

	reg         ctrl_run;

	wire        bus_clr;


	// Core
	// ----

	// Instance
	gamepad_cont #(
		.DIV        (DIV),
		.SEL_WIDTH  (SEL_WIDTH),
		.DATA_WIDTH (DATA_WIDTH),
		.REG_WIDTH  (REG_WIDTH)
	) core_I (
		.gp_sel   (gp_sel),
		.gp_data  (gp_data),
		.gp_latch (gp_latch),
		.gp_clk   (gp_clk),
		.gp_value (gp_value_flat),
		.ctrl_run (ctrl_run),
		.clk      (clk),
		.rst      (rst)
	);

	// Flat to array
	genvar i;

	for (i=0; i<N; i=i+1)
		assign gp_value[i] = gp_value_flat[i*REG_WIDTH+:REG_WIDTH];


	// Bus interface
	// -------------

	// Ack
	always @(posedge clk)
		wb_ack <= wb_cyc & ~wb_ack;

	// Read Mux
	assign bus_clr = ~wb_cyc | wb_ack;

	always @(posedge clk)
		if (bus_clr)
			wb_rdata <= 0;
		else begin
			wb_rdata <= 0;
			wb_rdata[RL:0] <= gp_value[wb_addr];
		end

	// "CSR"
	always @(posedge clk)
		if (rst)
			ctrl_run <= 1'b0;
		else if (wb_ack & wb_we)
			ctrl_run <= wb_wdata[0];

endmodule // gamepad_cont_wb
