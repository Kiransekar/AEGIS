# AEGIS-RV Certification Documentation

## ISO 26262 / DO-254 Compliance Mapping

### 1. Safety Goals

| ID | Safety Goal | ASIL | Domain |
|----|------------|------|--------|
| SG-01 | No undetected single-point fault leads to hazardous event | ASIL-D | RT Control |
| SG-02 | Dual-point faults detected within FTI | ASIL-D | RT Control |
| SG-03 | Interrupt latency ≤12 cycles guaranteed | ASIL-D | RT Core |
| SG-04 | TCLS quarantine ≤5 cycles after mismatch threshold | ASIL-D | Core |
| SG-05 | ECC single-bit correction, double-bit detection | ASIL-D | Memory |
| SG-06 | Safe-state transition irreversible without reset | ASIL-D | Power |
| SG-07 | No timing side-channel in crypto/math operations | ASIL-B | Security |

### 2. Safety Mechanism → ISO 26262 Clause Mapping

| Mechanism | Module | ISO 26262-6 Clause | Evidence |
|-----------|--------|-------------------|----------|
| TCLS 2oo3 voting | tcls_voter | §6.4.3 (Monitoring) | sby/core/tcls_properties.sby |
| Mismatch threshold | tcls_mismatch_counter | §6.4.3 (Fault detection) | tb/core/tcls_voter_tb.v |
| SMU fault aggregation | smu | §6.4.5 (Fault reaction) | sby/security/smu_fault_aggregation.sby |
| SECDED ECC | ecc_secdec_32 | §6.4.7 (Memory protection) | sby/memory/ecc_correction.sby |
| Background scrubber | ecc_scrubber | §6.4.7 (Latent fault detection) | tb/memory/ecc_scrubber_tb.v |
| Safe-state FSM | power_orchestrator | §6.4.5 (Safe state) | sby/power/safe_state_transition.sby |
| PMP deny-by-default | pmp_lite | §6.4.3 (Access protection) | tb/security/pmp_lite_tb.v |
| Constant-time wrapper | constant_time_wrapper | §6.4.9 (Timing) | sby/security/constant_time_invariant.sby |
| Interrupt determinism | rt_interrupt_controller | §6.4.9 (Timing) | sby/core/interrupt_determinism.sby |
| Retention registers | retention_reg_32 | §6.4.7 (Data preservation) | sby/power/retention_data_preservation.sby |
| Isolation cells | isolation_cell_1bit | §6.4.5 (Domain isolation) | — |
| AXI timeout | axi_timeout_monitor | §6.4.3 (Bus monitoring) | — |
| **MULDIV fixed latency** | **rt_muldiv** | **§6.4.9 (Timing)** | **sby/core/muldiv_fixed_latency.sby** |
| **Atomic reservation** | **rt_atomic** | **§6.4.3 (Access protection)** | **sby/core/atomic_reservation.sby** |
| **FPU FTZ determinism** | **rt_fpu** | **§6.4.9 (Timing)** | **sby/core/fpu_ftz_determinism.sby** |
| **Pipeline hazard safety** | **rt_pipeline_controller** | **§6.4.3 (Monitoring)** | **sby/core/pipeline_hazard_safety.sby** |
| **Branch determinism** | **rt_branch_unit** | **§6.4.9 (Timing)** | **sby/core/branch_latency.sby** |
| **IRQ 12-cycle entry** | **aegis_rt_core** | **§6.4.9 (Timing)** | **sby/core/irq_12cycle.sby** |
| **Watchdog timeout** | **rt_watchdog** | **§6.4.5 (Fault reaction)** | **tb/core/rt_watchdog_tb.v** |
| **TT arbiter latency** | **tt_arbiter_4master** | **§6.4.9 (Timing)** | **sby/interconnect/tt_arbiter_latency.sby** |

### 3. DO-254 DAL-A Compliance

| Requirement | Evidence | Status |
|-------------|----------|--------|
| Requirements traceability | cert_traceability.py output | Phase 1 |
| Structural coverage | Verilator + formal | Phase 1 |
| Independent verification | Separate TB + formal | Phase 1 |
| Configuration management | git + rtl_list.f | Phase 1 |
| Certification liaison | CERTIFICATION.md | Phase 1 |

### 4. Traceability Matrix Generation

Run `make cert_trace` to generate the full traceability matrix from RTL `@CERT` annotations.

### 5. WCET Evidence

Run `make wcet` to generate timing constraint evidence from `@WCET` annotations.

| Path | WCET (cycles) | WCET (ns @ 240MHz) | Evidence |
|------|--------------|-------------------|----------|
| Interrupt entry | 12 | 49.9 | sby/core/interrupt_determinism.sby |
| Context shadow swap | 18 | 75.0 | rt_register_file.v |
| Full context switch | 26 | 108.3 | ARCHITECTURE.md §2.3 |
| TCLS quarantine | 5 | 20.8 | sby/core/tcls_properties.sby |
| PWM kill assert | 2 | 8.3 | ARCHITECTURE.md §2.3 |
| Xdrone qmul | 2 | 8.3 | xdrone_qmul.v @WCET |
| Xdrone kalman | 4 | 16.7 | xdrone_kalman.v @WCET |
| Constant-time op | 64 | 266.7 | sby/security/constant_time_invariant.sby |
| **MUL (M extension)** | **2** | **8.3** | **sby/core/muldiv_fixed_latency.sby** |
| **DIV (M extension)** | **4** | **16.7** | **sby/core/muldiv_fixed_latency.sby** |
| **FPU single-precision** | **1** | **4.2** | **sby/core/fpu_ftz_determinism.sby** |
| **Atomic LR.W/SC.W** | **1** | **4.2** | **sby/core/atomic_reservation.sby** |
| **Branch resolve** | **1** | **4.2** | **sby/core/branch_latency.sby** |
| **Pipeline stall (load-use)** | **1** | **4.2** | **sby/core/pipeline_hazard_safety.sby** |
| **CSR access** | **1** | **4.2** | **rt_csr_unit.v @WCET** |
