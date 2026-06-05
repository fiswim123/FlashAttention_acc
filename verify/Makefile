# =============================================================================
# FlashAttention End-to-End Verification Makefile
# =============================================================================

# Directories
RTL_DIR := ../rtl
TB_DIR := .
SIM_DIR := ../sim_results
VERIFY_DIR := .

# RTL sources
RTL_SRCS := $(RTL_DIR)/fa_regfile.sv \
            $(RTL_DIR)/sram_sp_64x16.v \
            $(RTL_DIR)/sram_sp_1024x16.v \
            $(RTL_DIR)/sram_sp_256x16.v \
            $(RTL_DIR)/fa_buffer_mgr.sv \
            $(RTL_DIR)/fa_divider.sv \
            $(RTL_DIR)/fa_softmax.sv \
            $(RTL_DIR)/fa_systolic.sv \
            $(RTL_DIR)/fa_dma.sv \
            $(RTL_DIR)/fa_ctrl.sv \
            $(RTL_DIR)/fa_top.sv

# Test parameters
SEED := 42
S := 256
D := 64
NUM_TESTS := 5

# Verilator flags
VERILATOR := verilator
VFLAGS := --binary --trace --timing -Wno-fatal \
          -Wno-UNOPTFLAT -Wno-WIDTH -Wno-CASEINCOMPLETE \
          -Wno-UNUSED -Wno-UNDRIVEN -Wno-PINCONNECTEMPTY \
          -Wno-WIDTHEXPAND

.PHONY: all golden test clean help

# Default target
all: golden test

# Generate golden model test vectors
golden:
	@echo "=== Generating Golden Model Test Vectors ==="
	python3 $(VERIFY_DIR)/run_e2e_test.py --seed $(SEED) --num-tests $(NUM_TESTS) --S $(S) --d $(D)
	@echo "=== Golden Model Complete ==="

# Run end-to-end test
test: golden
	@echo "=== Running End-to-End Test ==="
	@mkdir -p $(SIM_DIR)
	cd $(RTL_DIR) && $(VERILATOR) $(VFLAGS) \
		$(RTL_SRCS) $(TB_DIR)/tb_e2e_seed$(SEED).sv \
		--top-module tb_e2e_seed$(SEED) \
		--Mdir $(SIM_DIR)/obj_tb_e2e_$(SEED) \
		-o $(SIM_DIR)/tb_e2e_$(SEED)
	cd $(SIM_DIR) && ./tb_e2e_$(SEED)
	@echo "=== End-to-End Test Complete ==="

# Run comparison (after RTL simulation)
compare:
	@echo "=== Comparing RTL Output with Golden Model ==="
	python3 $(VERIFY_DIR)/compare_results.py --seed $(SEED)
	@echo "=== Comparison Complete ==="

# Run all tests with multiple seeds
test_all:
	@echo "=== Running All End-to-End Tests ==="
	for seed in 42 43 44 45 46; do \
		echo "--- Testing seed=$$seed ---"; \
		$(MAKE) SEED=$$seed test; \
	done
	@echo "=== All Tests Complete ==="

# Generate test report
report:
	@echo "=== Generating Test Report ==="
	python3 $(VERIFY_DIR)/generate_report.py
	@echo "=== Report Generated ==="

# Clean
clean:
	rm -rf $(SIM_DIR)/obj_tb_e2e_* $(SIM_DIR)/tb_e2e_*
	rm -f $(VERIFY_DIR)/test_vectors_*.txt
	rm -f $(VERIFY_DIR)/mem_*.hex
	rm -f $(VERIFY_DIR)/tb_e2e_*.sv
	rm -f $(VERIFY_DIR)/*.vcd

# Help
help:
	@echo "FlashAttention End-to-End Verification"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Generate golden model and run tests (default)"
	@echo "  golden    - Generate golden model test vectors"
	@echo "  test      - Run end-to-end test with RTL simulation"
	@echo "  compare   - Compare RTL output with golden model"
	@echo "  test_all  - Run tests with multiple seeds"
	@echo "  report    - Generate test report"
	@echo "  clean     - Clean generated files"
	@echo "  help      - Show this help"
	@echo ""
	@echo "Parameters:"
	@echo "  SEED=$(SEED)    - Random seed"
	@echo "  S=$(S)        - Sequence length"
	@echo "  D=$(D)          - Head dimension"
	@echo "  NUM_TESTS=$(NUM_TESTS) - Number of test cases"
	@echo ""
	@echo "Examples:"
	@echo "  make                    # Run default test"
	@echo "  make SEED=123           # Run with specific seed"
	@echo "  make test_all           # Run all tests"
	@echo "  make SEED=42 compare    # Compare results"
