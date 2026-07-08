<!-- ============================================================================
  AEGIS FPGA VALIDATION PLAN — v1.1 (INTERN-EXECUTABLE)
  ============================================================================
  STATUS: READ-ONLY. Do not modify this file. Progress -> docs/PROGRESS.md,
  decisions -> docs/DECISIONS.md, bugs -> docs/BUGLOG.md (FPGA-xxx prefix).
  Inherits TAPEOUT_PLAN.md §A protocol. Agents AND human interns follow it.

  Audience: a fresh intern with Linux basics and one semester of digital
  design, optionally assisted by Claude Code agents. Every phase has:
  GOAL -> STEPS (with all code) -> CHECKPOINT (how you KNOW it worked) ->
  IF IT FAILS (first three things to check).

  Golden rules for the intern:
   1. Never edit rtl/core/** or rtl/memory/** to "make FPGA work". Only
      files under fpga/ may differ from the ASIC design. If the core seems
      to need a change, STOP and file docs/BUGLOG.md FPGA-xxx.
   2. Copy checkpoint evidence (photo, terminal paste, log file) into
      docs/PROGRESS.md for every phase. No evidence = not done.
   3. FPGA results NEVER prove ASIC timing. Cycle COUNTS transfer between
      platforms; nanoseconds do not. Report cycles first, always.

  Owner: chmod 444 FPGA_PLAN.md ; git update-index --skip-worktree FPGA_PLAN.md
  ============================================================================ -->

# AEGIS — FPGA Validation & Benchmark Plan v1.1

> **v1.1 changelog:** Phase F7 rewritten against the full text of the
> source article (Li Yu, June 2026) instead of literature reconstruction:
> exact hybrid VM/CM observer structure, PLL-based angle extraction,
> bandwidth in Hz with Kp=2wc/Ki=wc^2 verified against the article's
> quoted dB values, fs=6 kHz baseline, and the article's three
> experimental findings as reproduction targets. All other phases unchanged;
> task IDs stable. Commit the article text to docs/references/ (F7 step 0).

| Field | Value |
|---|---|
| Primary board | **Digilent Arty A7-100T** (Artix-7 XC7A100T, Vivado-supported, ~101k LUTs — fits triple-core TCLS) |
| Secondary board | Digilent Atlys (Spartan-6 LX45, ISE 14.7 ONLY, ~27k LUTs — single-core soak rig; see §F-ATLYS notes) |
| Cloud track | AWS EC2 F2 + FPGA Developer AMI (Vivado 2024.1) — mass fault-injection farm only (Phase F9) |
| Core clock on FPGA | 50 MHz first (10 MHz fallback). ASIC target stays 100 MHz — unrelated numbers |
| Headline deliverable | **Active-flux-observer + PI-correction FOC benchmark**: cycles/iteration, max loop rate, and measured ZERO cycle jitter (Phase F7) |
| Prerequisites | TAPEOUT_PLAN P0–P1 done (bug fixes, 64 KB map); TOOLCHAIN_PLAN S0–S3 done (compiler, generated link.ld, console, traps) |

Repo layout this plan creates:
```
fpga/
├── arty/
│   ├── fpga_top.v          # board wrapper (Phase F2)
│   ├── uart_tx.v  uart_rx.v
│   ├── bram_tcm.v          # 64 KB BRAM scratchpad (Phase F2)
│   ├── fault_inject.v      # switch-driven bit flips (Phase F6)
│   ├── arty.xdc            # pin constraints
│   └── build.tcl           # scripted Vivado build
├── atlys/                  # ISE variant (optional, single core)
├── sw/                     # host-side python tools
└── README.md
firmware/apps/bench_afo/    # the benchmark app (Phase F7)
```

════════════════════════════════════════════════════════════════════════════
## PHASE F0 — Environment setup (half a day)
════════════════════════════════════════════════════════════════════════════

**GOAL:** Vivado installed, board recognized, repo builds firmware.

**STEPS**
1. Install **Vivado ML Standard** (free edition; ~60 GB disk). During
   install select only Artix-7 device support to save space.
2. Install Digilent board files:
   ```bash
   git clone https://github.com/Digilent/vivado-boards
   cp -r vivado-boards/new/board_files/* \
     <Vivado_install>/data/boards/board_files/
   ```
3. USB/JTAG driver (Linux):
   ```bash
   cd <Vivado_install>/data/xicom/cable_drivers/lin64/install_script/install_drivers
   sudo ./install_drivers
   ```
4. Confirm the toolchain container from TOOLCHAIN_PLAN S1 builds firmware:
   `make -C firmware` must succeed before you touch the FPGA.

**CHECKPOINT:** plug in the Arty; `lsusb` shows a Future Technology Devices
(FTDI) entry; Vivado Hardware Manager "Open target → Auto Connect" finds
`xc7a100t_0`.
**IF IT FAILS:** (1) re-run driver script + replug, (2) try another USB
cable — many are power-only, (3) check `dmesg | tail` for the FTDI probe.

════════════════════════════════════════════════════════════════════════════
## PHASE F1 — First light: blink an LED (half a day)
════════════════════════════════════════════════════════════════════════════

**GOAL:** prove board + toolchain + constraints + programming path with the
dumbest possible design. Every bring-up in history starts here. Do not skip.

**STEPS**
1. `fpga/arty/blink.v`:
   ```verilog
   module blink (
       input  wire clk100,      // Arty 100 MHz oscillator (pin E3)
       output wire [3:0] led
   );
       reg [26:0] cnt = 27'd0;
       always @(posedge clk100) cnt <= cnt + 27'd1;
       assign led = cnt[26:23];  // ~0.75 Hz on led[3]
   endmodule
   ```
2. `fpga/arty/arty.xdc` (start; grows in later phases):
   ```tcl
   ## Clock
   set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk100]
   create_clock -period 10.000 -name sys_clk [get_ports clk100]
   ## LEDs
   set_property -dict {PACKAGE_PIN H5  IOSTANDARD LVCMOS33} [get_ports {led[0]}]
   set_property -dict {PACKAGE_PIN J5  IOSTANDARD LVCMOS33} [get_ports {led[1]}]
   set_property -dict {PACKAGE_PIN T9  IOSTANDARD LVCMOS33} [get_ports {led[2]}]
   set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
   ```
3. `fpga/arty/build.tcl` — scripted build (NEVER click through the GUI for
   real builds; scripts are reproducible, clicking is not):
   ```tcl
   # usage: vivado -mode batch -source build.tcl -tclargs <top_module>
   set top [lindex $argv 0]
   create_project -in_memory -part xc7a100tcsg324-1
   read_verilog [glob ./fpga/arty/*.v]
   # RTL sources added from Phase F2 onward:
   if {[file exists ./rtl/rtl_list.f]} {
     foreach f [split [exec grep -v {^#} ./rtl/rtl_list.f] "\n"] {
       if {$f ne ""} { read_verilog ./$f }
     }
   }
   read_xdc ./fpga/arty/arty.xdc
   synth_design -top $top -include_dirs ./rtl/security
   opt_design ; place_design ; route_design
   report_timing_summary -file build/timing_summary.rpt
   report_utilization    -file build/utilization.rpt
   write_bitstream -force build/${top}.bit
   ```
4. Build and program:
   ```bash
   mkdir -p build
   vivado -mode batch -source fpga/arty/build.tcl -tclargs blink
   # program: Hardware Manager GUI, or:
   vivado -mode batch -source fpga/arty/prog.tcl -tclargs build/blink.bit
   ```
   `fpga/arty/prog.tcl`:
   ```tcl
   open_hw_manager ; connect_hw_server ; open_hw_target
   set_property PROGRAM.FILE [lindex $argv 0] [current_hw_device]
   program_hw_devices [current_hw_device]
   ```

**CHECKPOINT:** four LEDs counting in binary. Photograph it. You have now
verified: install, license, constraints syntax, bitstream generation, JTAG.
**IF IT FAILS:** (1) `build/timing_summary.rpt` exists? build died earlier —
read the last log lines; (2) wrong part number (must be `xc7a100tcsg324-1`);
(3) LEDs wired but dark → XDC pin typo.

════════════════════════════════════════════════════════════════════════════
## PHASE F2 — The board wrapper: clock, reset, memory, UART (2–3 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** the three FPGA-specific pieces the ASIC design doesn't have. The
core itself is instantiated UNTOUCHED.

### F2.1 Clock: 100 MHz in → 50 MHz core clock
```verilog
// inside fpga_top.v — Xilinx PLL primitive, no IP wizard needed
wire clk_fb, clk50_raw, clk50, pll_locked;
PLLE2_BASE #(
    .CLKFBOUT_MULT(10),      // 100 MHz x 10 = 1000 MHz VCO
    .CLKIN1_PERIOD(10.0),
    .CLKOUT0_DIVIDE(20)      // 1000 / 20 = 50 MHz
) u_pll (
    .CLKIN1(clk100), .CLKFBIN(clk_fb), .CLKFBOUT(clk_fb),
    .CLKOUT0(clk50_raw), .LOCKED(pll_locked),
    .RST(1'b0), .PWRDWN(1'b0)
);
BUFG u_bufg (.I(clk50_raw), .O(clk50));
```
If 50 MHz fails timing later, change `CLKOUT0_DIVIDE` to 40 (25 MHz) —
cycle counts in every result stay identical; only wall-clock changes.

### F2.2 Reset: button + PLL lock → clean synchronous release
```verilog
// 2-flop reset synchronizer: async assert, sync deassert
reg [1:0] rst_sync = 2'b00;
wire rst_n_raw = pll_locked & ~btn_reset;   // btn pressed = reset
always @(posedge clk50 or negedge rst_n_raw)
    if (!rst_n_raw) rst_sync <= 2'b00;
    else            rst_sync <= {rst_sync[0], 1'b1};
wire core_rst_n = rst_sync[1];
```

### F2.3 Memory: 64 KB TCM in Block RAM, preloaded with firmware
`fpga/arty/bram_tcm.v` — replaces the OpenRAM/behavioral bank for FPGA:
```verilog
module bram_tcm #(
    parameter INIT_HEX = "firmware.mem"
)(
    input  wire        clk,
    input  wire [13:0] addr,      // 16384 words = 64 KB
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,
    output reg  [31:0] rdata
);
    (* ram_style = "block" *) reg [31:0] mem [0:16383];
    initial $readmemh(INIT_HEX, mem);        // firmware baked into bitstream
    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        if (re) rdata <= mem[addr];          // 1-cycle registered read: SAME
    end                                       // timing contract as ASIC bank
endmodule
```
Firmware hex format for `$readmemh` (one 32-bit word per line):
```bash
riscv-none-elf-objcopy -O binary build/firmware.elf build/firmware.bin
python3 - <<'EOF'
import sys
data = open('build/firmware.bin','rb').read()
data += b'\x00' * (-len(data) % 4)
with open('fpga/arty/firmware.mem','w') as f:
    for i in range(0, len(data), 4):
        f.write(f"{int.from_bytes(data[i:i+4],'little'):08x}\n")
EOF
```
Add this as `make -C firmware fpga_mem`.

**ECC note:** the ASIC path stores 39-bit (data+SECDED) words. For FPGA
either (a) widen to `reg [38:0]` and keep the full ECC path — DO THIS, it
lets Phase F6 inject real correctable errors — or (b) bypass ECC (weaker).
Choose (a); BRAMs are 36-bit native, Vivado will pair them automatically.

### F2.4 UART TX/RX (115200 8N1)
`fpga/arty/uart_tx.v`:
```verilog
module uart_tx #(parameter CLK_HZ=50_000_000, BAUD=115200)(
    input  wire clk, input wire rst_n,
    input  wire [7:0] data, input wire valid, output wire ready,
    output reg  txd
);
    localparam DIV = CLK_HZ / BAUD;           // 434 @50MHz
    reg [15:0] baud_cnt; reg [3:0] bit_idx; reg [9:0] shifter; reg busy;
    assign ready = ~busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin busy<=0; txd<=1'b1; end
        else if (!busy && valid) begin
            shifter <= {1'b1, data, 1'b0};    // stop, data, start
            busy<=1; bit_idx<=0; baud_cnt<=0;
        end else if (busy) begin
            if (baud_cnt == DIV-1) begin
                baud_cnt<=0; txd<=shifter[0];
                shifter <= {1'b1, shifter[9:1]};
                bit_idx <= bit_idx + 1;
                if (bit_idx == 4'd9) busy<=0;
            end else baud_cnt <= baud_cnt + 1;
        end
    end
endmodule
```
(uart_rx is the mirror image — sample at DIV/2 after start edge; agents can
generate it; verify both in a quick iverilog TB before synthesis.)

Memory-map the UART where TOOLCHAIN S0-T3 decided (the real address from
`spec/memory_map.yaml`, NOT 0x40000000): a write to `UART_TX_ADDR` drives
`data/valid`; reading `UART_STATUS_ADDR` returns `{31'b0, ready}`. Firmware's
`console.c` UART backend now becomes real.

### F2.5 fpga_top.v skeleton
```verilog
module fpga_top (
    input  wire clk100, input wire btn_reset,
    input  wire [3:0] sw, output wire [3:0] led,
    output wire uart_txd, input wire uart_rxd
);
    // ... PLL, reset sync from above ...
    wire [19:0] sp_addr; wire [31:0] sp_rdata, sp_wdata;
    wire sp_we, sp_re;

    aegis_rt_top u_aegis (          // UNMODIFIED ASIC top
        .i_clk(clk50), .i_rst_n(core_rst_n),
        .o_sp_addr(sp_addr), .i_sp_rdata(sp_rdata),
        .o_sp_wdata(sp_wdata), .o_sp_we(sp_we), .o_sp_re(sp_re)
        /* remaining ports per aegis_rt_top after P1-T5 wiring */
    );
    // address decode: TCM vs UART, per generated memmap
    // bram_tcm + uart glue here ...
    assign led[0] = heartbeat;      // firmware toggles a GPIO/CSR bit
endmodule
```
Add XDC pins: `uart_txd`=D10, `uart_rxd`=A9, `btn_reset`=D9 (BTN0),
`sw[3:0]`=A8/C11/C10/A10 (Arty A7 master XDC names).

**CHECKPOINT:** `vivado -mode batch ... -tclargs fpga_top` completes with
**WNS ≥ 0** in `build/timing_summary.rpt` and utilization < 80%. Commit both
reports.
**IF IT FAILS (timing):** (1) confirm the divider from P1-T3 is in (a
combinational divider will never close); (2) drop to 25 MHz; (3) read the
worst path in the report and file FPGA-xxx — do NOT "fix" core RTL yourself.

════════════════════════════════════════════════════════════════════════════
## PHASE F3 — BOOT_OK: the processor says hello (1–2 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** firmware boots on real silicon-adjacent hardware and prints over a
real wire. The single most important milestone of bring-up.

**STEPS**
1. Debug ladder — do these IN ORDER, each proves one more layer:
   a. Wire `led[3:1] = pc[19:17]` (bring PC bits out of the core for FPGA
      builds via a `ifdef FPGA` debug port). LEDs flickering = core fetches.
   b. Firmware = infinite loop toggling the heartbeat CSR bit → led[0]
      blinks at a firmware-controlled rate = fetch+decode+execute+CSR work.
   c. Full boot firmware → UART prints.
2. Host side:
   ```bash
   sudo apt install picocom
   picocom -b 115200 /dev/ttyUSB1     # Arty enumerates two ports; try USB1
   ```
3. Expect:
   ```
   main_reached
   BOOT_OK
   ```

**CHECKPOINT:** screenshot of picocom showing BOOT_OK. Frame it.
**IF IT FAILS:** (1) PC LEDs dead → reset polarity or PLL lock — probe
`core_rst_n` on an ILA (Phase F5); (2) PC stuck at reset vector → firmware
.mem not loaded (check `$readmemh` path is relative to where Vivado runs);
(3) garbage characters → baud divisor vs actual clock (did you fall back to
25 MHz and forget CLK_HZ?).

════════════════════════════════════════════════════════════════════════════
## PHASE F4 — Run the real test suites on hardware (2–3 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** the SAME tests from simulation, on the board. New platform, zero
new test logic — that's the discipline.

**STEPS**
1. Firmware test-runner protocol: each test prints one line
   `TEST <name> PASS|FAIL <detail>` and finally `SUITE DONE <pass>/<total>`.
   Reuse the S5-T1 manifest; the console backend is now the real UART.
2. Host checker `fpga/sw/run_board_tests.py`:
   ```python
   #!/usr/bin/env python3
   import serial, sys, re, time
   port = serial.Serial(sys.argv[1], 115200, timeout=120)
   passed = failed = 0
   deadline = time.time() + 300
   while time.time() < deadline:
       line = port.readline().decode(errors='replace').strip()
       if not line: continue
       print(line)
       if line.startswith('TEST'):
           if ' PASS' in line: passed += 1
           else: failed += 1; 
       if line.startswith('SUITE DONE'):
           break
   print(f"== board result: {passed} pass / {failed} fail ==")
   sys.exit(1 if failed or not passed else 0)
   ```
3. Run the riscv-arch-test signature subset on hardware: loader build
   (TOOLCHAIN S8-T2 UART loader) pushes each test binary, board returns the
   signature over UART, host diffs against the Sail reference signatures.
   If the loader isn't ready yet, bake a rotating 5-test image per bitstream
   as the interim (slower, works today).

**CHECKPOINT:** `run_board_tests.py` exits 0; arch-test signature diff
empty. Log files into docs/evidence/.
**Every sim-pass/board-fail divergence is GOLD:** file FPGA-xxx, reproduce
in simulation (that's where you can see everything), root-cause there.

════════════════════════════════════════════════════════════════════════════
## PHASE F5 — Seeing inside: the ILA (1 day, then as-needed)
════════════════════════════════════════════════════════════════════════════

**GOAL:** learn to plant a logic analyzer inside the FPGA before you need
it in anger.

**STEPS**
1. Mark signals in RTL (FPGA wrapper only!) or XDC:
   ```verilog
   (* mark_debug = "true" *) wire [19:0] dbg_sp_addr = sp_addr;
   (* mark_debug = "true" *) wire        dbg_smu_fault = smu_fault;
   ```
2. In build.tcl after synth_design:
   ```tcl
   # auto-insert ILA on all mark_debug nets, 4096-sample depth
   create_debug_core u_ila ila
   set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila]
   # (connect_debug_port lines — use Vivado's "Set Up Debug" wizard once,
   #  then copy the generated tcl here so it's scripted forever after)
   ```
3. Trigger discipline: always trigger on the EVENT (e.g. `smu_fault` rising
   edge), capture window centered (2048 pre / 2048 post). Export waveform
   CSV into docs/evidence/ for any bug you chase.

**CHECKPOINT:** you can capture the exact cycle a UART write occurs,
showing sp_addr == UART_TX_ADDR. Save that capture as your ILA "hello".

════════════════════════════════════════════════════════════════════════════
## PHASE F6 — TCLS fault-injection panel: the product demo (3–4 days)
════════════════════════════════════════════════════════════════════════════

**GOAL:** flip a physical switch → corrupt one core of three → outputs stay
correct → fault LED lights. This is the demo from RISK_PLAN R2-T2, live.

**STEPS**
1. Build the triple-core top (TAPEOUT P3-T3's `aegis_rt_tcls_top`) into the
   wrapper. Utilization check: 3 cores + voter should land ~60–75% of the
   100T. If it doesn't fit, file FPGA-xxx with the utilization report —
   do not trim the core.
2. `fpga/arty/fault_inject.v` — corrupt ONE core's scratchpad write data:
   ```verilog
   // sw[0] = inject enable, sw[2:1] selects victim core 0..2
   // Injection = XOR one bit of core N's sp_wdata, one-shot per press
   module fault_inject (
       input  wire clk, input wire rst_n,
       input  wire inject_btn,           // debounced button
       input  wire [1:0] victim_sel,
       input  wire [31:0] wdata_in,      // from victim core
       input  wire        this_core_is_victim,
       output wire [31:0] wdata_out,
       output reg         injected       // pulse, for LED latch
   );
       reg armed; reg btn_d;
       always @(posedge clk or negedge rst_n)
           if (!rst_n) begin armed<=0; btn_d<=0; injected<=0; end
           else begin
               btn_d <= inject_btn;
               injected <= 1'b0;
               if (inject_btn & ~btn_d) armed <= 1'b1;     // rising edge
               else if (armed && this_core_is_victim) begin
                   armed <= 1'b0; injected <= 1'b1;        // fire once
               end
           end
       assign wdata_out = (armed && this_core_is_victim)
                          ? wdata_in ^ 32'h0000_0100        // flip bit 8
                          : wdata_in;
   endmodule
   ```
   Wire per-core between core and voter. Latch LEDs: led[1]=TCLS mismatch
   flag (from voter), led[2]=SMU fault present, led[3]=SDC canary (should
   NEVER light: firmware checksum mismatch without any fault flag).
3. Demo firmware: run the F7 benchmark loop continuously, print one status
   line per second: `t=NNN pos_err=X.XX faults=<tcls:N ecc:N> status=OK`.
4. Rehearse the 90-second demo script and write it in
   `fpga/README.md#demo-runbook`: power on → BOOT_OK → steady OK lines →
   press inject → mismatch LED + fault count increments → OK lines CONTINUE
   uninterrupted → point at the never-lit SDC LED.
5. Bonus (ECC leg): a second switch XORs one bit on the BRAM read path of
   one bank → firmware reports `ecc:corrected` — visible SECDED in action.

**CHECKPOINT:** video of the full demo runbook. This file goes to R5's
pitch stack.
**IF IT FAILS (mismatch never flags):** the voter isn't actually comparing
the corrupted bus — ILA on the three wdata buses at the voter input; check
the injection is on the CORE side of the voter, not the memory side.

════════════════════════════════════════════════════════════════════════════
## PHASE F7 — THE BENCHMARK: hybrid active-flux observer, PI-correction
##             bandwidth study on AEGIS hardware (1–2 weeks)
════════════════════════════════════════════════════════════════════════════

**Source of truth for this phase:** 李彧 (Li Yu), "How should the bandwidth
of the PI correction loop in an Active-Flux observer be selected?"
(LinkedIn article, June 2026), which builds on [1] "A Robust Encoderless
Control for PMSM Drives: a Revised Hybrid Active Flux Based Technique,"
IEEE Trans. Power Electronics, and references [2] TI InstaSPIN-FOC/MOTION,
SPRUHJ1H. A copy of the article text lives at
`docs/references/afo_bandwidth_article.md` (commit it — do not rely on the
URL staying up). Do not substitute other observer structures; the whole
point is to reproduce THIS study on OUR core.

**GOAL:** implement the article's hybrid voltage-model/current-model
active-flux observer exactly, verify our implementation against the
article's own quoted Bode numbers, reproduce its three experimental
findings on AEGIS hardware, and publish the numbers the article's
STM32/DSP-class platforms never publish: cycles/iteration, max loop rate,
and measured ZERO cycle jitter.

### F7.1 The algorithm — exactly as the article defines it

Per control period Ts (article's analysis uses **fs = 6 kHz**; that is our
baseline configuration):

1. **Voltage-model stator flux with PI correction** (per αβ axis):
   `ψ̇ = (v − Rs·i) + u_corr`, integrated at Ts.
2. **Current-model stator flux** (the reference the PI corrects toward).
   For an IPMSM this must be computed in the rotor frame and rotated back:
   `id, iq = Park(iα, iβ, θ̂)` →
   `ψ_cm(dq) = [ψ_PM + Ld·id , Lq·iq]` →
   `ψ_cm(αβ) = InvPark(ψ_cm(dq), θ̂)`.
3. **PI correction:** `u_corr = Kp·(ψ_cm − ψ) + Ki·∫(ψ_cm − ψ)` per axis.
   **Gains from the correction bandwidth f_bw (in Hz — the article's
   parameter):** `ω_c = 2π·f_bw ; Kp = 2·ω_c ; Ki = ω_c²` (critically
   damped pole placement — VERIFIED below to reproduce the article's
   quoted dB values).
4. **Active flux:** `ψ_act = ψ − Lq·i` (per axis). This vector is aligned
   with the rotor d-axis and carries the angle information.
5. **PLL on the active flux** (the article: "processed by a PLL to output
   the estimated angle and speed") — cross-product phase detector, no
   atan2 in the control path:
   `ε = (ψact_β·cos θ̂ − ψact_α·sin θ̂) / max(|ψ_act|, ε_min)`
   `ω̂ = PI_pll(ε) ; θ̂ += Ts·ω̂` (wrap to ±π).

**Why the bandwidth matters (the article's transfer-function insight):**
the closed observer blends the two models frequency-wise:
`ψ = G_vm(s)·ψ_voltage-model + G_cm(s)·ψ_current-model` with
`G_vm(s) = s²/(s²+Kp·s+Ki)` (high-pass) and
`G_cm(s) = (Kp·s+Ki)/(s²+Kp·s+Ki)` (low-frequency path).
Below the correction bandwidth the current model dominates; above it the
voltage model dominates. The article's design rule, which our sweep must
demonstrate: **low-speed-focused designs set f_bw low (≤ f_electrical/5,
e.g. 5 Hz) so the voltage model dominates at the operating point;
high-speed designs raise it to ~30–40 Hz for observer dynamic response —
and a 5 Hz bandwidth at 360 Hz electrical drives the system to the edge
of losing control.**

### F7.2 Host-side verification FIRST — reproduce the article's Bode numbers

Before any firmware: prove our gain mapping matches the article.
`fpga/sw/afo_bode_check.py`:
```python
#!/usr/bin/env python3
"""Reproduce the article's Fig.3-6 numbers. Acceptance gate for F7."""
import numpy as np
FS = 6000.0                                   # article's sampling rate

def gains_continuous(f_bw, f_op):
    wc = 2*np.pi*f_bw; Kp, Ki = 2*wc, wc*wc
    s = 1j*2*np.pi*f_op
    den = s*s + Kp*s + Ki
    return (20*np.log10(abs((Kp*s+Ki)/den)),   # current-model path
            20*np.log10(abs(s*s/den)))         # voltage-model path

def gains_tustin(f_bw, f_op):                  # discrete @6 kHz, closer to article
    wc = 2*np.pi*f_bw; Kp, Ki = 2*wc, wc*wc
    w = 2*np.pi*f_op
    s = 2*FS*(np.exp(1j*w/FS)-1)/(np.exp(1j*w/FS)+1)   # Tustin-mapped s
    den = s*s + Kp*s + Ki
    return (20*np.log10(abs((Kp*s+Ki)/den)),
            20*np.log10(abs(s*s/den)))

# The article's quoted operating-point values (40 Hz electrical):
checks = [  # (f_bw, expected_cm_dB, expected_vm_dB, tol_dB)
    (5.0,  -12.2, 0.0, 0.5),
    (30.0,  0.163, -3.72, 0.5),
]
ok = True
for f_bw, e_cm, e_vm, tol in checks:
    cm, vm = gains_tustin(f_bw, 40.0)
    good = abs(cm-e_cm) < tol and abs(vm-e_vm) < tol
    ok &= good
    print(f"bw={f_bw:>4} Hz @40Hz: CM={cm:+.2f} dB (art. {e_cm:+.2f})  "
          f"VM={vm:+.2f} dB (art. {e_vm:+.2f})  {'OK' if good else 'FAIL'}")
# also emit full Bode plots (Fig.3/4 reproduction) to docs/evidence/
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
f = np.logspace(-1, np.log10(FS/2), 400)
for f_bw in (5.0, 30.0):
    cm = [gains_tustin(f_bw, x)[0] for x in f]
    vm = [gains_tustin(f_bw, x)[1] for x in f]
    plt.figure(); plt.semilogx(f, cm, label='current model')
    plt.semilogx(f, vm, label='voltage model'); plt.axvline(40, ls=':')
    plt.title(f'Active-flux observer paths, f_bw={f_bw} Hz, fs=6 kHz')
    plt.xlabel('electrical frequency [Hz]'); plt.ylabel('gain [dB]')
    plt.grid(True, which='both'); plt.legend()
    plt.savefig(f'docs/evidence/afo_bode_bw{int(f_bw)}.png', dpi=120)
raise SystemExit(0 if ok else 1)
```
**CHECKPOINT F7.2:** script exits 0 — our Kp/Ki mapping reproduces the
article's −12.2 dB / ~0 dB (5 Hz bw) and +0.163 dB / −3.72 dB (30 Hz bw)
values at the 40 Hz operating point within 0.5 dB, and the two Bode PNGs
visually match the article's Fig. 3/4. Sanity anchor (continuous-domain,
already verified during plan authoring): 5 Hz → CM −12.16 dB; 30 Hz →
CM +0.22 dB, VM −3.88 dB.

### F7.3 The firmware — `firmware/apps/bench_afo/afo.c`
```c
#include <stdint.h>
#include "aegis/csr.h"          /* generated */
#include "trig_lut.h"           /* 256-entry sin/cos LUT + lerp, generated */

typedef struct { float kp, ki, integ, lim; } pi_t;
static inline float pi_step(pi_t *c, float err, float Ts) {
    c->integ += c->ki * err * Ts;
    if (c->integ >  c->lim) c->integ =  c->lim;
    if (c->integ < -c->lim) c->integ = -c->lim;
    float u = c->kp * err + c->integ;
    if (u >  c->lim) u =  c->lim;
    if (u < -c->lim) u = -c->lim;
    return u;
}

/* demo IPMSM parameters — Ld != Lq matters: active flux needs saliency-
   consistent Lq subtraction. Keep one canonical set in bench_params.h. */
#define RS      0.05f
#define LD      0.30f
#define LQ      0.45f
#define PSI_PM  0.85f
#define TWO_PI  6.28318548f
#define PI_F    3.14159274f

typedef struct {
    float Ts;
    float psi_a, psi_b;          /* corrected voltage-model stator flux */
    pi_t  corr_a, corr_b;        /* THE PI correction loops              */
    pi_t  pll;
    float theta_hat, omega_hat;
} afo_t;

void afo_init(afo_t *o, float f_bw_hz, float Ts) {
    float wc = TWO_PI * f_bw_hz;               /* article's parameter */
    o->Ts = Ts;
    o->psi_a = PSI_PM; o->psi_b = 0.0f;        /* aligned start        */
    o->corr_a = (pi_t){ 2.0f*wc, wc*wc, 0.0f, 2.0f };
    o->corr_b = o->corr_a;
    o->pll    = (pi_t){ 2.0f*TWO_PI*50.0f,     /* 50 Hz PLL bw, fixed  */
                        (TWO_PI*50.0f)*(TWO_PI*50.0f), 0.0f, 6000.0f };
    o->theta_hat = 0.0f; o->omega_hat = 0.0f;
}

void afo_step(afo_t *o, float ia, float ib, float va, float vb,
              float *theta_out, float *omega_out)
{
    float c = cos_lut(o->theta_hat), s = sin_lut(o->theta_hat);

    /* (2) current-model flux: Park -> dq flux -> InvPark */
    float id     =  c*ia + s*ib;
    float iq     = -s*ia + c*ib;
    float psid   = PSI_PM + LD*id;
    float psiq   = LQ*iq;
    float cm_a   = c*psid - s*psiq;
    float cm_b   = s*psid + c*psiq;

    /* (3) PI correction toward the current model */
    float ua = pi_step(&o->corr_a, cm_a - o->psi_a, o->Ts);
    float ub = pi_step(&o->corr_b, cm_b - o->psi_b, o->Ts);

    /* (1) corrected voltage-model integration */
    o->psi_a += o->Ts * (va - RS*ia + ua);
    o->psi_b += o->Ts * (vb - RS*ib + ub);

    /* (4) active flux */
    float act_a = o->psi_a - LQ*ia;
    float act_b = o->psi_b - LQ*ib;

    /* (5) PLL on the active flux (cross-product detector, no atan2) */
    float mag2 = act_a*act_a + act_b*act_b;
    float inv  = (mag2 > 1e-6f) ? 1.0f : 0.0f;   /* freeze PLL near zero */
    float eps  = (act_b*c - act_a*s) * inv;
    o->omega_hat  = pi_step(&o->pll, eps, o->Ts);
    o->theta_hat += o->Ts * o->omega_hat;
    if (o->theta_hat >  PI_F) o->theta_hat -= TWO_PI;
    if (o->theta_hat < -PI_F) o->theta_hat += TWO_PI;

    *theta_out = o->theta_hat; *omega_out = o->omega_hat;
}
```
Plus `foc_step()` (Park, two PI current loops, InvPark, SVPWM duty write to
a benchmark register) and `pmsm_plant_step()` — a dq-frame Euler plant fed
by the FOC output, producing the synthetic (i, v) the observer consumes.
`trig_lut.h` is generated by `scripts/gen_trig_lut.py` (agents write it;
256 entries + linear interpolation; document the ~1e-4 amplitude error).
**Host validation first:** `make -C firmware host_afo` compiles the same C
for x86 and runs the F7.4 scenarios against a NumPy reference; commit the
angle-error comparison plot before any board time.

### F7.4 Reproduce the article's three findings on AEGIS hardware

Scenario runner (firmware, one build, selected over UART), fs = 6 kHz:

**Finding A — startup convergence (article Fig. 8 vs Fig. 9).**
Accelerate the plant 0 → f_e ≈ 20 Hz with load. Run once at f_bw = 5 Hz,
once at 30 Hz. Log θ_err(t) = θ̂ − θ_plant over UART (decimated ×10).
Expected reproduction: 5 Hz → clean monotone convergence; 30 Hz → visible
angle oscillation during startup. Plot both; annotate.

**Finding B — high speed with low bandwidth (article Fig. 10).**
Run steady-state at f_e = 360 Hz with f_bw = 5 Hz, then f_bw = 30 Hz and
40 Hz. Metrics: peak and RMS angle-tracking error, speed-estimate lag
(cross-correlation delay between ω_plant and ω̂ during a speed ramp).
Expected reproduction: 5 Hz shows large tracking lag / degraded current
control (the article's "edge of losing control"); 30–40 Hz healthy.

**Finding C — the f_bw ≤ f_e/5 design rule.**
Grid sweep: f_e ∈ {10, 20, 40, 80, 160, 360} Hz × f_bw ∈ {2, 5, 10, 20,
30, 40} Hz. For each cell: RMS angle error over 2 s steady state + a
drift-stress leg (inject a small DC offset on measured current — the
voltage-model weakness the correction exists to fix). Emit CSV:
```
CSV,f_e,f_bw,rms_err_deg,peak_err_deg,dc_settle_ms
```
`fpga/sw/bench_afo_report.py` renders the heatmap; overlay the f_bw=f_e/5
line — the article's rule should trace the low-error valley for the
low-speed half, with the dynamic-response penalty visible at high f_e /
low f_bw.

### F7.5 The AEGIS numbers — cycles, rate, and the zero
```c
static inline uint32_t rdcycle(void){ uint32_t c;
    __asm__ volatile("rdcycle %0":"=r"(c)); return c; }

#define N_ITER 100000
uint32_t c_min=0xFFFFFFFFu, c_max=0; uint64_t c_sum=0;
for (uint32_t i=0;i<N_ITER;i++){
    pmsm_plant_step(&plant,&drv);            /* NOT timed              */
    uint32_t t0 = rdcycle();
    afo_step(&obs, plant.ia, plant.ib, plant.va, plant.vb, &th, &om);
    foc_step(&foc, plant.ia, plant.ib, th, om_ref, &drv);
    uint32_t dt = rdcycle() - t0;
    c_sum += dt; if (dt<c_min)c_min=dt; if (dt>c_max)c_max=dt;
}
printf("AFO+FOC cycles: min=%lu max=%lu mean=%lu JITTER=%lu\n",
       (unsigned long)c_min,(unsigned long)c_max,
       (unsigned long)(c_sum/N_ITER),(unsigned long)(c_max-c_min));
printf("headroom: max rate @%uMHz = %lu Hz  (article baseline fs=6 kHz)\n",
       CLK_MHZ,(unsigned long)((uint64_t)CLK_MHZ*1000000u/c_max));
```
Also print per-region splits (observer alone / FOC alone / plant alone —
instrument each with its own rdcycle pair) and run the whole table twice:
**with and without Xdrone** for any step the coprocessor accelerates —
the delta is Xdrone's published value.

**The claim under test: JITTER == 0.** No cache, fixed-latency FPU and
divider, no speculation ⇒ identical control path = identical cycles.
The one legitimate exception: the PLL freeze branch (`mag2` guard) is
data-dependent — either force both paths to equal cost (compute-and-select
instead of branch; preferred) or report per-path counts. If jitter is
nonzero for any other reason, that's a BUGLOG finding, not a footnote.
This zero — printed next to a 6 kHz control study identical to one run on
STM32/DSP-class hardware — is the headline of the entire benchmark.

### F7.6 Reporting rules (non-negotiable)
- Cycles first, always. Wall-clock only with its measured clock
  ("X µs @ 50 MHz FPGA"). ASIC projection ONLY as `cycles / 100 MHz`,
  labeled "projected, pending silicon."
- State float config (F extension, FTZ/RTZ — non-IEEE, documented in
  HW_SW_CONTRACT.md), LUT trig error bound, -O level; commit exact flags
  beside the numbers.
- Reproduce-don't-assert: every figure in `docs/evidence/afo_bench.md`
  regenerates from `make bench_afo_report`; the article's figure numbers
  (8, 9, 10) are cross-referenced next to our reproductions.
- Cite only the two references the article itself gives ([1] IEEE TPEL
  revised hybrid active-flux paper; [2] TI SPRUHJ1H). Do not invent
  additional links or repos.

**CHECKPOINT F7 (final):** `docs/evidence/afo_bench.md` contains:
(1) F7.2 Bode gate PASS with the two reproduced plots, (2) Findings A/B/C
reproduced with plots + one-paragraph engineering commentary each,
(3) the cycles table with JITTER=0 (or per-path counts + justification),
(4) the with/without-Xdrone delta, (5) the exact build flags. That
document goes into the trust ledger and the R3-T2 comparison work.

════════════════════════════════════════════════════════════════════════════
## PHASE F8 — The soak (ongoing; feeds RISK_PLAN R6-T1)
════════════════════════════════════════════════════════════════════════════

Firmware: F7 loop forever + heartbeat line every 60 s with iteration count,
running checksum, fault counters. Host logger `fpga/sw/soak_logger.py`:
```python
#!/usr/bin/env python3
import serial, time, sys
port = serial.Serial(sys.argv[1], 115200, timeout=300)
log = open(f"soak_{time.strftime('%Y%m%d_%H%M%S')}.log", "a", buffering=1)
last = time.time()
while True:
    line = port.readline().decode(errors='replace').strip()
    now = time.strftime('%F %T')
    if line:
        log.write(f"{now} {line}\n"); last = time.time()
    elif time.time() - last > 180:
        log.write(f"{now} !!! SILENT >180s — possible hang\n"); last = time.time()
```
Run on the Arty; put the **Atlys** on the same duty with the single-core
build (see below). Weekly: `soak_summary.py` appends uptime + fault stats
to docs/TRUST_LEDGER.md. Any hang: ILA capture, reproduce in sim, BUGLOG.

### §F-ATLYS — using your existing board (optional but free)
Single core + 64 KB fits the LX45. Differences: toolchain is **ISE 14.7**
(runs best in the free `14.7 Windows-10/Linux VM` Xilinx ships); clock
primitive is `DCM_SP`/`PLL_BASE` not PLLE2; constraints are **UCF** not XDC:
```ucf
NET "clk100"   LOC = "L15" | IOSTANDARD = LVCMOS33 ;
NET "clk100"   TNM_NET = sys_clk ;
TIMESPEC TS_sys_clk = PERIOD "sys_clk" 100 MHz HIGH 50% ;
NET "uart_txd" LOC = "B16" | IOSTANDARD = LVCMOS33 ;   # Atlys USB-UART
```
No ILA convenience (ChipScope is clunkier) — treat the Atlys purely as the
second soak rig + BOOT_OK sanity board. Do NOT spend intern-days fighting
ISE for anything Phase F5+.

════════════════════════════════════════════════════════════════════════════
## PHASE F9 — AWS F2 fault-injection farm (advanced; agent-assisted)
════════════════════════════════════════════════════════════════════════════

Scope strictly: mass FI campaigns and long regressions. Never demos, never
heritage. Intern executes with an [OPUS] agent driving the CL specifics.

1. **Dev environment:** launch the FPGA Developer AMI (Vivado 2024.1
   preinstalled) on a c-family instance for builds; `git clone aws-fpga`
   (f2 branch), `source hdk_setup.sh`.
2. **CL wrapper:** start from the HDK's simplest RTL example (CL "hello
   world" pattern): AEGIS tcls_top + N-way replication inside the Custom
   Logic region; host↔CL over the shell's AXI-Lite (control: load hex via
   BRAM init ports or a DMA-loaded loader; status/result registers per
   instance; per-instance fault-injection registers replacing Phase F6's
   physical switches — same fault_inject.v, driven by a register write).
3. **Farm controller** `fpga/aws/fi_farm.py`: for each campaign entry
   (target FF path, bit, cycle) → write inject registers → run → collect
   classification → same JSON schema as TAPEOUT P3-T1 so the aggregator
   and FI_REPORT.md are shared.
4. **COST GUARDS (mandatory, before first launch):**
   ```bash
   # hard stop: instance self-terminates after MAX_HOURS no matter what
   aws ec2 run-instances ... --instance-initiated-shutdown-behavior terminate
   # inside user-data:
   echo "sudo shutdown -h +$((MAX_HOURS*60))" | at now
   ```
   plus an AWS Budget alert at a fixed monthly cap, and the §D rule below.
   Bitstream builds for the big part take hours — batch campaign changes;
   don't rebuild per run (fault registers exist precisely so one bitstream
   serves the whole campaign).

**CHECKPOINT:** 10,000-injection campaign completes; classification
distribution matches the Verilator campaign within statistical noise
(chi-square sanity check in the report) — that agreement is itself
evidence both platforms are telling the truth.

---

# §D — STANDING RULES (this plan)

1. Never modify this file; never modify core RTL to satisfy the FPGA.
2. Every phase checkpoint needs committed evidence — no evidence, not done.
3. Cycles are the currency of every published number; wall-clock always
   carries its clock frequency; ASIC projections always labeled projected.
4. Board-fail/sim-pass divergences are always reproduced in simulation
   before any fix is attempted.
5. AWS instances: hard auto-termination set BEFORE launch, budget alarm
   active, and no instance left running without a live job — an agent that
   cannot verify termination reports BLOCKED, it does not assume.
6. The demo runbook is rehearsed before any external showing; a stage-dead
   demo costs more trust than no demo.
