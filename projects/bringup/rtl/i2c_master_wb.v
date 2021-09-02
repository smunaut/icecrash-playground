/*
 * i2c_master_wb.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module i2c_master_wb #(
	parameter integer DW = 3
)(
	// IOs
	output wire scl_oe,
	output wire sda_oe,
	input  wire sda_i,

	// Wishbone
	input  wire [31:0] wb_wdata,
	output wire [31:0] wb_rdata,
	input  wire        wb_we,
	input  wire        wb_cyc,
	output wire        wb_ack,

	output wire ready,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	wire [7:0] data_in;
	wire       ack_in;
	wire [1:0] cmd;
	wire       stb;
	wire [7:0] data_out;
	wire       ack_out;

	i2c_master #(
		.DW(DW)
	) core_I (
		.scl_oe   (scl_oe),
		.sda_oe   (sda_oe),
		.sda_i    (sda_i),
		.data_in  (data_in),
		.ack_in   (ack_in),
		.cmd      (cmd),
		.stb      (stb),
		.data_out (data_out),
		.ack_out  (ack_out),
		.ready    (ready),
		.clk      (clk),
		.rst      (rst)
	);

	assign wb_rdata = wb_cyc ? { ready, 22'd0, ack_out, data_out } : 32'h00000000;

	assign cmd      = wb_wdata[13:12];
	assign ack_in   = wb_wdata[8];
	assign data_in  = wb_wdata[7:0];

	assign stb      = wb_cyc & wb_we;

	assign wb_ack   = wb_cyc;

endmodule // i2c_master_wb
