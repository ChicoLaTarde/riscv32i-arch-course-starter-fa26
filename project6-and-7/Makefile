IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
ECE552 ?= ece552
BUILD_DIR ?= build
RISCV_PREFIX ?= riscv64-unknown-elf-

RTL := rtl/hart.v rtl/PC_reg.v rtl/rf.v rtl/decoder.v rtl/imm.v rtl/alu.v \
       rtl/forwarding_unit.v rtl/fetch_stage.v rtl/decode_stage.v \
       rtl/execute_stage.v rtl/memory_stage.v rtl/writeback_stage.v \
       rtl/fd_register.v rtl/dx_register.v rtl/xm_register.v rtl/mw_register.v

.PHONY: compile test test-official assemble check

compile: $(BUILD_DIR)/hart_tb

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/hart_tb: $(RTL) rtl/tb_memory.v tb/tb.v | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s hart_tb -o $@ $^

test:
	$(PYTHON) tb/run_multicycle_tests.py

test-official: $(BUILD_DIR)/hart_tb
	$(PYTHON) tb/run_official_tests.py $(BUILD_DIR)/hart_tb

assemble:
	$(PYTHON) tb/assemble_tests.py "$(RISCV_PREFIX)"

check:
	$(ECE552) validate -w $(RTL)
