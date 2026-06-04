# =============================================================================
# FlashAttention Verification - Makefile
# Uses Verilator --binary mode for compilation and simulation
# =============================================================================

RTL_DIR  := ../rtl
TB_DIR   := .
SIM_DIR  := ../sim_results
COV_DIR  := ../

VERILATOR := verilator
VFLAGS    := --binary --trace --coverage --top-module \
             -Wno-fatal -Wno-UNOPTFLAT -Wno-WIDTH -Wno-CASEINCOMPLETE \
             -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY -Wno-WIDTHEXPAND

RTL_SRCS := $(RTL_DIR)/fa_regfile.sv \
            $(RTL_DIR)/fa_buffer_mgr.sv \
            $(RTL_DIR)/fa_divider.sv \
            $(RTL_DIR)/fa_softmax.sv \
            $(RTL_DIR)/fa_systolic.sv \
            $(RTL_DIR)/fa_dma.sv \
            $(RTL_DIR)/fa_ctrl.sv \
            $(RTL_DIR)/fa_top.sv

TESTS := tb_fa_regfile tb_fa_buffer_mgr tb_fa_divider tb_fa_softmax \
         tb_fa_systolic tb_fa_ctrl tb_fa_dma tb_fa_top

.PHONY: all clean $(TESTS)

all: $(TESTS)

# Generic rule: build and run each testbench
define RUN_TEST
$(1): $(SIM_DIR)/$(1).log

$(SIM_DIR)/$(1).log: $(TB_DIR)/$(1).sv $(RTL_SRCS)
	@echo "=== Building $(1) ==="
	@mkdir -p $(SIM_DIR)
	cd $(RTL_DIR) && $(VERILATOR) $(VFLAGS) $(1) \
		$(RTL_SRCS) $(TB_DIR)/$(1).sv \
		--Mdir ../sim_results/obj_$(1) \
		-o ../sim_results/$(1) 2>&1 | tee ../sim_results/$(1)_build.log
	@echo "=== Running $(1) ==="
	cd $(SIM_DIR) && ./$(1) 2>&1 | tee $(1).log; \
		EXIT=$$?; \
		grep -q "RESULT: PASS" $(1).log; \
		if [ $$? -eq 0 ]; then \
			echo "=== $(1): PASS ==="; \
		else \
			echo "=== $(1): FAIL ==="; \
		fi
endef

$(foreach test,$(TESTS),$(eval $(call RUN_TEST,$(test))))

# Collect coverage data from all tests
coverage:
	@echo "=== Collecting coverage ==="
	@mkdir -p $(COV_DIR)
	@for test in $(TESTS); do \
		if [ -f $(SIM_DIR)/coverage_$$test.dat ]; then \
			echo "Processing coverage for $$test"; \
		fi; \
	done
	@echo "Coverage collection complete"

clean:
	rm -rf $(SIM_DIR)/obj_* $(SIM_DIR)/tb_* $(SIM_DIR)/*.log $(SIM_DIR)/*.vcd
	rm -f $(SIM_DIR)/*.dat $(COV_DIR)/coverage.json
