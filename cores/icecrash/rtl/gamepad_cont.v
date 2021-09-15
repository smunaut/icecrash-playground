/*
 * gamepad_cont.v
 *
 * "Continuous" version of gamepad.
 * This scans all controllers in a loop and output the latest value for each
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module gamepad_cont #(
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

	// Current value
	output wire [VL:0] gp_value,

	// Control
	input  wire        ctrl_run,

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
		ST_NEXT      = 5;

	reg [2:0] state;
	reg [2:0] state_nxt;

	// Tick
	reg  [TL:0] tick_cnt;
	wire        tick;

	// Bit-Counter
	reg  [BL:0] bit_cnt;
	wire        bit_last;
	wire        bit_shift;

	// Shift register
	reg  [RL:0] shift_reg[0:DL];

	// Current value
	reg  [RL:0] value[0:(1<<SEL_WIDTH)-1][0:DL];


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
				if (ctrl_run)
					state_nxt = ST_PRE_PAUSE;

			ST_PRE_PAUSE:
				if (tick)
					state_nxt = ST_LATCH;

			ST_LATCH:
				if (tick)
					state_nxt = ST_CLK_LO;

			ST_CLK_HI:
				if (tick)
					state_nxt = bit_last ? ST_NEXT : ST_CLK_LO;

			ST_CLK_LO:
				if (tick)
					state_nxt = ST_CLK_HI;

			ST_NEXT:
				state_nxt = ctrl_run ? ST_PRE_PAUSE : ST_IDLE;
		endcase
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
			for (i=0; i<DATA_WIDTH; i=i+1)
				shift_reg[i] = { ~gp_data[i], shift_reg[i][RL:1] };


	// Game pad control
	// ----------------

	always @(posedge clk)
	begin
		gp_latch <= (state == ST_LATCH);
		gp_clk   <= (state == ST_CLK_HI);
	end

	always @(posedge clk)
		if (state == ST_IDLE)
			gp_sel <= 0;
		else if (SEL_WIDTH > 0)
			gp_sel <= gp_sel + (state == ST_NEXT);


	// Final value
	// -----------

	genvar j;
	genvar k;

	for (j=0; j<(1<<SEL_WIDTH); j=j+1)
		for (k=0; k<DATA_WIDTH; k=k+1)
		begin
			// Capture
			always @(posedge clk)
				if ((state == ST_NEXT) & (gp_sel == j))
					value[j][k] <= shift_reg[k];

			// Mapping to flat value
			assign gp_value[(j*DATA_WIDTH+k)*REG_WIDTH+:REG_WIDTH] = value[j][k];
		end

endmodule // gamepad_cont
