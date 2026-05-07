# AEGIS-RV Verification Plan

## Verification Strategy

### Phase 1: Module-Level Verification
1. **Lint** (Verilator): All RTL files pass lint with documented waivers
2. **Simulation** (Verilator + Icarus): Unit testbenches per module
3. **Formal** (SymbiYosys): Safety-critical properties proved

### Phase 2: Integration Verification
1. System-level smoke test (boot → interrupt → halt)
2. WCET measurement harness
3. Fault injection testbench (SEU/SET)

### Phase 3: Synthesis & PnR Verification
1. Synthesis with 130nm constraints
2. STA signoff (WNS ≥ 0)
3. DRC/LVS clean

## Coverage Targets

| Category | Target | Method |
|----------|--------|--------|
| Line Coverage | 100% | Simulation |
| Branch Coverage | >90% | Simulation |
| Safety-Critical Path | 100% | Formal + Sim |
| Fault Injection | 100% mechanisms | Fault injection TB |

## Module Verification Matrix

| Module | Lint | Sim | Formal | Status |
|--------|------|-----|--------|--------|
| smu | ✓ | ✓ | ✓ | Phase 1 |
| power_orchestrator | ✓ | ✓ | ✓ | Phase 1 |
| ecc_secdec_32 | ✓ | ✓ | ✓ | Phase 1 |
| scratchpad_ctrl | ✓ | ✓ | ✓ | Phase 1 |
| tcls_voter | ✓ | ✓ | ✓ | Phase 1 |
| rt_interrupt_controller | ✓ | ✓ | ✓ | Phase 1 |
| xdrone_dispatcher | ✓ | ✓ | ✓ | Phase 1 |
| aegis_rt_core | ✓ | ✓ | ✓ | Phase 1 |
| aegis_rt_top | ✓ | ✓ | — | Phase 1 |

### Phase 2: Pipeline Deepening + Xdrone Integration

| Module | Lint | Sim | Formal | Status |
|--------|------|-----|--------|--------|
| rt_decoder | ✓ | ✓ (28 tests) | — | Phase 2 |
| rt_fpu | ✓ | ✓ (10 tests) | ✓ (FTZ determinism) | Phase 2 |
| rv32c_expander | ✓ | — | — | Phase 2 |
| rt_muldiv | ✓ | ✓ (9 tests) | ✓ (fixed latency) | Phase 2 |
| rt_atomic | ✓ | — | ✓ (reservation) | Phase 2 |
| rt_watchdog | ✓ | ✓ (6 tests) | — | Phase 2 |
| rt_pipeline_controller | ✓ | — | — | Phase 2 |
| rt_dft_scan | ✓ | — | — | Phase 2 |
| xdrone_qmul | ✓ | ✓ (3 tests) | — | Phase 2 |
| xdrone_kalman | ✓ | ✓ (4 tests) | — | Phase 2 |
| xdrone_dispatcher | ✓ | ✓ | ✓ | Phase 2 (updated) |
| aegis_rt_core v2.0 | ✓ | ✓ | ✓ (IRQ 12c) | Phase 2 |
| tt_arbiter_4master | ✓ | — | ✓ (latency bound) | Phase 2 |

### Formal Verification Properties (Phase 2)

| Property | Module | Depth | Status |
|----------|--------|-------|--------|
| Branch 1-cycle determinism | rt_branch_unit | 20 | Phase 2 |
| MULDIV fixed latency | rt_muldiv | 10 | Phase 2 |
| Atomic reservation valid/clear | rt_atomic | 15 | Phase 2 |
| FPU FTZ determinism | rt_fpu | 15 | Phase 2 |
| IRQ 12-cycle entry | aegis_rt_core | 20 | Phase 2 |
| TT arbiter latency ≤29 cycles | tt_arbiter_4master | 30 | Phase 2 |
| Constant-time invariant | constant_time_wrapper | 70 | Phase 1+ |
| Retention data preservation | retention_reg_32 | 20 | Phase 1+ |
