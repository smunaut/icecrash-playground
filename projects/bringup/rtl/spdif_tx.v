/*
 * spdif_tx.v
 *
 * vim: ts=4 sw=4
 *
 * SPDIF TX encoding module
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module spdif_tx #(
	parameter integer ACC_STEP  = 125, /* (sys_clk / (2 * spdif_clk)) * (1 << ACC_FRAC) */
	parameter integer ACC_FRAC  = 4    /* # fractional bits so that ACC_STEP is integer */
)(
	// SPDIF out
	output wire        spdif,
	output wire        spdif_tick,

	// Data in
	input  wire [23:0] audio_l,
	input  wire [23:0] audio_r,
	output reg         ack,

	input  wire        mode,	// 0=PCM, 1=IEC 61937
	input  wire        valid,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	// Constants
	// ---------

	localparam integer ACC_WIDTH = $clog2(ACC_STEP - (1<<ACC_FRAC)) + 1;
	localparam integer AL = ACC_WIDTH - 1;

	localparam [AL:0] ACC_INC0 = -(1 << ACC_FRAC);
	localparam [AL:0] ACC_INC1 = ACC_STEP - (1 << ACC_FRAC);


	// Signals
	// -------

	// Sub Frame
	reg  [ 8:0] sf_cnt;
	reg         sf_first;
	wire        sf_last;
	wire        sf_low;

	reg         sf_csb;
	reg  [ 1:0] sf_preamble;
	reg  [26:0] sf_payload;
	wire        sf_ack;

	// Tick
	reg [AL:0] tick_cnt;
	wire       tick;


	// Sub Frame
	// ---------

	// Counter
	always @(posedge clk or posedge rst)
		if (rst) begin
			sf_first <= 1'b0;
			sf_cnt   <= 9'd0;
		end else if (sf_ack) begin
			sf_first <= sf_last;
			sf_cnt   <= sf_last ? 9'd0 : (sf_cnt + 1);
		end

	assign sf_last = sf_cnt == 9'h17f;
	assign sf_low  = ~|sf_cnt[8:3];

	// Channel status
		// Really only some LSBs are used at all
		// [191:4] = 0
		// [  3:0] = 0100 for PCM
		// [  3:0] = 0110 for IEC 61937
	always @(*)
		if (sf_low)
			sf_csb = (mode ? 4'b0110 : 4'b0100) >> sf_cnt[2:1];
		else
			sf_csb = 1'b0;

	// Mux
	always @(posedge clk or posedge rst)
	begin
		if (rst) begin
			sf_preamble <= 2'b00;
			sf_payload  <= 27'h0000000;
		end else if (sf_ack) begin
			// Preamble
			sf_preamble[1] <= ~sf_first;
			sf_preamble[0] <=  sf_cnt[0];

			// Payload
			sf_payload[  26] <= sf_csb;
			sf_payload[  25] <= 1'b0;	// User Data
			sf_payload[  24] <= ~valid;	// Valid
			sf_payload[23:0] <= sf_cnt[0] ? audio_r : audio_l;
		end
	end

	// Ack when done
	always @(posedge clk)
		ack <= sf_ack & sf_cnt[0];


	// Low level word encoding
	// -----------------------

	spdif_word_code code_I (
		.word_preamble (sf_preamble),
		.word_payload  (sf_payload),
		.word_ack      (sf_ack),
		.bit_val       (spdif),
		.bit_ack       (tick),
		.clk           (clk),
		.rst           (rst)
	);


	// Tick at 6.144M
	// ---------------

	always @(posedge clk or posedge rst)
		if (rst)
			tick_cnt <= 0;
		else
			tick_cnt <= tick_cnt + (tick ? ACC_INC1 : ACC_INC0);

	assign tick = tick_cnt[AL];

	assign spdif_tick = tick;

endmodule // spdif_tx
