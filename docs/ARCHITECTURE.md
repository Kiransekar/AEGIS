# AEGIS-RV Architecture Specification v3.0

## Overview

AEGIS-RV is a safety-certifiable RISC-V processor IP targeting flight control,
motor control, ISO 26262 ASIL-D, and DO-254 DAL-A applications on 130nm CMOS.

## Domain Architecture

### RT Control Domain (Primary Build Target)
- **ISA**: RV32IMACF + Xdrone (custom-0/custom-1)
- **Pipeline**: 4-stage in-order (IF → ID → EX → WB) + 3 multi-cycle states
- **Clock**: 240 MHz (4.167 ns period)
- **Interrupt Latency**: 12 cycles guaranteed (49.9 ns)
- **Memory**: 512 KB scratchpad (dual-bank, 1-cycle latency, SECDED ECC)
- **Lockstep**: TCLS 2oo3 voting, mismatch threshold=3
- **Hazard Control**: RAW detection + data forwarding (EX→ID, WB→ID)
- **DFT**: 4×256-bit scan chains (fuse-gated in production)

### Pipeline v2.0 States
| State | Description | WCET |
|-------|-------------|------|
| RT_FETCH | Instruction fetch from TCM | 1 cycle |
| RT_DECODE | Full RV32IMACF decode + hazard check | 1 cycle |
| RT_EXECUTE | ALU/FPU/Branch/CSR dispatch | 1 cycle |
| RT_WRITEBACK | Register file write | 1 cycle |
| RT_MULDIV | M extension (MUL=2c, DIV=4c) | 2-4 cycles |
| RT_IRQ_ENTRY | Interrupt entry + shadow bank swap | 12 cycles |
| RT_XDRONE | Xdrone dispatch (qmul=2c, kalman=4c) | 2-4 cycles |

### Xdrone Extension
| Operation | Latency | Format |
|-----------|---------|--------|
| qmul (quaternion multiply) | 2 cycles | 4×16-bit signed Q8.8, saturating |
| kalman (INS predict step) | 4 cycles | 6×16-bit state, Q8.8 fixed-point |
| SAT (satellite estimation) | 2 cycles | Stub |
| FOC (field-oriented control) | 2 cycles | Stub |

### Application Domain
- **ISA**: RV64GCV
- **Pipeline**: 7-stage OoO
- **Clock**: 1.2 GHz
- **Memory**: L1/L2 Cache + MMU

### Security Domain
- **ISA**: RV32E
- **Pipeline**: 2-stage
- **Clock**: 80 MHz
- **Features**: PMP + Root of Trust

## Safety Interconnect
- AXI5 with RT-dedicated TT arbitration slice
- IOPMP per master (64 entries, 4KB granule)
- QoS: RT > Security > App > DMA

## Timing Contracts
| Path | WCET | Bound |
|------|------|-------|
| Interrupt Entry | 12 cycles | ≤12 |
| Context Shadow Swap | 18 cycles | ≤18 |
| Context Full Switch | 26 cycles | ≤26 |
| TCLS Quarantine | 5 cycles | ≤5 |
| MUL (M extension) | 2 cycles | =2 |
| DIV (M extension) | 4 cycles | =4 |
| FPU (FTZ mode) | 1 cycle | =1 |
| Atomic LR.W/SC.W | 1 cycle | =1 |
| Branch Resolve | 1 cycle | =1 |
| Pipeline Stall (load-use) | 1 cycle | ≤1 |
| Xdrone qmul | 2 cycles | =2 |
| Xdrone Kalman | 4 cycles | =4 |
| AXI RT Access | 3 cycles | ≤3 |
| Watchdog Timeout | 1 cycle | ≤1 |
