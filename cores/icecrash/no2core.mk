CORE := icecrash

RTL_SRCS_icecrash := $(addprefix rtl/, \
	dfu_helper.v \
	gamepad_cont.v \
	gamepad_cont_wb.v \
	gamepad_od.v \
	gamepad_od_wb.v \
	hdmi_phy_ddr_1x.v \
	spdif_tx.v \
	spdif_word_code.v \
	vid_tgen.v \
)

TESTBENCHES_icecrash := \
	gamepad_cont_tb \
	gamepad_od_tb \
	spdif_tx_tb \
	$(NULL)

include $(NO2BUILD_DIR)/core-magic.mk
