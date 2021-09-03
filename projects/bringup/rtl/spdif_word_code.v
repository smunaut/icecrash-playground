/*
 * spdif_word_code.v
 *
 * vim: ts=4 sw=4
 *
 * Internal biphase coder for the SPDIF TX module
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spdif_word_code (
	// 27-bit word input
	input  wire [ 1:0] word_preamble,	// 00=B, 10=M, 11=W
	input  wire [26:0] word_payload,
	output wire        word_ack,

	// Encoded bi-phase bit output
	output reg         bit_val,
	input  wire        bit_ack,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	// Signals
	// -------

	// Word
	reg  [ 7:0] word_preamble_bits;
	wire [34:0] word_val;

	wire        pol;

	// Shift register
	reg  [34:0] shift_data;
	reg  [ 3:0] shift_cnt1;		// Preamble counter
	reg  [ 6:0] shift_cnt2;		// Total counter
	wire        shift_last;

	(* keep *)
	wire        shift_ce;

	// Bi-Phase code
	wire        bp_in;
	wire        bp_cycle;


	// Next-Word value
	// ---------------

	always @(*)
		case (word_preamble)
			2'b00:   word_preamble_bits = 8'b00010111;	// B
			2'b10:   word_preamble_bits = 8'b01000111;	// M
			2'b11:   word_preamble_bits = 8'b00100111;	// W
			default: word_preamble_bits = 8'bxxxxxxxx;
		endcase

	assign word_val[34: 8] =  word_payload;
	assign word_val[ 7: 0] =  word_preamble_bits ^ { 8{pol} };

	assign pol = bit_val ^ bp_in;


	// Shift regiter
	// -------------

	// Counters
	always @(posedge clk or posedge rst)
		if (rst) begin
			shift_cnt1 <= 0;
			shift_cnt2 <= 0;
		end else if (bit_ack) begin
			shift_cnt1 <= shift_last ? 4'd8 : (shift_cnt1 + {3'b000, shift_cnt1[3]});
			shift_cnt2 <= shift_last ? 7'd1 : (shift_cnt2 + 1);
		end

	assign shift_last = shift_cnt2[6];

	// Data
	always @(posedge clk or posedge rst)
		if (rst)
			shift_data <= 0;
		else if (shift_ce)
			shift_data <= shift_last ? word_val : { ^shift_data[34:8], shift_data[34:1] };

	assign shift_ce = bit_ack & (shift_cnt1[3] | ~shift_cnt2[0]);

	assign word_ack = bit_ack & shift_last;


	// Bi-Phase coding
	// ---------------

	assign bp_in    = shift_data[0];
	assign bp_cycle = shift_cnt2[0];

	always @(posedge clk or posedge rst)
		if (rst)
			bit_val <= 1'b0;
		else if (bit_ack)
			bit_val <= shift_cnt1[3] ? bp_in : (bit_val ^ (bp_in || bp_cycle));

endmodule // spdif_word_code
