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
	/*
	 * The spdif bitrate should be 3.072M (classic 2 channel 48 kHz), which
	 * means for the biphase code we need to generate a 6.144 MHz tick.
	 *
	 * To approximate it, ACC_STEP should be set to :
	 * (sys_clk / (2 * spdif_bitrate)) * (1 << ACC_FRAC)
	 *
	 * The actual resulting rate will be :
	 * (sys_clk * (1 << ACC_FRAC)) / (2 * ACC_STEP)
	 */
	parameter integer ACC_STEP  = 125,
	parameter integer ACC_FRAC  = 4    /* # fractional bits so that ACC_STEP is integer */
)(
	// SPDIF out
	output wire        spdif,
	output wire        spdif_tick,

	// Data in
	input  wire [23:0] audio_l,
	input  wire [23:0] audio_r,
	output reg         ack,

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

	// Channel status
	always @(*)
		if (sf_cnt[8:1] < 40)
			sf_csb = {
				4'hd,	// [39:36] Original sampling frequency: 48 kHz
				3'b101,	// [35:33] Sample word length = 24 bits
				1'b1,	//    [32] Maxmimum audio sample length is 24 bits
				2'b00,	// N/A
				2'b00,	// [29:28] Level 2 clock accuracy
				4'h2,	// [27:24] Sampling frequency: 48 kHz
				4'h0,	// [23:20] Channel number: Do not take into account
				4'h0,	// [19:16] Source number: Do not take into account
				8'h00,	// [15: 8] Category code
				2'b00,	//  [7: 6] Mode 0
				3'b000,	//  [5: 3] 2 audio channel without pre-emphasis
				1'b1,	//    [ 2] No copyright
				1'b0,	//    [ 1] Audio is PCM samples
				1'b0	//    [ 0] Consumer use
			} >> sf_cnt[8:1];
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
