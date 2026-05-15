# AEGIS-RV: Phase Completion Tracker

> **Last Updated**: 2026-05-15  
> **Repository**: [Kiransekar/AEGIS](https://github.com/Kiransekar/AEGIS)  
> **Top Module**: `aegis_rt_core`  
> **Target PDK**: SkyWater Sky130 HD (130nm)  
> **Target Frequency**: 240 MHz (4.167 ns period)

---

## 📊 Phase Status Overview

| Phase | Description | Status | Gate |
|-------|------------|--------|------|
| **Phase 1** | Toolchain & Boot Validation | ✅ Complete | PASS |
| **Phase 2** | ISA Compliance & Formal Verification | ✅ Complete | PASS (160/160 ISA, Formal PASS) |
| **Phase 3.1** | Synthesis (Yosys + Sky130 HD) | ✅ **Complete** | **PASS** |
| **Phase 3.2** | Place & Route (OpenROAD) | ⬜ Pending | — |
| **Phase 3.3** | Gate-Level Simulation (GLS) | ⬜ Pending | — |
| **Phase 4** | Safety Certification Evidence | ⬜ Pending | — |
| **Phase 5** | Debug & Bring-Up Infrastructure | ⬜ Pending | — |

---

## ✅ PHASE 1: Toolchain & Boot Validation — COMPLETE

- **GCC Toolchain**: `riscv64-unknown-elf-gcc` (rv32imacf / ilp32)
- **Boot Sequence**: `_start` → `boot.S` → `main()` verified in simulation
- **Firmware Build**: `boot.S`, `link.ld`, `syscalls.c`, `main.c` — all compiling
- **Result**: `BOOT_OK` confirmed in simulation log

---

## ✅ PHASE 2: ISA Compliance & Formal Verification — COMPLETE

- **ISA Compliance**: 160/160 tests pass (`riscv-arch-test` RV32IMACF)
- **Formal Verification**: All SymbiYosys properties PASS
  - `mtvec_valid.sby` — PASS
  - `lockstep_consensus.sby` — PASS
  - `no_deadlock.sby` — PASS
- **Gate-Level Check**: ✅ Pass

---

## ✅ PHASE 3.1: Synthesis — COMPLETE

### Synthesis Configuration

| Parameter | Value |
|-----------|-------|
| **Tool** | Yosys 0.33 (git sha1 `2584903a060`) |
| **Technology Mapper** | ABC (Berkeley) |
| **PDK Library** | `sky130_fd_sc_hd__tt_025C_1v80.lib` |
| **PDK Path** | `/home/kiran-sekar/OpenROAD/test/sky130hd/` |
| **Top Module** | `aegis_rt_core` |
| **Synthesis Script** | `constraints/synth_sky130.ys` |
| **Output Netlist** | `outputs/aegis_rt_core_syn.v` |
| **Exit Code** | 0 (Success) |

### Chip Area

| Metric | Value |
|--------|-------|
| **Standard Cell Area** | **557,926 µm² (0.558 mm²)** |
| **Total Cells** | 69,705 |
| **Total Wires** | 65,335 (75,508 bits) |
| **Est. Die Area @ 60% util** | ~0.93 mm² |
| **Est. Die Area @ 70% util** | ~0.80 mm² |
| **Est. Die Area @ 80% util** | ~0.70 mm² |
| **Area Budget (CLAUDE.md)** | < 1.5 mm² ✅ |

### Clock Frequency

| Parameter | Value |
|-----------|-------|
| **Target Frequency** | **240 MHz** |
| **Clock Period** | **4.167 ns** |
| **Clock Signal** | `i_clk` |
| **Clock Domain** | RT (Real-Time) |
| **Reset Signal** | `i_rst_n` (active-low, async) |
| **Timing Closure** | Pending P&R (Phase 3.2) |

### Design Hierarchy (All 17 Modules Mapped ✅)

```
aegis_rt_core                     (top)
├── rt_alu                        (ALU — RV32 arithmetic/logic)
├── rt_atomic                     (Atomic memory ops)
├── rt_branch_unit                (Branch prediction/resolution)
├── rt_csr_unit                   (CSR read/write)
├── rt_decoder                    (Instruction decode)
├── rt_exception_handler          (Exception/trap handling)
├── rt_fpu                        (Floating-point unit)
├── rt_interrupt_controller       (Interrupt arbitration)
├── rt_muldiv                     (64-bit multiply/divide)
├── rt_pipeline_controller        (Pipeline hazard control)
├── rt_register_file              (32x32-bit register file)
├── rt_watchdog                   (Hardware watchdog timer)
├── rv32c_expander                (RV32C compressed ISA)
└── xdrone_dispatcher             (Xdrone flight controller)
    ├── xdrone_kalman             (Kalman filter)
    └── xdrone_qmul               (64-bit quaternion multiply)
```

### Module Gate Counts

| Module | Gates | Wires | ABC Time |
|--------|------:|------:|----------|
| `aegis_rt_core` (glue) | 1,418 | 1,925 | < 1 min |
| `rt_alu` | 1,874 | 1,976 | < 1 min |
| `rt_atomic` | 85 | 147 | < 1 min |
| `rt_branch_unit` | 888 | 1,058 | < 1 min |
| `rt_csr_unit` | 895 | 1,296 | < 1 min |
| `rt_decoder` | 869 | 905 | < 1 min |
| `rt_exception_handler` | 248 | 286 | < 1 min |
| `rt_fpu` | 8,588 | 8,692 | ~2 min |
| `rt_interrupt_controller` | 127 | 159 | < 1 min |
| `rt_muldiv` | 28,039 | 28,119 | ~15 min |
| `rt_pipeline_controller` | 67 | 95 | < 1 min |
| `rt_register_file` | 4,430 | 6,529 | < 1 min |
| `rt_watchdog` | 358 | 427 | < 1 min |
| `rv32c_expander` | 843 | 863 | < 1 min |
| `xdrone_dispatcher` | 586 | 742 | < 1 min |
| `xdrone_kalman` | 18,462 | 18,823 | ~5 min |
| **`xdrone_qmul`** | **36,716** | **37,172** | **~8h 20m** |
| **TOTAL** | **~104,000 (pre-opt)** | — | **~9h 5m** |

### Top Cell Types by Area

| Cell Type | Count | Area (µm²) | % of Total |
|-----------|------:|----------:|-----------:|
| `xnor2_1` | 11,759 | 102,990 | 18.5% |
| `xor2_1` | 6,479 | 56,746 | 10.2% |
| `maj3_1` | 4,587 | 45,914 | 8.2% |
| `mux4_2` | 1,362 | 30,674 | 5.5% |
| `nand2_1` | 7,336 | 27,536 | 4.9% |
| `nor2_1` | 6,583 | 24,710 | 4.4% |
| `a21oi_1` | 3,627 | 18,152 | 3.3% |
| `o21ai_0` | 3,519 | 17,612 | 3.2% |

### Synthesis Runtime

| Metric | Value |
|--------|-------|
| **Total Yosys runtime** | ~9 hours 5 minutes |
| **ABC mapping time** | 32,677 seconds (99% of total) |
| **Peak memory** | 1,215 MB |
| **Netlist file size** | 8.1 MB (442,834 lines) |
| **Warnings** | 17 unique (21 total) — all non-critical |

### Synthesis Verification

```bash
# Verify netlist exists and is non-empty
ls -lh outputs/aegis_rt_core_syn.v
# Output: 8.1M — PASS ✅

# Verify exit code
tail -3 outputs/synth.log
# Output: "End of script... Exit code: 0" — PASS ✅

# Verify all modules mapped
grep -c "Re-integrating ABC results" outputs/synth.log
# Output: 17 — PASS ✅ (17/17 modules)
```

---

## ⬜ PHASE 3.2: Place & Route — PENDING

**Tool**: OpenROAD  
**Goal**: Generate physical layout with timing closure (WNS ≥ 0 ns @ 240 MHz)

### Prerequisites
- [x] Synthesis netlist: `outputs/aegis_rt_core_syn.v`
- [ ] SDC timing constraints: `constraints/aegis.sdc`
- [ ] Floorplan configuration
- [ ] Clock tree synthesis (CTS)
- [ ] DRC/LVS clean

---

## ⬜ PHASE 3.3: Gate-Level Simulation — PENDING

**Goal**: Verify synthesized netlist functionally matches RTL behavior

### Prerequisites
- [x] Synthesis netlist: `outputs/aegis_rt_core_syn.v`
- [ ] SDF timing annotation from P&R
- [ ] GLS testbench with firmware hex

---

## ⬜ PHASE 4: Safety Certification Evidence — PENDING

- [ ] Toolchain Qualification (TCL) bundle
- [ ] FMEDA report
- [ ] Traceability matrix (100% `@SAFETY` coverage)

---

## ⬜ PHASE 5: Debug & Bring-Up Infrastructure — PENDING

- [ ] OpenOCD configuration
- [ ] GDB workflow validation
- [ ] JTAG chain verification

---

## ✅ Definition of Tapeout-Ready (Binary Checklist)

- [x] `vvp sim_boot` outputs `BOOT_OK`
- [x] `riscv-arch-test` returns 0 failures (160/160)
- [x] All `sby/*.sby` files return `PASS`
- [x] Synthesis completes with 0 errors (69,705 cells mapped)
- [ ] P&R timing closure: WNS ≥ 0 ns @ 240 MHz
- [ ] DRC/LVS = 0 violations
- [ ] GLS log matches RTL `boot.log`
- [ ] Safety certification evidence generated
- [ ] OpenOCD/GDB workflow verified
- [ ] `BUILD_LOG.md` contains exact toolchain hash, PDK revision, test logs
- [ ] `docs/traceability.json` covers 100% of `@SAFETY` lines
- [ ] No `TODO:` or `FIXME:` in `firmware/`, `rtl/`, `sby/`, `docs/`

> 🚫 **TAPEOUT IS BLOCKED** until all checkboxes are checked.  
> 📝 **Sign-off**: `[ENGINEER NAME] | [DATE] | [GIT COMMIT HASH]`