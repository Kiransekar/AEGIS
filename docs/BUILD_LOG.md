# AEGIS-RV Build Log

## Phase 1: Foundation (Week 1-2)

### 2026-05-04 — Initial Project Setup

**Created**: 69 files across full project structure

#### RTL Modules (30 files)
| Module | Category | Lines | Status |
|--------|----------|-------|--------|
| aegis_rt_core | Core | ~200 | Phase 1 skeleton |
| rt_register_file | Core | ~80 | Shadow banks implemented |
| rt_alu | Core | ~80 | Integer ops + FPU stubs |
| rt_branch_unit | Core | ~60 | Deterministic timing |
| rt_csr_unit | Core | ~120 | Machine-mode-only CSR |
| rt_interrupt_controller | Core | ~100 | 12-cycle entry FSM |
| tcls_voter | Core | ~100 | 2oo3 voting + quarantine |
| tcls_mismatch_counter | Core | ~40 | Configurable threshold |
| xdrone_decoder | Core | ~50 | Custom opcode decode |
| xdrone_dispatcher | Core | ~80 | Fixed-latency dispatch |
| scratchpad_ctrl | Memory | ~130 | Dual-bank + ECC + scrubber |
| scratchpad_bank | Memory | ~60 | RAM inference + inline ECC |
| ecc_secdec_32 | Memory | ~200 | SECDED(39,32) full impl |
| ecc_scrubber | Memory | ~80 | Background scrub FSM |
| memory_mux | Memory | ~70 | Address routing |
| smu | Security | ~130 | Fault aggregation FSM |
| pmp_lite | Security | ~80 | 16-region deny-by-default |
| constant_time_wrapper | Security | ~60 | Fixed 64-cycle isolation |
| secure_boot_stub | Security | ~30 | Phase 1 stub |
| crypto_accel_if | Security | ~20 | Phase 1 stub |
| power_orchestrator | Power | ~100 | RUN/SLEEP/SAFE_STATE FSM |
| isolation_cell_1bit | Power | ~20 | Default-clamp isolation |
| retention_reg_32 | Power | ~50 | Save/restore + mismatch detect |
| wake_sequencer | Power | ~40 | Stabilization timer |
| power_domain_if | Power | ~20 | Signal aggregation |
| axi_lite_rt_slice | Interconnect | ~60 | RT-dedicated AXI slice |
| tt_arbiter_4master | Interconnect | ~40 | Fixed priority arbiter |
| iopmp_ctrl | Interconnect | ~20 | Phase 1 stub |
| axi_timeout_monitor | Interconnect | ~40 | Deadlock prevention |
| aegis_top / aegis_rt_top | Top | ~120 | Domain integration |

#### Testbenches (9 files)
- smu_tb, power_orchestrator_tb, ecc_secdec_32_tb
- tcls_voter_tb, rt_interrupt_controller_tb, xdrone_decoder_tb
- scratchpad_ctrl_tb, constant_time_wrapper_tb, pmp_lite_tb
- retention_reg_tb, aegis_rt_smoke_tb, aegis_rt_fault_injection_tb
- tb_common.vh

#### Formal Verification (8 files)
- 7 SBY configs + sby_common.svh

#### Build Infrastructure
- Makefile, .gitignore, .verilator_lint.vlt, .sby_global_config, rtl_list.f
- 4 Python scripts, 5 synthesis TCL, 4 OpenROAD TCL
- Firmware: link.ld, boot.S, rt_test.c, Makefile

### 2026-05-04 — Verification Infrastructure Added

**Created**: 12 additional testbenches + setup scripts + synthesis scripts

#### New Testbenches
- tcls_voter_tb (7 tests: voting, mismatch, quarantine, hot-spare)
- rt_interrupt_controller_tb (6 tests: latency, priority, disabled, vector)
- xdrone_decoder_tb (5 tests: custom-0/1 decode, field extraction)
- scratchpad_ctrl_tb (6 tests: dual-bank, latency, scrubber)
- constant_time_wrapper_tb (4 tests: fixed 64-cycle, constant timing)
- pmp_lite_tb (5 tests: deny-by-default, RW/RO/NONE, unmapped)
- retention_reg_tb (4 tests: save/restore, mismatch detect)
- aegis_rt_smoke_tb (5 tests: reset, TCLS, power, PC, no spurious)
- aegis_rt_fault_injection_tb (7 tests: TCLS, ECC, watchdog, LF accumulation)

#### New Infrastructure
- setup_toolchain.sh, setup_pdk.sh, wave_preload.py
- synth_rt_core.tcl, synth_scratchpad.tcl, synth_ecc_secdec.tcl
- floorplan.tcl, power_grid.tcl, signoff.tcl

## Phase 2: Pipeline Deepening (Week 5-6)

### 2026-05-04 — Full RV32IMACF Decode + FPU + M/A Extensions

**Created**: 48 new files (117 total)

#### New RTL Modules (8 files)
| Module | Category | Lines | Status |
|--------|----------|-------|--------|
| rt_decoder | Core | ~280 | Full RV32IMACF decode |
| rt_fpu | Core | ~300 | Single-precision FTZ mode |
| rv32c_expander | Core | ~200 | 16-bit→32-bit expansion |
| rt_muldiv | Core | ~160 | M extension (MUL=2c, DIV=4c) |
| rt_atomic | Core | ~100 | A extension LR.W/SC.W |
| rt_watchdog | Core | ~60 | Configurable timeout + latching |
| aegis_rt_core v2.0 | Core | ~680 | Full pipeline integration |

#### Pipeline Integration (aegis_rt_core v2.0)
- IF: rv32c_expander in-line with TCM fetch
- ID: rt_decoder drives all pipeline control signals
- EX: Dispatch to ALU / FPU / MULDIV / Atomic / Branch / CSR / Xdrone
- WB: Register writeback with x0 hardwired protection
- RT_MULDIV: Multi-cycle (MUL=2, DIV=4 fixed latency)
- RT_IRQ_ENTRY: 12-cycle interrupt entry with shadow bank swap
- RT_XDRONE: Multi-cycle Xdrone dispatch
- Watchdog timeout → SMU fault code 0x08
- Context switch: shadow_bank_sel on IRQ entry / ECALL / EBREAK

#### New Testbenches (6 files)
- rt_decoder_tb (28 tests: full ISA decode coverage)
- rt_fpu_tb (10 tests: FADD/FSUB/FMUL/NaN/FTZ/FMIN/FSGNJ/FMV.X.W/divzero/latency)
- rt_muldiv_tb (9 tests: MUL/MULH/DIV/DIV0/REM/DIVU/latency)
- rt_watchdog_tb (6 tests: disable/countdown/kick/timeout/latch/disable)
- aegis_rt_core_tb (7 tests: reset/PC/TCLS/scratchpad/halt/SMU/Xdrone)
- tb_memory_model (behavioral SRAM with fault injection)

#### New Formal Verification (3 files)
- constant_time_invariant.sby (fixed 64-cycle, no early exit)
- retention_data_preservation.sby (shadow capture, mismatch detect)
- branch_latency.sby (1-cycle branch determinism)

#### New Infrastructure (15 files)
- OpenROAD: flow_common.tcl, placement.tcl, cts.tcl, route.tcl
- OpenROAD: constraints/physical_constraints.tcl, constraints/power_intent.upf
- Synthesis: synth_tcls_voter.tcl, 130nm_library_map.tcl
- Scripts: gen_memory_map.py
- Docs: CERTIFICATION.md (ISO 26262 / DO-254 compliance mapping)
- LICENSE (Apache 2.0 core + Proprietary Xdrone)

---

## Phase 2: Pipeline Deepening + Xdrone Integration (2026-05-04)

### Milestone: Lint-Clean RTL (0 Verilator errors)
All 44 RTL files pass Verilator lint with `--Wall --Wno-fatal`.

### New RTL Modules (12)
- Core: rt_decoder (RV32IMACF), rt_fpu (FTZ), rv32c_expander, rt_muldiv (M ext),
  rt_atomic (A ext), rt_watchdog, rt_pipeline_controller (hazard+forwarding),
  rt_dft_scan (4×256-bit scan chains), rt_exception_handler (ECALL/EBREAK/MRET/illegal),
  xdrone_qmul (2-cycle quaternion multiply), xdrone_kalman (4-cycle Kalman predict)
- Updated: aegis_rt_core v2.0 (7-state pipeline + forwarding + stall),
  xdrone_dispatcher (qmul/kalman sub-module wiring), aegis_rt_top (CSR wiring + PMP),
  aegis_top (DFT scan interface)

### Pipeline v2.0
- 7 states: FETCH, DECODE, EXECUTE, WRITEBACK, MULDIV, IRQ_ENTRY, XDRONE
- RAW hazard detection + data forwarding (EX→ID, WB→ID)
- Load-use stall (1 cycle), structural stall (MULDIV/FPU/Xdrone busy)
- Shadow bank swap on IRQ entry and ECALL/EBREAK

### Lint Fixes Applied
- WIDTHTRUNC: 2'd10→2'd2, 2'd01→2'd1, 6'd64→7'd64 across rt_decoder, rt_alu,
  pmp_lite, constant_time_wrapper, aegis_rt_core
- FPU: wire→reg inside always block (fsub_impl)
- IRQ controller: 4'd(expr)→localparam, FSM state names prefixed with IRQ_ST_
- AXI slice: input→output assignment fix (pass-through direction)
- PMP instance: port name mismatch fix in aegis_rt_top

### New Testbenches (6)
- rt_decoder_tb (28 tests), rt_fpu_tb (10 tests), rt_muldiv_tb (9 tests),
- rt_watchdog_tb (6 tests), xdrone_qmul_tb (3 tests), xdrone_kalman_tb (4 tests),
- rt_pipeline_tb (6 tests: no-hazard, EX-RAW, load-use, WB-RAW, MULDIV-busy, x0)

### New Formal Proofs (9)
- branch_latency, muldiv_fixed_latency, atomic_reservation, fpu_ftz_determinism,
- irq_12cycle, pipeline_hazard_safety, watchdog_latching, decoder_illegal,
- exception_trap_safety, context_switch_safety

### New Firmware
- irq_handler.S (11-vector interrupt handler + MRET)

### New Synthesis
- synth_rt_core_phase2.tcl (WCET path constraints for MULDIV/FPU/atomic/branch)

### Documentation Updates
- ARCHITECTURE.md v3.0 (pipeline states, Xdrone extension, 14 timing contracts)
- CERTIFICATION.md (8 new Phase 2 safety mechanisms, 8 new WCET paths)
- VERIFICATION_PLAN.md (Phase 2 module matrix, formal property table)
- CHANGELOG.md v0.2.0 (full Phase 2 change log)

### Build System
- Makefile: sim_phase2, formal_phase2, lint_phase2 targets
- wcet_analyzer.py: 8 new Phase 2 WCET contracts
- rtl_list.f: 44 RTL entries (was 28)
