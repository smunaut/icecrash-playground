# Project config
PROJ := bringup

PROJ_DEPS := icecrash no2ice40 no2misc no2muacm
PROJ_RTL_SRCS := $(addprefix rtl/, \
	vid_test.v \
	spi_flash_reader.v \
	sysmgr.v \
)
PROJ_TESTBENCHES := \
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
