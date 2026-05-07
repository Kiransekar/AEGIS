<p align="center">
  <img src="https://img.shields.io/badge/ISA-RV32IMACF-blue" alt="ISA" />
  <img src="https://img.shields.io/badge/Process-130nm_CMOS-green" alt="Process" />
  <img src="https://img.shields.io/badge/Clock-240_MHz-orange" alt="Clock" />
  <img src="https://img.shields.io/badge/Safety-ASIL--D_/_DAL--A-red" alt="Safety" />
  <img src="https://img.shields.io/badge/Tests-24%2F24_passing-brightgreen" alt="Tests" />
</p>

# AEGIS — Safety-Certifiable RISC-V Processor IP

## Overview

**AEGIS** (Adaptive Engine for Guarded Integrated Systems) is a safety-certifiable RISC-V processor IP designed for hard real-time control in safety-critical domains:

- **Flight Control** — DO-254 DAL-A (airborne systems)
- **Motor Control** — ISO 26262 ASIL-D (automotive)
- **Target Process** — 130nm CMOS (SkyWater 130 / TSMC 130G / UMC 130nm)

The processor implements a three-domain SoC architecture with a unified safety interconnect, prioritizing deterministic timing, fault detection, and certification traceability.

---

## Architecture

Three-domain SoC with unified safety interconnect:

| Domain | ISA | Pipeline | Clock | Safety Mechanism |
|--------|-----|----------|-------|------------------|
| **RT Control** | RV32IMACF + Xdrone | 4-stage in-order | 240 MHz | TCLS 2oo3 voting |
| **Application** | RV64GCV | 7-stage OoO | 1.2 GHz | L1/L2 Cache ECC |
| **Security** | RV32E | 2-stage | 80 MHz | PMP + Root of Trust |

### RT Core — Primary Build Target

The RT Control domain is the current focus of development and verification:

- **Interrupt Latency**: 12 cycles guaranteed (49.9 ns @ 240 MHz)
- **Context Switch**: ≤26 cycles worst-case (shadow register swap)
- **Memory**: 512 KB scratchpad (dual-bank, SECDED ECC, 1-cycle read latency)
- **Lockstep**: TCLS 2oo3 voting with mismatch threshold = 3
- **Custom Extensions**: Xdrone coprocessor (quaternion multiply, Kalman filter, FOC)
- **Watchdog**: Configurable timeout with latching fault indication
- **Power Management**: Multi-domain with retention registers, isolation cells, and wake sequencer

### Safety Management Unit (SMU)

Central fault aggregation and safe-state triggering:

- **Fault Classification**: Low / Medium / High severity with configurable thresholds
- **Counter-Based Aggregation**: SPF (single-point fault), LF (latent fault), MPF (multiple-point fault) counters
- **FSM-Controlled Safe-State**: IDLE → EVALUATE → TRIGGER → SAFE_WAIT with acknowledgment handshaking
- **Fault History**: 32-bit sticky register tracking all observed fault codes
- **WCET**: SMU fault → safe-state in ≤4 cycles (measured)

### Memory Subsystem

- **SECDED ECC**: Hamming (38,32) code with overall parity — single-bit correction, double-bit detection
- **Background Scrubbing**: Configurable interval, address auto-increment, error counter
- **Dual-Bank Scratchpad**: Simultaneous core + scrubber access via memory mux
- **1-Cycle Read Latency**: Registered output with ECC decode in-line

### Power Management

- **Power Orchestrator**: FSM managing RUN / SLEEP_PREP / SLEEP / SAFE_STATE transitions
- **Retention Registers**: 32-bit shadow registers with edge-triggered capture and restore verification
- **Isolation Cells**: Safe-state output clamping to prevent glitch propagation
- **Wake Sequencer**: Controlled power-up sequence with completion handshaking

---

## Verification Status

All 24 testbenches pass with Icarus Verilog (`iverilog` + `vvp`):

| Category | Testbench | Status |
|----------|-----------|--------|
| **Core** | `rt_decoder_tb` | ✅ PASS |
| | `rt_alu_tb` | ✅ PASS |
| | `rt_fpu_tb` | ✅ PASS |
| | `rt_muldiv_tb` | ✅ PASS |
| | `rt_branch_unit_tb` | ✅ PASS |
| | `rt_csr_unit_tb` | ✅ PASS |
| | `rt_register_file_tb` | ✅ PASS |
| | `rt_interrupt_controller_tb` | ✅ PASS |
| | `rt_pipeline_tb` | ✅ PASS |
| | `rt_exception_handler_tb` | ✅ PASS |
| | `rt_watchdog_tb` | ✅ PASS |
| | `tcls_voter_tb` | ✅ PASS |
| | `xdrone_decoder_tb` | ✅ PASS |
| | `xdrone_qmul_tb` | ✅ PASS |
| | `xdrone_kalman_tb` | ✅ PASS |
| | `aegis_rt_core_tb` | ✅ PASS |
| | `aegis_rt_core_integration_tb` | ✅ PASS |
| **Memory** | `ecc_secdec_32_tb` | ✅ PASS |
| | `scratchpad_ctrl_tb` | ✅ PASS |
| | `ecc_scrubber_tb` | ✅ PASS |
| **Security** | `smu_tb` | ✅ PASS |
| | `pmp_lite_tb` | ✅ PASS |
| | `constant_time_wrapper_tb` | ✅ PASS |
| **Power** | `power_orchestrator_tb` | ✅ PASS |
| | `retention_reg_tb` | ✅ PASS |
| **Integration** | `aegis_rt_smoke_tb` | ✅ PASS |
| | `aegis_rt_fault_injection_tb` | ✅ PASS |
| | `aegis_rt_wcet_tb` | ✅ PASS |

### Quick Simulation

```bash
# Run a single unit test
iverilog -o /tmp/sim -g2012 rtl/path/to_rtl.v tb/path/to_tb.v
vvp /tmp/sim

# Run all tests via Makefile
make sim
```

---

## Project Structure

```
AEGIS/
├── rtl/                    # RTL source (Verilog 2001)
│   ├── core/               # Pipeline, ALU, TCLS voter, Xdrone, IRQ controller
│   │   ├── aegis_rt_core.v # Top-level RT core
│   │   ├── rt_decoder.v    # RISC-V instruction decoder
│   │   ├── rt_alu.v        # Arithmetic-logic unit
│   │   ├── rt_fpu.v        # IEEE 754 float unit (FTZ/round-to-zero)
│   │   ├── rt_muldiv.v     # Fixed-latency multiply/divide
│   │   ├── rt_branch_unit.v
│   │   ├── rt_csr_unit.v   # CSR read/write + machine-mode CSRs
│   │   ├── rt_register_file.v
│   │   ├── rt_pipeline_if.v       # Pipeline IF/ID/EX/WB registers
│   │   ├── rt_pipeline_controller.v # Hazard detection & forwarding
│   │   ├── rt_exception_handler.v  # Trap handling (ECALL/EBREAK/MRET)
│   │   ├── rt_interrupt_controller.v
│   │   ├── rt_watchdog.v    # Configurable watchdog timer
│   │   ├── rt_dft_scan.v    # Scan-chain DFT wrapper
│   │   ├── rt_atomic.v      # LR/SC atomic reservation
│   │   ├── rv32c_expander.v # RVC compressed instruction expansion
│   │   ├── tcls_voter.v     # Triple-core lockstep 2oo3 voter
│   │   ├── tcls_mismatch_counter.v
│   │   ├── xdrone_decoder.v
│   │   ├── xdrone_dispatcher.v
│   │   ├── xdrone_qmul.v    # Quaternion multiply (2-cycle)
│   │   └── xdrone_kalman.v  # Kalman filter (4-cycle)
│   ├── memory/
│   │   ├── scratchpad_ctrl.v   # Dual-bank scratchpad controller
│   │   ├── scratchpad_bank.v  # Single SRAM bank
│   │   ├── ecc_secdec_32.v    # SECDED Hamming (38,32) encoder/decoder
│   │   ├── ecc_scrubber.v     # Background ECC scrubber FSM
│   │   └── memory_mux.v       # Core/scrubber arbitration mux
│   ├── security/
│   │   ├── smu.v               # Safety Management Unit
│   │   ├── smu_fault_codes.vh  # Fault code & severity definitions
│   │   ├── pmp_lite.v         # Lightweight PMP (4 regions)
│   │   ├── constant_time_wrapper.v
│   │   ├── crypto_accel_if.v
│   │   └── secure_boot_stub.v
│   ├── power/
│   │   ├── power_orchestrator.v  # RUN/SLEEP/SAFE_STATE FSM
│   │   ├── retention_reg_32.v    # Shadow retention register
│   │   ├── isolation_cell_1bit.v
│   │   ├── power_domain_if.v
│   │   └── wake_sequencer.v
│   └── interconnect/
│       ├── axi_lite_rt_slice.v   # Deterministic AXI-Lite bridge
│       ├── tt_arbiter_4master.v  # Time-triggered 4-master arbiter
│       ├── iopmp_ctrl.v          # I/O PMP controller
│       └── axi_timeout_monitor.v
├── tb/                     # Testbenches
│   ├── core/               # Unit tests for core modules
│   ├── memory/             # ECC, scratchpad, scrubber tests
│   ├── security/           # SMU, PMP, constant-time tests
│   ├── power/              # Power orchestrator, retention tests
│   └── integration/        # Smoke, fault injection, WCET tests
├── sby/                    # SymbiYosys formal verification
│   ├── core/               # Pipeline, hazard, IRQ, Xdrone proofs
│   ├── security/           # SMU aggregation, constant-time proofs
│   ├── memory/             # ECC correction, scratchpad proofs
│   ├── power/              # Retention, safe-state proofs
│   └── interconnect/       # Arbiter latency proofs
├── syn/                    # Yosys synthesis scripts
│   ├── core/               # RT core & TCLS voter synthesis
│   ├── memory/             # ECC & scratchpad synthesis
│   └── 130nm_*.tcl         # Library map & constraints
├── openroad/               # OpenROAD PnR flow
│   ├── constraints/        # SDC, UPF, physical constraints
│   └── *.tcl               # Floorplan, CTS, place, route, signoff
├── scripts/                # Python utilities
│   ├── gen_csr_map.py      # CSR address map generator
│   ├── gen_memory_map.py   # Memory map generator
│   ├── cert_traceability.py # Certification clause traceability
│   ├── wcet_analyzer.py    # WCET measurement analysis
│   ├── lint_summary.py     # Lint report aggregation
│   ├── setup_toolchain.sh  # Toolchain installation helper
│   └── setup_pdk.sh        # PDK setup helper
├── firmware/               # RT core test firmware
│   ├── boot.S              # Boot assembly
│   ├── irq_handler.S       # Interrupt handler
│   ├── rt_test.c           # C test routines
│   ├── link.ld             # Linker script
│   └── Makefile
├── docs/                   # Documentation
│   ├── ARCHITECTURE.md     # Full architecture specification
│   ├── CERTIFICATION.md    # Certification plan & evidence
│   ├── VERIFICATION_PLAN.md
│   ├── CSR_SPEC.md         # CSR register specification
│   ├── MEMORY_MAP.md       # Address map documentation
│   ├── RTL_STYLE_GUIDE.md  # Coding standards
│   ├── BUILD_LOG.md        # Build & verification log
│   └── CHANGELOG.md
├── fw/                     # Generated firmware headers
│   └── rt_csr_map.h
├── Makefile                # Top-level build system
├── CLAUDE.md               # AI development context
└── LICENSE                 # Apache 2.0
```

---

## Build System

```bash
# Environment check
make env_check

# Lint all RTL
make lint

# Run unit simulations
make sim

# Run formal verification
make formal

# Synthesis (dry-run)
make synth

# Synthesis with PDK
make synth PDK=sky130

# Place & Route
make pnr PDK=sky130
```

---

## Toolchain

| Tool | Version | Purpose |
|------|---------|---------|
| Icarus Verilog | 10.3+ | RTL simulation |
| Yosys | 0.35+ | Synthesis |
| SymbiYosys | 1.2+ | Formal verification |
| Verilator | 5.024+ | Lint & simulation |
| GTKWave | 3.3.118+ | Waveform viewing |
| OpenROAD | 2.0+ | Place & route |

---

## Coding Standards

- **Verilog 2001 only** — no SystemVerilog constructs
- **Safety annotations** mandatory on all critical paths: `@SAFETY`, `@WCET`, `@CERT`, `@FAULT`
- **Default cases** in all FSMs — prevents latch inference (ISO 26262-8:2018 §8.4.3)
- **Explicit bit-widths** on all constants — no unsized literals
- **Simulation-only code** wrapped in `ifdef SIMULATION`
- **No `always @*`** for combinational logic — use continuous `assign` to avoid iverilog sensitivity issues

---

## WCET Contracts

| Operation | Worst-Case Cycles | Time @ 240 MHz |
|-----------|-------------------|----------------|
| Interrupt Entry | ≤12 | 49.9 ns |
| Shadow Register Swap | ≤18 | 74.9 ns |
| Full Context Switch | ≤26 | 108.3 ns |
| TCLS Quarantine | ≤5 | 20.8 ns |
| SMU Fault → Safe-State | ≤4 | 16.7 ns |
| Power RUN → SAFE_STATE | ≤1 | 4.2 ns |

---

## Certification Targets

| Standard | Level | Domain |
|----------|-------|--------|
| ISO 26262-6:2018 | ASIL-D | Automotive motor control |
| DO-254 | DAL-A | Airborne flight control |
| IEC 61508 | SIL-3 | Industrial safety |

Every code change maps to a certification clause via the traceability system (`scripts/cert_traceability.py`).

---

## Fault Code Reference

| Code | Name | Severity |
|------|------|----------|
| 0x01 | TCLS Mismatch | LOW |
| 0x02 | TCLS Quarantine | LOW |
| 0x04 | ECC Single-Bit | LOW |
| 0x08 | Watchdog Timeout | LOW |
| 0x10 | ECC Double-Bit | MEDIUM |
| 0x11 | Scrubber Corrected | MEDIUM |
| 0x12 | Power Glitch | MEDIUM |
| 0x14 | Clock Monitor Trip | MEDIUM |
| 0x18 | Retention Restore Fail | MEDIUM |
| 0x20 | SPU Violation | HIGH |
| 0x21 | PMP Violation | HIGH |
| 0x22 | IOPMP Violation | HIGH |
| 0x24 | AXI Timeout | HIGH |
| 0x28 | Safe-State Violation | HIGH |
| 0x30 | PMHF Threshold Exceeded | HIGH |

---

## License

- **Core RTL & Testbenches**: Apache 2.0
- **Xdrone Custom Extensions**: Proprietary (contact for licensing)

---

## Status

**BUILD PHASE** — RTL Development & Verification (Phase 1)

All unit testbenches passing. Formal verification and synthesis in progress.
