IVERILOG ?= iverilog
VVP ?= vvp
PYTHON ?= python3
ECE552 ?= ece552
BUILD_DIR ?= build

# The implementation is ./hart.v; rtl/hart.v is the original empty starter.
RTL := hart.v PC_reg.v rf.v decoder.v imm.v alu.v \
       $(wildcard pipeline_registers/*.v) $(wildcard stages/*.v)

.PHONY: test compile test-registers test-pipeline check

test: compile test-registers test-pipeline

compile: $(BUILD_DIR)/hart

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/hart: $(RTL) | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s hart -o $@ $(RTL)

$(BUILD_DIR)/dx_register_tb: pipeline_registers/dx_register.v tb/dx_register_tb.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s dx_register_tb -o $@ $^

$(BUILD_DIR)/xm_mw_register_tb: pipeline_registers/xm_register.v pipeline_registers/mw_register.v tb/xm_mw_register_tb.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s xm_mw_register_tb -o $@ $^

test-registers: $(BUILD_DIR)/dx_register_tb $(BUILD_DIR)/xm_mw_register_tb
	$(VVP) $(BUILD_DIR)/dx_register_tb
	$(VVP) $(BUILD_DIR)/xm_mw_register_tb

test-pipeline:
	$(PYTHON) tb/run_pipeline_tests.py

check:
	$(ECE552) validate -w $(RTL)
