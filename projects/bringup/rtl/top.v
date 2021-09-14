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
	localparam integer WB_N = 2;

	localparam integer DL = (32*WB_N)-1;
	localparam integer CL = WB_N-1;


	// Signals
	// -------

	// Wishbone bus
	wire [31:0] wb_wdata;
	wire [DL:0] wb_rdata_flat;
	wire [31:0] wb_rdata [0:WB_N-1];
	wire [15:0] wb_addr;
	wire        wb_we;
	wire [CL:0] wb_cyc;
	wire [CL:0] wb_ack;

	wire [31:0] aux_csr;

	// Video
	wire [23:0] vid_data;
	wire        vid_hsync;
	wire        vid_vsync;
	wire        vid_de;

	// Audio
	reg  [15:0] audio_val;
	wire        audio_ack;

	// I2C
	wire        i2c_scl_oe;
	wire        i2c_sda_oe;
	wire        i2c_sda_i;

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



	// Video
	// -----

	// Test-pattern
	vid_test hdmi_pgen_I (
		.out_data  (vid_data),
		.out_hsync (vid_hsync),
		.out_vsync (vid_vsync),
		.out_de    (vid_de),
		.clk       (clk_1x),
		.rst       (rst_sys)
	);

	// PHY
	hdmi_phy_ddr_1x #(
		.DW   (12),		// 12bits DDR
		.EDGE (1'b0)	// Falling edge first (match Sil9022 config !)
	) hdmi_phy_I (
		.hdmi_data  (hdmi_data),
		.hdmi_hsync (hdmi_hsync),
		.hdmi_vsync (hdmi_vsync),
		.hdmi_de    (hdmi_de),
		.hdmi_clk   (hdmi_idck),
		.in_data    (vid_data),
		.in_hsync   (vid_hsync),
		.in_vsync   (vid_vsync),
		.in_de      (vid_de),
		.clk        (clk_1x)
	);


	// I2C [0]
	// ---

	// Core
	i2c_master_wb #(
		.DW(4)
	) i2c_I (
		.scl_oe   (i2c_scl_oe),
		.sda_oe   (i2c_sda_oe),
		.sda_i    (i2c_sda_i),
		.wb_wdata (wb_wdata),
		.wb_rdata (wb_rdata[0]),
		.wb_we    (wb_we),
		.wb_cyc   (wb_cyc[0]),
		.wb_ack   (wb_ack[0]),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);

	// IOBs
    SB_IO #(
        .PIN_TYPE    (6'b1101_01),
        .PULLUP      (1'b1),
        .IO_STANDARD ("SB_LVCMOS")
    ) i2c_scl_iob (
        .PACKAGE_PIN   (i2c_scl),
        .OUTPUT_CLK    (clk_1x),
        .OUTPUT_ENABLE (i2c_scl_oe),
        .D_OUT_0       (1'b0)
    );

    SB_IO #(
        .PIN_TYPE    (6'b1101_00),
        .PULLUP      (1'b1),
        .IO_STANDARD ("SB_LVCMOS")
    ) i2c_sda_iob (
        .PACKAGE_PIN   (i2c_sda),
        .INPUT_CLK     (clk_1x),
        .OUTPUT_CLK    (clk_1x),
        .OUTPUT_ENABLE (i2c_sda_oe),
        .D_OUT_0       (1'b0),
        .D_IN_0        (i2c_sda_i)
    );


	// Game Pads [1]
	// ---------

	gamepad_cont_wb #(
//	gamepad_od_wb #(
		.DIV        (200),
		.SEL_WIDTH  (1),
		.DATA_WIDTH (2),
		.REG_WIDTH  (16)
	) gamepad_I (
		.gp_sel  (gp_sel),
		.gp_data (gp_data),
		.gp_latch(gp_latch),
		.gp_clk  (gp_clk),
		.wb_addr (wb_addr[3:0]),
		.wb_wdata(wb_wdata),
		.wb_rdata(wb_rdata[1]),
		.wb_we   (wb_we),
		.wb_cyc  (wb_cyc[1]),
		.wb_ack  (wb_ack[1]),
		.clk     (clk_1x),
		.rst     (rst_sys)
	);


	// Audio
	// -----

	reg  [23:0] fr_addr;
	wire [15:0] fr_len;
	wire        fr_go;
	wire        fr_rdy;

	wire [9:0] af_level;
	wire       af_aempty;

	wire [7:0] af_wdata;
	wire       af_wena;
	wire       af_full;

	wire [7:0] af_rdata;
	wire       af_rena;
	wire       af_empty;

	// Flash read
	spi_flash_reader fr_I (
		.spi_mosi (spi_io[0]),
		.spi_miso (spi_io[1]),
		.spi_cs_n (spi_cs_n[0]),
		.spi_clk  (spi_sck),
		.addr     (fr_addr),
		.len      (fr_len),
		.go       (fr_go),
		.rdy      (fr_rdy),
		.data     (af_wdata),
		.valid    (af_wena),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);

	always @(posedge clk_1x)
		if (rst_sys)
			fr_addr <= 24'h800000;
		else if (fr_go)
			fr_addr <= {1'b1, fr_addr[22:0] + 23'd128 };

	assign fr_len = 16'd127;
	assign fr_go  = fr_rdy & af_aempty & aux_csr[0];

	// FIFO
	fifo_sync_ram #(
		.WIDTH(8),
		.DEPTH(512)
	) audio_fifo_I (
		.wr_data  (af_wdata),
		.wr_ena   (af_wena),
		.wr_full  (af_full),
		.rd_data  (af_rdata),
		.rd_ena   (af_rena),
		.rd_empty (af_empty),
		.clk      (clk_1x),
		.rst      (rst_sys)
	);

	always @(posedge clk_1x)
		if (rst_sys)
			af_level <= 0;
		else if (af_wena & ~af_rena)
			af_level <= af_level + 1;
		else if (af_rena & ~af_wena)
			af_level <= af_level - 1;

	assign af_aempty = (af_level[9:8] == 2'b00);

	// Audio source:
	//  - FIFO or
	//  - Triangle wave generator (750 Hz at 48 ksps)
	always @(posedge clk_1x)
		if (audio_ack)
			if (aux_csr[0])
				audio_val <= af_empty ? 16'h0000 : { af_rdata, af_rdata };
			else
				audio_val <= audio_val + 16'd1024;

	assign af_rena = ~af_empty & aux_csr[0] & audio_ack;

	// Encoder
	spdif_tx #(
		// Approximate 3.072M bitrate 25.125 MHz
		// (we get 3.045M which is 0.86% off)
		.ACC_STEP (33),
		.ACC_FRAC ( 3)
	) spdif_I (
		.spdif      (spdif),
		.spdif_tick (),
		.audio_l    ({2'b00, audio_val, 6'b000000}),
		.audio_r    ({2'b00, audio_val, 6'b000000}),
		.ack        (audio_ack),
		.valid      (1'b1),
		.clk        (clk_1x),
		.rst        (rst_sys)
	);


	// USB <-> Wishbone bridge
	// -----------------------

	muacm2wb #(
		.WB_N(WB_N)
	) wb_I (
		.usb_dp     (usb_dp),
		.usb_dn     (usb_dn),
		.usb_pu     (usb_pu),
		.usb_clk    (clk_usb),
		.usb_rst    (rst_usb),
		.wb_wdata   (wb_wdata),
		.wb_rdata   (wb_rdata_flat),
		.wb_addr    (wb_addr),
		.wb_we      (wb_we),
		.wb_cyc     (wb_cyc),
		.wb_ack     (wb_ack),
		.aux_csr    (aux_csr),
		.bootloader (bootloader_req),
		.clk        (clk_1x),
		.rst        (rst_sys)
	);

	genvar i;
	for (i=0; i<WB_N; i=i+1)
		assign wb_rdata_flat[i*32+:32] = wb_rdata[i];


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
	assign rgb_pwm[0] = spdif;
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
