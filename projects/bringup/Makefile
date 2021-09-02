# Project config
PROJ := bringup

PROJ_DEPS := no2usb no2misc no2ice40
PROJ_RTL_SRCS := $(addprefix rtl/, \
	dfu_helper.v \
	muacm_xclk.v \
	muacm2wb.v \
	stream2wb.v \
	sysmgr.v \
)
PROJ_RTL_SRCS += ../../cores/no2muacm-bin/muacm.v
PROJ_TOP_SRC := rtl/top.v
PROJ_TOP_MOD := top

# Target config
BOARD ?= icecrash
DEVICE := up5k
PACKAGE := sg48

PIN_DEF := ../_common/data/icecrash.pcf

# Include default rules
include ../../build/project-rules.mk
