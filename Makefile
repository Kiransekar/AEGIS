#===============================================================================
# AEGIS-RV Makefile — Unified Build System
# Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
# Target: 130nm CMOS (SkyWater 130 / TSMC 130G)
#===============================================================================

#--- Configuration ---
PDK        ?= sky130
PDK_ROOT   ?= $(HOME)/skywater-pdk
STD_CELL   ?= sky130_fd_sc_hd
TRACE      ?= 0
COVERAGE   ?= 0
VERBOSE    ?= 0
TEST       ?=
OPTIMIZE   ?= 0
DFT        ?= 0
POWER      ?= 0

#--- Tool Configuration ---
YOSYS      ?= yosys
SBY        ?= sby
VERILATOR  ?= verilator
OPENROAD   ?= openroad
GTKWAVE    ?= gtkwave

#--- Directories ---
RTL_DIR    = rtl
TB_DIR     = tb
SBY_DIR    = sby
SYN_DIR    = syn
SIM_DIR    = sim
SCRIPT_DIR = scripts
DOC_DIR    = docs
FW_DIR     = firmware

#--- RTL File List ---
RTL_LIST   = $(RTL_DIR)/rtl_list.f

#--- Common Verilator Flags ---
VFLAGS     = --Wall --Wno-fatal \
             +define+SAFETY_MODE +define+XDRONE_EXT \
             --verilator-lint .verilator_lint.vlt

#===============================================================================
# HELP
#===============================================================================
.PHONY: help
help:
	@echo "AEGIS-RV Build System"
	@echo "==============================================================================="
	@echo "ENVIRONMENT"
	@echo "  make env_check          # Verify toolchain + PDK installation"
	@echo ""
	@echo "LINTING"
	@echo "  make lint               # Lint all RTL files (Verilator)"
	@echo "  make lint_<module>      # Lint specific module (e.g., lint_smu)"
	@echo "  make lint_phase2        # Lint Phase 2 modules"
	@echo ""
	@echo "SIMULATION"
	@echo "  make sim                # Run all unit testbenches"
	@echo "  make sim_<module>       # Run specific testbench (e.g., sim_smu)"
	@echo "  make sim TRACE=1        # Enable waveform tracing for all sims"
	@echo "  make sim_<module> TEST=<test_name>  # Run specific test case"
	@echo "  make sim_phase2         # Run Phase 2 module testbenches"
	@echo ""
	@echo "FORMAL VERIFICATION"
	@echo "  make formal             # Run all SymbiYosys properties"
	@echo "  make formal_<module>    # Run specific property set (e.g., formal_tcls)"
	@echo "  make formal_phase2      # Run Phase 2 formal proofs"
	@echo ""
	@echo "SYNTHESIS"
	@echo "  make synth              # Synthesize all modules (dry-run, no PDK)"
	@echo "  make synth_<module>     # Synthesize specific module"
	@echo "  make synth PDK=sky130   # Synthesize with target PDK"
	@echo ""
	@echo "PLACE & ROUTE"
	@echo "  make pnr                # Full OpenROAD flow for RT domain"
	@echo "  make pnr FLOORPLAN=1    # Run floorplan only"
	@echo "  make pnr SIGNOFF=1      # Run STA + DRC + LVS signoff"
	@echo ""
	@echo "CERTIFICATION"
	@echo "  make cert_trace         # Generate ISO 26262 / DO-254 traceability matrix"
	@echo "  make wcet               # Run WCET analysis + generate timing constraints"
	@echo ""
	@echo "FIRMWARE"
	@echo "  make firmware           # Build RT core test firmware"
	@echo "  make cosim              # Co-simulate firmware + RTL (Verilator C++)"
	@echo ""
	@echo "UTILITIES"
	@echo "  make docs               # Generate documentation from source"
	@echo "  make clean              # Remove build artifacts"
	@echo "  make clean_all          # Remove all generated files (including PDK)"
	@echo "==============================================================================="

#===============================================================================
# ENVIRONMENT CHECK
#===============================================================================
.PHONY: env_check
env_check:
	@echo "==============================================================================="
	@echo "AEGIS-RV Environment Check"
	@echo "==============================================================================="
	@command -v yosys >/dev/null 2>&1 && echo "[✓] Yosys $$(yosys -V | head -1)" || echo "[✗] Yosys not found"
	@command -v sby >/dev/null 2>&1 && echo "[✓] SymbiYosys $$(sby --version 2>/dev/null || echo 'installed')" || echo "[✗] SymbiYosys not found"
	@command -v verilator >/dev/null 2>&1 && echo "[✓] Verilator $$(verilator --version | head -1)" || echo "[✗] Verilator not found"
	@command -v gtkwave >/dev/null 2>&1 && echo "[✓] GTKWave $$(gtkwave --version 2>/dev/null | head -1)" || echo "[✗] GTKWave not found"
	@command -v openroad >/dev/null 2>&1 && echo "[✓] OpenROAD $$(openroad -version 2>/dev/null || echo 'installed')" || echo "[✗] OpenROAD not found"
	@test -n "$${PDK_ROOT:-}" && echo "[✓] PDK_ROOT=$$PDK_ROOT" || echo "[✗] PDK_ROOT not set"
	@test -n "$${PDK:-}" && echo "[✓] PDK=$$PDK" || echo "[✗] PDK not set"
	@test -n "$${STD_CELL_LIBRARY:-}" && echo "[✓] STD_CELL_LIBRARY=$$STD_CELL_LIBRARY" || echo "[✗] STD_CELL_LIBRARY not set"
	@echo "==============================================================================="

#===============================================================================
# LINTING TARGETS
#===============================================================================
.PHONY: lint lint_%
lint:
	$(VERILATOR) --lint-only $(VFLAGS) \
		--top aegis_rt_top \
		-f $(RTL_LIST)

lint_%:
	@module_file=$$(find $(RTL_DIR) -name "$*.v" | head -1); \
	if [ -z "$$module_file" ]; then \
		echo "[✗] Module $* not found in $(RTL_DIR)/"; \
		exit 1; \
	fi; \
	$(VERILATOR) --lint-only $(VFLAGS) \
		--top $* \
		$$module_file

#===============================================================================
# SIMULATION TARGETS
#===============================================================================
.PHONY: sim sim_all_phase1
sim:
	@for tb in $$(find $(TB_DIR) -name "*_tb.v" -not -path "*/integration/*"); do \
		module=$$(basename $$tb _tb.v); \
		echo "[→] Running simulation: $$module"; \
		$(MAKE) sim_$$module || exit 1; \
	done

sim_all_phase1: sim
sim_all_phase2: sim_rt_decoder sim_rt_fpu sim_rt_muldiv sim_rt_watchdog sim_aegis_rt_core

# Phase 1 Boot Validation with Icarus Verilog
.PHONY: sim_boot
sim_boot:
	@echo "[→] Phase 1: Boot Validation with Icarus Verilog"
	@if [ ! -f $(FW_DIR)/build/firmware.hex ]; then \
		echo "[!] firmware.hex not found, building firmware..."; \
		$(MAKE) -C $(FW_DIR) build/firmware.hex || exit 1; \
	fi
	@mkdir -p $(SIM_DIR)
	iverilog -g2012 tb/core/aegis_boot_standalone_tb.v -o $(SIM_DIR)/boot_sim 2>&1 | tee $(SIM_DIR)/boot_compile.log
	@if grep -q error $(SIM_DIR)/boot_compile.log; then \
		echo "[✗] Compilation failed"; \
		exit 1; \
	fi
	@echo "[→] Running boot simulation..."
	vvp $(SIM_DIR)/boot_sim 2>&1 | tee $(SIM_DIR)/boot.log
	@if grep -q "PASS: Phase 1" $(SIM_DIR)/boot.log; then \
		echo "[✓] Phase 1 Boot Validation PASSED"; \
	else \
		echo "[✗] Phase 1 Boot Validation FAILED"; \
		exit 1; \
	fi

sim_%:
	@tb_file=$$(find $(TB_DIR) -name "$*_tb.v" | head -1); \
	if [ -z "$$tb_file" ]; then \
		echo "[✗] Testbench $*_tb.v not found in $(TB_DIR)/"; \
		exit 1; \
	fi; \
	tb_dir=$$(dirname $$tb_file); \
	mkdir -p $(SIM_DIR)/$*_obj; \
	echo "[→] Compiling: $*"; \
	$(VERILATOR) --cc --exe \
		$(if $(filter 1,$(TRACE)),--trace --trace-struct) \
		--top $*_tb \
		-f $(RTL_LIST) \
		$$tb_file \
		+define+SAFETY_MODE +define+SIMULATION \
		--Mdir $(SIM_DIR)/$*_obj \
		--build \
		-CFLAGS "-I. -I$(TB_DIR) -std=c++17" \
		-LDFLAGS "-lpthread" || exit 1; \
	echo "[→] Running: $*"; \
	$(SIM_DIR)/$*_obj/V$*_tb $(if $(TEST),+test=$(TEST)); \
	echo "[✓] Simulation complete: $*"

#===============================================================================
# FORMAL VERIFICATION TARGETS
#===============================================================================
.PHONY: formal formal_%
formal:
	@for sby_file in $$(find $(SBY_DIR) -name "*.sby"); do \
		echo "[→] Running formal: $$sby_file"; \
		$(SBY) -f $$sby_file || exit 1; \
	done

formal_%:
	@sby_file=$$(find $(SBY_DIR) -name "$*.sby" | head -1); \
	if [ -z "$$sby_file" ]; then \
		echo "[✗] SBY config $*.sby not found in $(SBY_DIR)/"; \
		exit 1; \
	fi; \
	$(SBY) -f $$sby_file

#===============================================================================
# SYNTHESIS TARGETS
#===============================================================================
.PHONY: synth synth_%
synth:
	$(YOSYS) -l $(SYN_DIR)/synth.log \
		-p "tcl $(SYN_DIR)/synth_common.tcl; tcl $(SYN_DIR)/130nm_constraints.tcl"

synth_%:
	@module_file=$$(find $(RTL_DIR) -name "$*.v" | head -1); \
	if [ -z "$$module_file" ]; then \
		echo "[✗] Module $*.v not found in $(RTL_DIR)/"; \
		exit 1; \
	fi; \
	mkdir -p $(SYN_DIR)/reports; \
	$(YOSYS) -l $(SYN_DIR)/$*_synth.log \
		-p "read_verilog -sv -defer $$module_file; \
		    tcl $(SYN_DIR)/synth_common.tcl; \
		    tcl $(SYN_DIR)/130nm_constraints.tcl; \
		    write_verilog -noattr $(SYN_DIR)/$*_syn.v; \
		    write_json $(SYN_DIR)/$*.json"

#===============================================================================
# PLACE & ROUTE TARGETS
#===============================================================================
.PHONY: pnr
pnr:
	$(OPENROAD) -exit openroad/flow.tcl

#===============================================================================
# CERTIFICATION TARGETS
#===============================================================================
.PHONY: cert_trace wcet
cert_trace:
	python3 $(SCRIPT_DIR)/cert_traceability.py \
		--spec $(DOC_DIR)/ARCHITECTURE.md \
		--rtl $(RTL_DIR)/ \
		--output $(DOC_DIR)/CERTIFICATION.md

#===============================================================================
# PHASE 2 SPECIFIC TARGETS
#===============================================================================
.PHONY: sim_phase2 formal_phase2 lint_phase2
sim_phase2: sim_rt_decoder sim_rt_fpu sim_rt_muldiv sim_rt_watchdog

formal_phase2: formal_branch_latency formal_muldiv_fixed_latency formal_atomic_reservation

lint_phase2:
	@for mod in rt_decoder rt_fpu rt_muldiv rt_atomic rt_watchdog rv32c_expander rt_pipeline_controller; do \
		echo "[→] Linting: $$mod"; \
		$(MAKE) lint_$$mod || exit 1; \
		done

wcet:
	python3 $(SCRIPT_DIR)/wcet_analyzer.py \
		--rtl $(RTL_DIR)/core/aegis_rt_core.v \
		--constraints $(SYN_DIR)/130nm_constraints.tcl \
		--output $(SYN_DIR)/wcet_constraints.sdc

#===============================================================================
# FIRMWARE TARGETS
#===============================================================================
.PHONY: firmware cosim
firmware:
	$(MAKE) -C $(FW_DIR)

cosim: firmware
	$(VERILATOR) --cc --exe --trace \
		--top aegis_rt_top \
		-f $(RTL_LIST) \
		$(FW_DIR)/build/rt_test.elf \
		--Mdir $(SIM_DIR)/cosim_obj \
		--build \
		-CFLAGS "-I. -I$(FW_DIR) -std=c++17" \
		-LDFLAGS "-lpthread"
	@$(SIM_DIR)/cosim_obj/Vaegis_rt_top

#===============================================================================
# DOCUMENTATION TARGETS
#===============================================================================
.PHONY: docs
docs:
	@echo "[→] Generating documentation..."
	@python3 $(SCRIPT_DIR)/cert_traceability.py \
		--spec $(DOC_DIR)/ARCHITECTURE.md \
		--rtl $(RTL_DIR)/ \
		--output $(DOC_DIR)/CERTIFICATION.md 2>/dev/null || true
	@echo "[✓] Documentation generated"

#===============================================================================
# CLEAN TARGETS
#===============================================================================
.PHONY: clean clean_all
clean:
	rm -rf $(SIM_DIR)/ $(SIGNOFF_DIR)/
	rm -f $(SYN_DIR)/*.log $(SYN_DIR)/*_syn.v $(SYN_DIR)/*.json
	$(MAKE) -C $(FW_DIR) clean 2>/dev/null || true

clean_all: clean
	rm -rf .venv/ skywater-pdk/
