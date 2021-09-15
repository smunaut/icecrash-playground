# Project config
PROJ := bringup

PROJ_DEPS := no2ice40 no2misc no2muacm
PROJ_RTL_SRCS := $(addprefix rtl/, \
	dfu_helper.v \
	gamepad_cont.v \
	gamepad_cont_wb.v \
	gamepad_od.v \
	gamepad_od_wb.v \
	hdmi_phy_ddr_1x.v \
	vid_test.v \
	vid_tgen.v \
	spdif_tx.v \
	spdif_word_code.v \
	sysmgr.v \
)
PROJ_TESTBENCHES := \
	gamepad_cont_tb \
	gamepad_od_tb \
	spdif_tx_tb \
	$(NULL)
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icecrash
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/icecrash.pcf

# Include default rules
include ../../build/project-rules.mk
