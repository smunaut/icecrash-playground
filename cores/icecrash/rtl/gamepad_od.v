/*
 * gamepad_od.v
 *
 * "On-Demand" version of gamepad.
 * This only scans one controller and only when requested.
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module gamepad_od #(
	parameter integer DIV = 150,
	parameter integer SEL_WIDTH = 1,	// Select line width
	parameter integer DATA_WIDTH = 2,	// Number of parallel
	parameter integer REG_WIDTH = 12,	// Shift Register width

	// auto-set
	parameter integer SL = SEL_WIDTH ? (SEL_WIDTH - 1) : 0,				// Sel line left bound
	parameter integer ML = DATA_WIDTH > 1 ? $clog2(DATA_WIDTH) : 0,		// Mux control left bound
	parameter integer DL = DATA_WIDTH - 1,								// Data in left bound
	parameter integer VL = ((REG_WIDTH * DATA_WIDTH) << SEL_WIDTH) - 1	// Value out left bound
)(
	// Controller
	output wire [SL:0] gp_sel,
	input  wire [DL:0] gp_data,
	output reg         gp_latch,
	output reg         gp_clk,

	// Current value
	output wire [15:0] gp_value,

	// Control
	input  wire        ctrl_go,
	input  wire [SL:0] ctrl_sel,	// Controls gp_sel lines
	input  wire [ML:0] ctrl_mux,	// Selects between gp_data lines
	output wire        ctrl_rdy,

	// Clock / Reset
	input  wire        clk,
	input  wire        rst
);

	localparam integer TL = $clog2(DIV);		// Divider counter left bound
	localparam integer BL = $clog2(REG_WIDTH);	// Bit counter left bound
	localparam integer RL = REG_WIDTH - 1;		// Shift Register left bound


	// Signals
	// -------

	// FSM
	localparam [2:0]
		ST_IDLE      = 0,
		ST_PRE_PAUSE = 1,
		ST_LATCH     = 2,
		ST_CLK_HI    = 3,
		ST_CLK_LO    = 4,
		ST_DONE      = 5;

	reg   [2:0] state;
	reg   [2:0] state_nxt;

	// Current req
	reg  [SL:0] cur_sel;
	reg  [ML:0] cur_mux;

	// Tick
	reg  [TL:0] tick_cnt;
	wire        tick;

	// Bit-Counter
	reg  [BL:0] bit_cnt;
	wire        bit_last;
	wire        bit_shift;

	// Shift register
	reg         shift_in;
	reg  [RL:0] shift_reg;


	// FSM
	// ---

	// State register
	always @(posedge clk)
		if (rst)
			state <= ST_IDLE;
		else
			state <= state_nxt;

	// Next-state logic
	always @(*)
	begin
		// Default is no-change
		state_nxt = state;

		// Transitions
		case (state)
			ST_IDLE:
				if (ctrl_go)
					state_nxt = ST_PRE_PAUSE;

			ST_PRE_PAUSE:
				if (tick)
					state_nxt = ST_LATCH;

			ST_LATCH:
				if (tick)
					state_nxt = ST_CLK_LO;

			ST_CLK_HI:
				if (tick)
					state_nxt = bit_last ? ST_DONE : ST_CLK_LO;

			ST_CLK_LO:
				if (tick)
					state_nxt = ST_CLK_HI;

			ST_DONE:
				state_nxt = ST_IDLE;
		endcase
	end


	// Control IF
	// ----------

	assign ctrl_rdy = (state == ST_IDLE);

	always @(posedge clk)
		if (ctrl_go & ctrl_rdy) begin
			cur_sel <= ctrl_sel;
			cur_mux <= ctrl_mux;
		end


	// Tick
	// ----

	always @(posedge clk)
		if (state == ST_IDLE)
			tick_cnt <= 0;
		else
			tick_cnt <= { 1'b0, tick_cnt[TL-1:0] } + 1;

	assign tick = tick_cnt[TL];


	// Bit Counter
	// -----------

	always @(posedge clk)
		if (state == ST_LATCH)
			bit_cnt <= REG_WIDTH - 1;
		else
			bit_cnt <= bit_cnt + {(BL+1){bit_shift}};

	assign bit_last = bit_cnt[BL];
	assign bit_shift = (state == ST_CLK_LO) & tick;


	// Shift registers
	// ---------------

	integer i;

	always @(posedge clk)
		if (bit_shift)
			shift_reg <= { ~shift_in, shift_reg[RL:1] };


	// Game pad IO
	// -----------

	always @(posedge clk)
	begin
		gp_latch <= (state == ST_LATCH);
		gp_clk   <= (state == ST_CLK_HI);
	end

	assign gp_sel = cur_sel;

	always @(posedge clk)
		shift_in <= (DATA_WIDTH > 1) ? gp_data[cur_mux] : gp_data[0];


	// Final value
	// -----------

	assign gp_value = shift_reg;

endmodule // gamepad_od
