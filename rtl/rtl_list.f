#===============================================================================
# AEGIS-RV RTL File List (ordered for elaboration)
# Usage: -f rtl/rtl_list.f
#===============================================================================

#--- Core Pipeline ---
rtl/core/rt_pipeline_if.v
rtl/core/rt_pipeline_controller.v
rtl/core/rv32c_expander.v
rtl/core/rt_decoder.v
rtl/core/rt_register_file.v
rtl/core/rt_alu.v
rtl/core/rt_fpu.v
rtl/core/rt_muldiv.v
rtl/core/rt_atomic.v
rtl/core/rt_watchdog.v
rtl/core/rt_branch_unit.v
rtl/core/rt_csr_unit.v
rtl/core/xdrone_decoder.v
rtl/core/xdrone_qmul.v
rtl/core/xdrone_kalman.v
rtl/core/xdrone_dispatcher.v
rtl/core/tcls_voter.v
rtl/core/tcls_mismatch_counter.v
rtl/core/rt_interrupt_controller.v
rtl/core/rt_exception_handler.v
rtl/core/rt_dft_scan.v
rtl/core/aegis_rt_core.v

#--- Memory Subsystem ---
rtl/memory/ecc_secdec_32.v
rtl/memory/ecc_scrubber.v
rtl/memory/scratchpad_bank.v
rtl/memory/scratchpad_ctrl.v
rtl/memory/memory_mux.v

#--- Security ---
rtl/security/smu_fault_codes.vh
rtl/security/smu.v
rtl/security/secure_boot_stub.v
rtl/security/crypto_accel_if.v
rtl/security/constant_time_wrapper.v
rtl/security/pmp_lite.v

#--- Power Management ---
rtl/power/power_domain_if.v
rtl/power/isolation_cell_1bit.v
rtl/power/retention_reg_32.v
rtl/power/wake_sequencer.v
rtl/power/power_orchestrator.v

#--- Interconnect ---
rtl/interconnect/axi_lite_rt_slice.v
rtl/interconnect/tt_arbiter_4master.v
rtl/interconnect/iopmp_ctrl.v
rtl/interconnect/axi_timeout_monitor.v

#--- Top-Level ---
rtl/aegis_rt_top.v
rtl/aegis_top.v
