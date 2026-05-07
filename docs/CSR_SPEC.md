# AEGIS-RV CSR Specification

## CSR Map (RT Domain)

All CSRs accessible only in Machine mode (privilege level 3).
CSR address space: 0x7C0–0x7FF (custom CSR range).

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| 0x7C0 | `aegis_rt_cfg` | RW | RT core configuration (TCLS enable, mismatch threshold) |
| 0x7C1 | `aegis_rt_status` | RO | RT core status (pipeline stage, IRQ pending, fault code) |
| 0x7C2 | `watchdog_cfg` | RW | Watchdog timer configuration (enable, timeout) |
| 0x7C3 | `watchdog_status` | RW1C | Watchdog status (tripped flag, cycles since feed) |
| 0x7C4 | `ecc_scrub_cfg` | RW | ECC scrubber configuration (enable, interval) |
| 0x7C5 | `ecc_scrub_status` | RO | ECC scrubber status (errors corrected, last address) |
| 0x7C6 | `xdrone_cfg` | RW | Xdrone configuration (max depth, precision) |
| 0x7C7 | `xdrone_status` | RO | Xdrone status (current depth, active precision) |
| 0x7C8 | `smu_fault_code` | RW1C | SMU fault code (ISO 26262 mapped) |
| 0x7C9 | `smu_ctrl` | RW | SMU control (safe-state request, fault acknowledge) |
| 0x7CA | `power_cfg` | RW | Power management configuration |
| 0x7CB | `power_status` | RO | Power management status (tile state) |

## Bit Field Details

See CLAUDE.md §9.1 for complete bit field specifications.
