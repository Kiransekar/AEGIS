# AEGIS-RV RTL Style Guide

## Verilog 2001 Compliance (Mandatory)

### Module Declaration
- Explicit port directions, widths, and comments
- All ports documented with purpose

### Always Blocks
- Synchronous reset (`posedge i_clk or negedge i_rst_n`)
- Explicit `default` case in all FSMs
- No inferred latches (default assignments before conditional)

### Combinational Logic
- Use `assign` for simple logic
- Use `always @*` for complex logic with full sensitivity
- Explicit bit-widths on all constants

### Parameters
- `localparam` for module-internal constants
- `parameter` for configurability
- Explicit bit-widths on all numeric parameters

### Memory Primitives
- Synthesizable RAM inference pattern for 130nm PDK
- Wrap simulation-only code in `ifdef SIMULATION`

## Safety Annotations (Mandatory)

| Tag | Purpose |
|-----|---------|
| `@SAFETY` | Safety mechanism description + standard reference |
| `@WCET` | Timing guarantee + analysis method |
| `@CERT` | Traceability ID + requirement document section |
| `@FAULT` | Fault detection mechanism + coverage target |
| `@TEST` | Verification method + coverage metric |
| `@SIDE_CHANNEL` | Mitigation description |
| `@PDK` | PDK-specific implementation note |
| `@SYNTH` | Synthesis-specific note |

## What to Avoid
- **No** implicit bit-widths
- **No** inferred latches
- **No** SystemVerilog features (logic, always_ff, struct packed)
- **No** non-synthesizable constructs outside `ifdef SIMULATION`
