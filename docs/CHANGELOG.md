# AEGIS-RV Changelog

All notable changes to the AEGIS-RV project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-05-04

### Added
- Project directory structure (rtl/, tb/, sby/, syn/, openroad/, scripts/, docs/, firmware/)
- Makefile with all build targets (lint, sim, formal, synth, pnr, cert, firmware)
- Project configuration (.gitignore, .verilator_lint.vlt, .sby_global_config, rtl_list.f)

#### RTL — Core Pipeline
- `aegis_rt_core` — 4-stage IF→ID→EX→WB pipeline with Xdrone dispatch
- `rt_register_file` — 32×32-bit register file with hardware shadow banks
- `rt_alu` — Integer ALU + FPU stubs (1-cycle deterministic)
- `rt_branch_unit` — Deterministic branch comparator
- `rt_csr_unit` — Machine-mode-only CSR access with privilege gating
- `rt_interrupt_controller` — 12-cycle guaranteed entry latency
- `tcls_voter` — 2oo3 majority voting + quarantine FSM (≤5 cycles)
- `tcls_mismatch_counter` — Configurable threshold counter
- `xdrone_decoder` / `xdrone_dispatcher` — Custom opcode decode + fixed-latency dispatch

#### RTL — Memory
- `scratchpad_ctrl` — 512 KB dual-bank TCM controller (1-cycle latency)
- `scratchpad_bank` — 256 KB bank with inline ECC decoder
- `ecc_secdec_32` — SECDED(39,32) Hamming encoder/decoder
- `ecc_scrubber` — Background scrubber for latent fault detection
- `memory_mux` — Address routing per memory map

#### RTL — Security
- `smu` — Fault aggregation FSM with ISO 26262 fault codes
- `pmp_lite` — 16-region PMP (deny-by-default)
- `constant_time_wrapper` — Fixed 64-cycle timing isolation
- `secure_boot_stub` / `crypto_accel_if` — Phase 1 stubs

#### RTL — Power
- `power_orchestrator` — RUN/SLEEP/SAFE_STATE FSM (irreversible safe-state)
- `isolation_cell_1bit` / `retention_reg_32` / `wake_sequencer` / `power_domain_if`

#### RTL — Interconnect
- `axi_lite_rt_slice` — RT-dedicated AXI slice with TT arbitration
- `tt_arbiter_4master` — Fixed-priority arbiter
- `iopmp_ctrl` / `axi_timeout_monitor`

#### RTL — Top-Level
- `aegis_top` / `aegis_rt_top` — Domain integration

#### Testbenches
- Unit testbenches for: SMU, power_orchestrator, ECC SECDED, TCLS voter,
  interrupt controller, Xdrone decoder, scratchpad controller,
  constant-time wrapper, PMP, retention register
- Integration: smoke test, fault injection testbench
- Common: `tb_common.vh` logging/assertion macros

#### Formal Verification
- SBY configs: TCLS properties, interrupt determinism, Xdrone fixed latency,
  ECC correction, scratchpad 1-cycle, SMU fault aggregation, safe-state transition
- Common: `sby_common.svh` assertion macros

#### Scripts
- `cert_traceability.py` — ISO 26262 / DO-254 traceability generator
- `wcet_analyzer.py` — WCET timing constraint generator
- `lint_summary.py` — Verilator lint aggregation
- `gen_csr_map.py` — CSR decoder + C header generator
- `setup_toolchain.sh` / `setup_pdk.sh` / `wave_preload.py`

#### Synthesis & PnR
- Yosys: synth_common.tcl, 130nm_constraints.tcl, synth_rt_core.tcl,
  synth_scratchpad.tcl, synth_ecc_secdec.tcl
- OpenROAD: flow.tcl, floorplan.tcl, power_grid.tcl, signoff.tcl, rt_domain.sdc

#### Firmware
- link.ld, boot.S, rt_test.c, Makefile

#### Documentation
- README.md, ARCHITECTURE.md, RTL_STYLE_GUIDE.md, VERIFICATION_PLAN.md,
  CSR_SPEC.md, MEMORY_MAP.md, BUILD_LOG.md, CHANGELOG.md

## [0.2.0] - 2026-05-04

### Added — Phase 2: Pipeline Deepening + Xdrone Integration

#### RTL — Core Pipeline v2.0
- `rt_decoder` — Full RV32IMACF instruction decoder with illegal instruction trap
- `rt_fpu` — Single-precision FPU with flush-to-zero (FTZ) mode (1-cycle deterministic)
- `rv32c_expander` — 16-bit→32-bit compressed instruction expansion
- `rt_muldiv` — M extension multiply/divide (MUL=2c, DIV=4c fixed latency)
- `rt_atomic` — A extension LR.W/SC.W with reservation set tracking
- `rt_watchdog` — Configurable timeout watchdog with latching (SMU fault 0x08)
- `rt_pipeline_controller` — Hazard detection (RAW) + forwarding control
- `rt_dft_scan` — DFT scan chain wrapper (4×256-bit, fuse-gated in production)
- `xdrone_qmul` — Quaternion multiply (2-cycle fixed, Q8.8 fixed-point, saturating)
- `xdrone_kalman` — Kalman filter predict step (4-cycle fixed, 6×16-bit state)
- `aegis_rt_core` v2.0 — Full pipeline with 7 states + forwarding + stall logic
- `aegis_rt_top` — CSR wiring to subsystems + PMP integration
- `aegis_top` — DFT scan interface + Phase 2 domain description

#### Testbenches
- `rt_decoder_tb` — 28 tests (full ISA decode coverage)
- `rt_fpu_tb` — 10 tests (FADD/FSUB/FMUL/NaN/FTZ/FMIN/FSGNJ/FMV/latency)
- `rt_muldiv_tb` — 9 tests (MUL/MULH/DIV/DIV0/REM/DIVU/latency)
- `rt_watchdog_tb` — 6 tests (disable/countdown/kick/timeout/latch)
- `xdrone_qmul_tb` — 3 tests (identity/latency/busy)
- `xdrone_kalman_tb` — 4 tests (zero/latency/busy/non-zero)
- `tb_memory_model` — Behavioral SRAM with fault injection

#### Formal Verification
- `branch_latency.sby` — 1-cycle branch determinism
- `muldiv_fixed_latency.sby` — MUL=2c, DIV=4c, no early valid
- `atomic_reservation.sby` — LR sets reservation, SC fails without, ext write clears
- `fpu_ftz_determinism.sby` — Subnormal→zero with FTZ, 1-cycle latency
- `irq_12cycle.sby` — 12-cycle interrupt entry
- `pipeline_hazard_safety.sby` — RAW hazard detection, load-use stall
- `tt_arbiter_latency.sby` — RT master ≤29 cycles, no starvation

#### Firmware
- `irq_handler.S` — Full interrupt handler with 11-vector table + MRET

#### Synthesis
- `synth_rt_core_phase2.tcl` — Phase 2 synthesis with WCET constraints

#### Scripts
- `wcet_analyzer.py` — Updated with Phase 2 WCET contracts (8 new paths)

#### Documentation
- `CERTIFICATION.md` — Phase 2 ISO 26262/DO-254 traceability (8 new mechanisms)
- `VERIFICATION_PLAN.md` — Phase 2 module matrix + formal property table
- `BUILD_LOG.md` — Phase 2 build entries

#### Build System
- Makefile: `sim_phase2`, `formal_phase2`, `lint_phase2` targets
- `rtl_list.f` — Updated with all Phase 2 modules
- `LICENSE` — Apache 2.0 (core) + Proprietary (Xdrone)

### Changed
- `rt_alu` — FPU stubs marked as delegated to `rt_fpu`
- `xdrone_dispatcher` — Wired qmul/kalman sub-modules with valid/done handshaking
- `aegis_rt_core` — Full pipeline integration with decoder, FPU, MULDIV, atomic,
  watchdog, pipeline controller, forwarding, stall, context switch, IRQ entry
