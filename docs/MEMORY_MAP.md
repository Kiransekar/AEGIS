# AEGIS-RV Memory Map

## RT Domain Address Map

| Base Address | End Address | Size | Module | Access | Attributes |
|-------------|-------------|------|--------|--------|------------|
| 0x0000_0000 | 0x0007_FFFF | 512 KB | Scratchpad TCM | RW | 1-cycle, SECDED ECC, dual-bank |
| 0x0008_0000 | 0x0008_0FFF | 4 KB | CSR Space | RW | 1-cycle, privilege-gated |
| 0x0009_0000 | 0x0009_0FFF | 4 KB | Xdrone Decoder | RO | Opcode dispatch |
| 0x000A_0000 | 0x000A_0FFF | 4 KB | SMU Interface | RW1C | Fault code, safe-state |
| 0x000B_0000 | 0x000B_0FFF | 4 KB | Power Orchestrator | RW | Power state control |
| 0x000C_0000 | 0x000C_0FFF | 4 KB | Interrupt Controller | RW | Vector table, priority |
| 0x000D_0000 | 0x000F_FFFF | 192 KB | RESERVED | — | — |
| 0x0010_0000 | 0x001F_FFFF | 1 MB | AXI RT Slice | RW | TT arbitration, IOPMP |
| 0x0020_0000+ | — | — | External Peripherals | RW | Via AXI (IOPMP-gated) |

## Access Rules

- **Scratchpad TCM**: 1-cycle read/write, no cache, ECC-protected
- **CSR/Control**: 1-cycle access, privilege-gated, side-effect aware
- **AXI RT Slice**: Bounded latency ≤120 ns (TT arbitration)
- **All accesses**: Checked by IOPMP (64 entries, 4KB granule, deny-by-default)
