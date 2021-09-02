/*
 * top.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2021  Sylvain Munaut <tnt@246tNt.com>
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

`default_nettype none

module top (
	// HDMI video
	output wire [11:0] hdmi_data,
	output wire        hdmi_idck,
	output wire        hdmi_de,
	output wire        hdmi_hsync,
	output wire        hdmi_vsync,

	// HDMI sound
	output wire        spdif,

	// I2C
	inout  wire        i2c_scl,
	inout  wire        i2c_sda,

	// Controller
	output wire        gp_sel,
	input  wire  [1:0] gp_data,
	output wire        gp_latch,
	output wire        gp_clk,

	// USB
	inout  wire        usb_dp,
	inout  wire        usb_dn,
	output wire        usb_pu,

	// SPI
	output wire        spi_sck,
	inout  wire  [3:0] spi_io,
	output wire  [1:0] spi_cs_n,

	// Button
	input  wire        btn,

	// Leds
	output wire  [2:0] rgb,

	// Clock
	input  wire        clk_in
);

	// Config
	localparam integer WB_N = 3;

	localparam integer DL = (32*WB_N)-1;
	localparam integer CL = WB_N-1;


	// Signals
	// -------

	// Wishbone bus
	wire [31:0] wb_wdata;
	wire [DL:0] wb_rdata;
	wire [15:0] wb_addr;
	wire        wb_we;
	wire [CL:0] wb_cyc;
	wire [CL:0] wb_ack;

	wire [31:0] aux_csr;

	// DFU helper
	wire        bootloader_req;
	wire        rst_req;

	// LEDs
	wire  [2:0] rgb_pwm;

	// Clock / Reset
	wire clk_1x;
	wire clk_4x;
	wire sync_4x;
	wire rst_sys;

	wire clk_usb;
	wire rst_usb;



	// USB <-> Wishbone bridge
	// -----------------------

	muacm2wb #(
		.WB_N(3)
	) wb_I (
		.usb_dp     (usb_dp),
		.usb_dn     (usb_dn),
		.usb_pu     (usb_pu),
		.usb_clk    (clk_usb),
		.usb_rst    (rst_usb),
		.wb_wdata   (wb_wdata),
		.wb_rdata   (wb_rdata),
		.wb_addr    (wb_addr),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc),
		.wb_ack     (wb_ack),
		.bootloader (bootloader_req),
		.clk        (clk_1x),
		.rst        (rst_sys)
	);


	// DFU helper
	// ----------

	dfu_helper #(
		.SAMP_TW  ( 7),
		.LONG_TW  (18),
		.BTN_MODE ( 3)
	) dfu_I (
		.boot_sel  (2'b01),
		.boot_now  (bootloader_req),
		.btn_in    (btn),
		.btn_tick  (1'b0),
		.btn_val   (),
		.btn_press (rst_req),
		.clk       (clk_1x),
		.rst       (rst_sys)
	);


	// LED
	// ---

	// Driver
	SB_RGBA_DRV #(
		.CURRENT_MODE("0b1"),
		.RGB0_CURRENT("0b000001"),
		.RGB1_CURRENT("0b000001"),
		.RGB2_CURRENT("0b000001")
	) rgb_drv_I (
		.RGBLEDEN (1'b1),
		.RGB0PWM  (rgb_pwm[0]),
		.RGB1PWM  (rgb_pwm[1]),
		.RGB2PWM  (rgb_pwm[2]),
		.CURREN   (1'b1),
		.RGB0     (rgb[0]),
		.RGB1     (rgb[1]),
		.RGB2     (rgb[2])
	);

	// Debug signals
	assign rgb_pwm[0] = 1'b0;
	assign rgb_pwm[1] = rst_sys;
	assign rgb_pwm[2] = rst_usb;


	// Clock/Reset Generation
	// ----------------------

	sysmgr sysmgr_I (
		.rst_in  (rst_req),
		.clk_in  (clk_in),
		.clk_1x  (clk_1x),
		.clk_4x  (clk_4x),
		.sync_4x (sync_4x),
		.rst_sys (rst_sys),
		.clk_usb (clk_usb),
		.rst_usb (rst_usb)
	);

endmodule // top
