/*
 * gamepad_od_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module gamepad_od_wb #(
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

	localparam integer ML = DATA_WIDTH > 1 ? $clog2(DATA_WIDTH) : 0;	// Mux control left bound
	localparam integer RL = REG_WIDTH - 1;								// Shift Register left bound
	localparam integer N = DATA_WIDTH << SEL_WIDTH;						// Number of game pads

	wire [RL:0] gp_value;

	wire        ctrl_go;
	wire [SL:0] ctrl_sel;
	wire [ML:0] ctrl_mux;
	wire        ctrl_rdy;

	wire        bus_clr;


	// Core
	// ----

	gamepad_od #(
		.DIV        (DIV),
		.SEL_WIDTH  (SEL_WIDTH),
		.DATA_WIDTH (DATA_WIDTH),
		.REG_WIDTH  (REG_WIDTH)
	) core_I (
		.gp_sel   (gp_sel),
		.gp_data  (gp_data),
		.gp_latch (gp_latch),
		.gp_clk   (gp_clk),
		.gp_value (gp_value),
		.ctrl_go  (ctrl_go),
		.ctrl_sel (ctrl_sel),
		.ctrl_mux (ctrl_mux),
		.ctrl_rdy (ctrl_rdy),
		.clk      (clk),
		.rst      (rst)
	);


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
			wb_rdata[RL:0] <= gp_value;
			wb_rdata[31]   <= ctrl_rdy;
		end

	// "CSR"
	assign ctrl_go = wb_ack & wb_we;
	assign { ctrl_sel, ctrl_mux } = wb_wdata;

endmodule // gamepad_od_wb
