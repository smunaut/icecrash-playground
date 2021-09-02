/*
 * sysmgr.v
 *
 * vim: ts=4 sw=4
 *
 * CRG generating:
 *  - clk_usb -  48     MHz from internal SB_HFOSC for USB
 *  - clk_1x  -  25.125 MHz for main logic
 *  - clk_4x  - 100.5   MHz for QPI memory
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module sysmgr (
	// Inputs
	input  wire rst_in,
	input  wire clk_in,

	// System
	output wire clk_1x,
	output wire clk_4x,
	output wire sync_4x,
	output wire rst_sys,

	// USB
	output wire clk_usb,
	output wire rst_usb
);

	// Signals
	// -------

	// Misc
	wire     pll_lock;

	// System reset
	reg [3:0] rst_sys_cnt;
	reg       rst_sys_i;

	// USB reset
	reg [3:0] rst_usb_cnt;
	reg       rst_usb_i;


	// System clock
	// ------------

	// PLL
	SB_PLL40_2F_PAD #(
		.FEEDBACK_PATH       ("SIMPLE"),
		.DIVR                (4'b0000),
		.DIVF                (7'b1000010),
		.DIVQ                (3'b011),
		.FILTER_RANGE        (3'b001),
		.PLLOUT_SELECT_PORTA ("GENCLK"),
		.PLLOUT_SELECT_PORTB ("SHIFTREG_0deg")
	) pll_I (
		.PACKAGEPIN    (clk_in),
		.PLLOUTGLOBALA (clk_4x),
		.PLLOUTGLOBALB (clk_1x),
		.RESETB        (~rst_in),
		.LOCK          (pll_lock)
	);

	// SERDES sync signal
	ice40_serdes_sync #(
		.PHASE      (2),
		.NEG_EDGE   (0),
		.GLOBAL_BUF (0),
		.LOCAL_BUF  (0),
		.BEL_COL    ("X21"),
		.BEL_ROW    ("Y4"),
	) sync_4x_I (
		.clk_slow (clk_1x),
		.clk_fast (clk_4x),
		.rst      (rst_sys),
		.sync     (sync_4x)
	);

	// Reset generation
	always @(posedge clk_1x or negedge pll_lock)
		if (~pll_lock)
			rst_sys_cnt <= 4'h8;
		else if (rst_sys_i)
			rst_sys_cnt <= rst_sys_cnt + 1;

	assign rst_sys_i = rst_sys_cnt[3];

	SB_GB rst_sys_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (rst_sys_i),
		.GLOBAL_BUFFER_OUTPUT         (rst_sys)
	);


	// USB clock
	// ---------

	// HFOSC (48 MHz source)
	SB_HFOSC #(
		.CLKHF_DIV("0b00")
	) osc_I (
		.CLKHFPU (1'b1),
		.CLKHFEN (1'b1),
		.CLKHF   (clk_usb)
	);

	// Reset generation
	always @(posedge clk_usb or negedge pll_lock)
		if (~pll_lock)
			rst_usb_cnt <= 4'h8;
		else if (rst_usb_i)
			rst_usb_cnt <= rst_usb_cnt + 1;

	assign rst_usb_i = rst_usb_cnt[3];

	SB_GB rst_usb_gbuf_I (
		.USER_SIGNAL_TO_GLOBAL_BUFFER (rst_usb_i),
		.GLOBAL_BUFFER_OUTPUT         (rst_usb)
	);

endmodule // sysmgr
