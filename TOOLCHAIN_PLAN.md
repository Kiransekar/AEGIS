<!-- ============================================================================
  AEGIS SOFTWARE TOOLCHAIN ROADMAP — MASTER PLAN v1.0 (DETAILED)
  ============================================================================
  STATUS: READ-ONLY. AGENTS MUST NOT MODIFY THIS FILE. NO EXCEPTIONS.

  This file is the software-side companion to TAPEOUT_PLAN.md and inherits
  its entire §A AGENT OPERATING PROTOCOL verbatim (session checklist, model
  routing, commit format, red-before-green, evidence rule, docs/PROGRESS.md
  / DECISIONS.md / BUGLOG.md schemas). Read TAPEOUT_PLAN.md §A first.
  Software bugs use the SW-xxx prefix in docs/BUGLOG.md.

    * DO NOT edit, append to, or mark tasks complete inside this file.
    * Progress -> docs/PROGRESS.md   Decisions -> docs/DECISIONS.md
    * Cross-plan conflicts (this plan vs TAPEOUT_PLAN.md): TAPEOUT_PLAN
      task IDs win on hardware-owned artifacts (memory map, boot vehicle);
      this plan wins on firmware/, sdk/, verif/sw/. Record any conflict
      resolution in docs/DECISIONS.md.

  Repo owner — enforce mechanically after committing this file:
      chmod 444 TOOLCHAIN_PLAN.md
      git update-index --skip-worktree TOOLCHAIN_PLAN.md
  Add to CLAUDE.md: "TOOLCHAIN_PLAN.md is immutable, same rules as
  TAPEOUT_PLAN.md."
  ============================================================================ -->

# AEGIS — Software Toolchain & Firmware Plan v1.0

| Field | Value |
|---|---|
| Scope | Cross-compiler, codegen, startup/runtime, HAL + drivers, Xdrone intrinsics, execution platforms (RTL sim / Verilator / Renode), quality gates, executive/RTOS, debug & boot, reference apps, SDK |
| Compiler | Pinned xPack `riscv-none-elf-gcc` 14.x (rv32 multilibs included). LLVM optional later |
| ISA string | **Decided in S0-T2** — current `rv32imacf` is invalid (see SW-001/SW-002) |
| Language policy | C11, MISRA C:2012 checked; assembly where contracts demand; no C++ on target; Rust noted as future option only |
| Prime directive | The hardware/software contract is written down, generated from one source, and tested on both sides. Undocumented contracts caused every bug in §B |

Dependency on TAPEOUT_PLAN: S0 requires hardware P1-T2 (memory map) to be
DECIDED (not necessarily implemented). S5 RTL-sim harness is shared with
hardware P2-T1 (RISCOF). S8 boot loader implements hardware P6-T4. S9 demo
firmware feeds hardware P3-T1 (FI workload) and P7-T1 (FPGA pitch).

---

# §B — SOFTWARE DEFECT REGISTER (found in the 2026-07 firmware audit)

Populate docs/BUGLOG.md with these before starting S0. Locate by content,
not line number.

| ID | File | Defect |
|---|---|---|
| SW-001 | `firmware/Makefile` | `ISA ?= rv32imacf` is a **non-canonical ISA string** (canonical order is I M A F D … with C after F). Modern GCC rejects or misparses it. Must be `rv32imafc` — IF the A decision (SW-002) keeps A at all |
| SW-002 | contract | `-march` with `a` licenses GCC to emit **AMO instructions** (amoadd.w, amoswap.w, …). The RTL (`rt_atomic.v`) implements **LR/SC only**. Any compiled atomic RMW → illegal instruction in hardware. Either hardware grows AMOs, or the ISA string drops to `rv32imfc_zalrsc` (GCC 14+ supports Zalrsc), or all atomics are hand-written LR/SC asm. DECISION REQUIRED |
| SW-003 | `firmware/link.ld` | `TCM LENGTH = 512K` — stale against the P1-T2 64 KB decision. Also `main.c` writes a result marker to `0x0001FFFC`, outside 64 KB. Stack top, BSS, everything shifts |
| SW-004 | `firmware/main.c`, `syscalls.c` | UART at `0x40000000` and GPIO at `0x40001000` are **phantom peripherals** — unmapped in the memory map and nonexistent in RTL. Boot TBs grep for UART strings that only work if a TB-side bus monitor fakes a UART. HW/SW contract for console output is undefined |
| SW-005 | `firmware/boot.S` | Never sets `mstatus.FS` — per the privileged spec, executing any F instruction with FS=Off traps. Worse: grep shows `rt_csr_unit.v` may not implement FS at all. The F-extension HW/SW contract (FS handling, FP context in the shadow-bank swap, fcsr) is completely unspecified |
| SW-006 | contract | FPU is FTZ / round-to-zero (per RTL header) — **not IEEE 754 compliant**. GCC generates code assuming IEEE semantics (rounding-mode CSR writes, denormal behavior). Deviations must be documented and a compile-flag policy set; some libm functions will be silently wrong |
| SW-007 | `docs/openocd.cfg` | Pure fiction: FTDI JTAG config, expected-id `0x10000001`, work-area at `0x80000000` (not a mapped address). **No RISC-V Debug Module (DM/DTM) exists in RTL.** No JTAG TAP. Debug strategy is an open decision (S8-T1) |
| SW-008 | `scripts/gen_csr_map.py` | Generator expects a YAML spec that is **not in the repo** — codegen has no input. Meanwhile `firmware/rt_test.c` hand-duplicates CSR addresses (0x7C0–0x7CB) as #defines → guaranteed drift |
| SW-009 | `firmware/syscalls.c` | `_write` returns `void` (newlib needs `int` bytes-written); no `_sbrk`, `_close`, `_fstat`, `_isatty`, `_lseek` → blocks any libc adoption; currently masked by `-nostdlib` |
| SW-010 | `firmware/irq_handler.S` | Clobbers t0–t5 relying on the hardware shadow-bank swap saving them — contract unverified by any test. Dispatch indexes `vector_table[mcause & 0x7FF]` with **no bounds check** — a spurious cause > table size jumps through wild memory |
| SW-011 | repo | No firmware CI, no host unit tests, no static analysis, no stack-usage analysis, no firmware coverage |
| SW-012 | `scripts/setup_toolchain.sh` | Installs only HW tools; builds Yosys from unpinned master; uses `qt5-default` (removed from modern Ubuntu); installs no RISC-V compiler despite the name |

---

# §C — THE PHASES

Order: S0 → S1 → S2 → S3 → {S4, S5 parallel} → S6 → {S7, S8, S9 parallel}.
Every phase ends with an executable exit gate.

════════════════════════════════════════════════════════════════════════════
## PHASE S0 — Contract audit & decisions  [OPUS, ~2 days]
════════════════════════════════════════════════════════════════════════════

### S0-T1 [OPUS] Write the HW/SW contract document (the keystone task)
Create `docs/HW_SW_CONTRACT.md` — every fact firmware relies on, each with
an Evidence column (RTL file + test), UNVERIFIED where none exists yet:
1. Memory map (import the P1-T2 table verbatim; mark generated-from S2).
2. Reset state: PC reset vector value (read from RTL, don't assume 0x0),
   register/CSR reset values firmware may rely on.
3. Interrupt contract: the 12-cycle entry, EXACTLY what hardware does on
   entry (shadow-bank swap scope — integer regs only? FP regs? which
   banks), mcause encoding, `o_irq_vector[10:0]` meaning, mepc semantics,
   nesting rules, what software must/must-not save (resolves SW-010).
4. Exception contract: ECALL/EBREAK/MRET/illegal-instr behavior per
   `rt_exception_handler.v`, mtvec mode (direct vs vectored — RTL truth).
5. F-extension contract: does hardware implement mstatus.FS? fcsr? If FS
   is hardwired-on, spec-deviation note; FP regs in shadow swap or not
   (resolves SW-005). FTZ/RTZ deviations enumerated (resolves SW-006).
6. Atomics contract: LR/SC only; reservation granule/expiry rules from
   `rt_atomic.v` (feeds S0-T2).
7. Custom CSR map 0x7C0+ (from S2 YAML once it exists).
8. Xdrone instruction encodings: extract opcode/funct fields from
   `xdrone_decoder.v` into an encoding table (feeds S4-T1).
9. Console/IO contract: NONE exists (SW-004). Record the S0-T3 decision.
**Method:** read the RTL, don't trust docs/ARCHITECTURE.md — where they
disagree, BUGLOG it. **Acceptance:** doc exists; every row has Evidence or
UNVERIFIED; UNVERIFIED rows each map to a task in S3–S5 that verifies them.

### S0-T2 [OPUS] ISA string & atomics decision (SW-001/SW-002)
Options: (a) `rv32imafc` + hardware team adds AMOs (raise as new TAPEOUT
task, weeks); (b) **`rv32imfc_zalrsc`** — honest string for LR/SC-only
hardware, needs GCC 14+/pinned xPack, C11 atomics via LR/SC loops libgcc
emits or a small `aegis_atomic.h`; (c) `rv32imfc` and forbid `<stdatomic.h>`.
**Recommended: (b).** Record as D-0xx; update Makefile `ISA`/`ABI` in S1-T2.
Whatever is chosen: add a CI check that objdumps every built ELF and greps
for instructions outside the contract
(`riscv-none-elf-objdump -d | grep -E '\bamo'` must be empty under (b)/(c)).

### S0-T3 [OPUS] Console/IO decision (SW-004)
The map has no UART. Options: (a) add a minimal memory-mapped UART-TX
register to RTL inside an existing window (new small TAPEOUT-side task,
recommended — pitch it as `0xB1000`-adjacent or a CSR mailbox);
(b) HTIF-style `tohost` magic address monitored by TBs (works in sim,
dead in silicon); (c) both — tohost for sim speed, UART for silicon.
**Recommended: (c).** Record decision; firmware `console.c` abstracts it
behind `console_putc()` so the choice is a link-time backend.

### S0-T4 [SONNET] Purge software fiction
Per the decisions above: delete or quarantine `docs/openocd.cfg` (move to
`docs/aspirational/` with a header "NO DEBUG HARDWARE EXISTS — see S8"),
fix `scripts/setup_toolchain.sh` (split into `setup_hw_tools.sh` — pinned
versions, no qt5-default — and `setup_sw_tools.sh` created in S1-T1), and
add tombstones to docs/BUILD_LOG.md for each removed fiction.

### PHASE S0 EXIT GATE
`docs/HW_SW_CONTRACT.md` committed with evidence columns · D-entries exist
for ISA string, console, (and FS if hardware change needed → cross-filed to
TAPEOUT plan) · `grep -rn "0x40000000\|0x40001000" firmware/` still present
(fixed in S3) but each occurrence now has a `// SW-004: replaced in S3-T2`
marker · openocd fiction quarantined.

════════════════════════════════════════════════════════════════════════════
## PHASE S1 — Toolchain bring-up & pinning  [SONNET, ~1–2 days]
════════════════════════════════════════════════════════════════════════════

### S1-T1 [SONNET] Pinned toolchain install + container
`scripts/setup_sw_tools.sh` + `docker/sw-toolchain.Dockerfile`:
- xPack `riscv-none-elf-gcc` pinned exact version (14.x line), verified by
  sha256; PATH export documented. Confirm the needed multilib exists:
  `riscv-none-elf-gcc -print-multi-lib | grep <chosen march/mabi>` — if
  absent, build strategy: `--specs=nano.specs` with the closest multilib or
  a crosstool-ng recipe (document which, DECISIONS.md).
- Also: `cppcheck` (with MISRA addon), `gcovr`, `clang-format`, `srecord`,
  python deps for scripts/.
- CI: a `toolchain` job that builds the container and caches it; all
  firmware jobs run inside it. Tool versions echoed into every build log.
**Acceptance:** `docker build` succeeds; `make -C firmware` inside the
container compiles (after S1-T2); versions pinned by digest.

### S1-T2 [SONNET] Fix the firmware Makefile (SW-001 + hygiene)
- `ISA` per S0-T2 decision; `ABI` per S0-T2 (ilp32f if hard-float ABI
  chosen AND multilib exists, else ilp32 — record which and why).
- `CROSS_COMPILE ?= riscv-none-elf-`.
- Flags: add `-ffreestanding -ffunction-sections -fdata-sections
  -Wextra -Werror -g -fstack-usage`; LDFLAGS `-Wl,--gc-sections
  -Wl,-Map=build/firmware.map`.
- Targets: `all`, `hex`, `disasm` (objdump -d to build/firmware.lst),
  `size` (riscv-none-elf-size), `clean`. Every artifact under `build/`
  (gitignored).
- The link script is GENERATED (S2) — Makefile depends on
  `firmware/generated/link.ld`, never on a hand-edited one.
**Acceptance:** clean build in container, zero warnings; `make disasm size`
work; objdump contract-check (S0-T2) green.

### PHASE S1 EXIT GATE
Container builds reproducibly · firmware compiles with the decided ISA
string, -Werror clean · objdump instruction audit green · CI `fw-build`
job required.

════════════════════════════════════════════════════════════════════════════
## PHASE S2 — Single source of truth codegen  [OPUS design, SONNET impl, ~3 days]
════════════════════════════════════════════════════════════════════════════

### S2-T1 [OPUS] Author the machine-readable specs (SW-008)
Create `spec/memory_map.yaml` (regions: name/base/size/attrs, exactly the
P1-T2 table) and `spec/csr_map.yaml` (every 0x7C0+ CSR: address, name,
access, reset value, field breakdown with bit ranges + enums). Content is
transcribed FROM RTL + HW_SW_CONTRACT.md, reviewed against
`rt_csr_unit.v` field by field — any mismatch is a BUGLOG entry decided in
favor of the documented contract (fix RTL or fix spec, never silently).

### S2-T2 [SONNET] Generators + drift gate
Extend `scripts/gen_csr_map.py` and `scripts/gen_memory_map.py` to emit,
from the YAMLs ONLY:
1. `firmware/generated/aegis_csr.h` — addresses, field masks/shifts,
   typed accessor inline functions (`aegis_csr_read_smu_fault()` style),
   plus the `csr_read/csr_write` asm macros (deleting the hand copies in
   rt_test.c).
2. `firmware/generated/aegis_memmap.h` — region bases/sizes as macros +
   `_Static_assert`s (e.g., result-marker address inside TCM).
3. `firmware/generated/link.ld` — MEMORY block from the YAML (fixes
   SW-003), sections layout templated from `spec/link.ld.in`.
4. `docs/CSR_SPEC.md` + `docs/MEMORY_MAP.md` — regenerated, banner
   "AUTO-GENERATED — edit spec/*.yaml".
5. (hook for hardware) the RTL CSR decoder — coordinate with TAPEOUT plan
   before wiring it into rtl_list.f; until then emit to `generated/rtl/`
   and add a comparison check against the hand-written decoder.
CI job `codegen-drift`: regenerate everything, `git diff --exit-code` on
generated files → any hand edit or stale artifact fails the build.
**Acceptance:** rt_test.c contains zero hand-written CSR addresses;
firmware links with the generated link.ld; drift job green and required.

### PHASE S2 EXIT GATE
`spec/*.yaml` reviewed against RTL · all five outputs generated · drift
gate in CI · `grep -rn "0x7C[0-9A-B]" firmware/ --include='*.c' | grep -v
generated` → empty.

════════════════════════════════════════════════════════════════════════════
## PHASE S3 — Startup & runtime correctness  [OPUS, ~1 week]
════════════════════════════════════════════════════════════════════════════

### S3-T1 [OPUS] boot.S rewrite (SW-005)
Ordered, each step commented with its contract reference:
1. `la sp, __stack_top` (+ optional stack-paint pattern for S6-T3).
2. mtvec setup — mode bits per HW_SW_CONTRACT (direct/vectored as RTL
   truly implements; test both claims).
3. **FP enable**: `li t0, MSTATUS_FS_INITIAL; csrs mstatus, t0` then
   `csrwi fcsr, 0` — but ONLY per the S0 contract finding; if hardware has
   no FS, document the deviation and skip, guarded by a generated macro.
4. .data copy loop (currently MISSING — works today only because
   everything is RAM-resident; the UART-loader boot path in S8 changes
   that; write it now, LMA==VMA collapses it to a no-op).
5. BSS clear, then `call main`; `wfi` halt loop with SMU heartbeat kick.
**Red-first:** extend the boot TB to check an initialized .data global and
an FP instruction execute correctly from reset.

### S3-T2 [OPUS] Console + syscalls (SW-004, SW-009)
`firmware/src/console.c`: backends per S0-T3 (tohost sim backend now; UART
backend stubbed until the RTL register exists — compile-time selected).
Rewrite `syscalls.c` as proper newlib-nano stubs: `_write` (int return,
routes fd 1/2 to console), `_sbrk` (heap between `__heap_start`/`__heap_end`
from generated link.ld, with exhaustion → SMU fault hook, NOT silent
wraparound), `_read/_close/_fstat/_isatty/_lseek/_exit` (spec-correct
returns + errno). Switch Makefile to `--specs=nano.specs` + `-lc -lgcc`
once green. Remove phantom GPIO/UART addresses from main.c (replaced by
console API + a result-marker macro from aegis_memmap.h).

### S3-T3 [OPUS] Trap & interrupt runtime (SW-010)
Rewrite `irq_handler.S` + add `firmware/src/trap.c`:
- Entry: verify against the shadow-bank contract with a DIRECTED TEST
  (tb + firmware) that proves which registers hardware preserves; the
  handler saves exactly the complement, nothing more (WCET) and nothing
  less (correctness).
- Bounds-check mcause code against `IRQ_VECTOR_COUNT` (generated); out of
  range → `unhandled_trap()` → SMU fault assert + safe spin, never a wild
  jump.
- Exceptions (mcause interrupt bit clear) route to a C handler table:
  ECALL, EBREAK, illegal-instr (log instr + mepc via console, assert SMU
  fault), misaligned per contract.
- Nesting policy per contract (likely: none; MIE stays 0 in handler) —
  documented + tested.
**Red-first:** TB that injects (a) each defined IRQ, (b) a spurious high
cause, (c) an illegal instruction, (d) ECALL — firmware reports each via
the result marker; runs in `make fw-test` (S5-T1).

### PHASE S3 EXIT GATE
Boot TB green incl. .data + FP checks · newlib-nano hello-world links and
runs on RTL sim printing via console backend · trap TB green incl.
spurious-cause bound check · `grep -rn "0x4000" firmware/` → empty.

════════════════════════════════════════════════════════════════════════════
## PHASE S4 — HAL, drivers, Xdrone intrinsics  [~1 week, parallel with S5]
════════════════════════════════════════════════════════════════════════════

### S4-T1 [OPUS] Xdrone intrinsics header
From the S0-T1 encoding table, write `sdk/include/aegis/xdrone.h`:
- Each custom op as a static-inline using `.insn r` (e.g.
  `__asm__ volatile(".insn r OPCODE, FUNCT3, FUNCT7, %0, %1, %2" ...)`) —
  NEVER raw `.word` (breaks compressed alignment assumptions and disasm).
- Typed wrappers: `xdrone_qmul(q_a, q_b)`, `xdrone_kalman_step(...)`,
  documented cycle counts from RTL (@WCET headers).
- Fixed-point formats documented per RTL (Q-format of quaternion unit —
  extract from `xdrone_qmul.v`, don't guess).
**Verification (mandatory):** `verif/sw/xdrone_intrinsics_tb` — firmware
executes every intrinsic; RTL TB checks the exact expected instruction
reached `xdrone_decoder` and result matches a golden C model
(`sdk/models/xdrone_model.c`, also used by S5-T3 Renode + S6 host tests).
License note: header carries the proprietary-extension license banner.

### S4-T2 [SONNET] Peripheral drivers (one subagent per driver, OPUS review)
`sdk/src/`: `smu.c` (read/clear faults, severity query, safe-state ack
handshake), `watchdog.c` (arm/kick/timeout cfg — kick placed via S7
executive only), `ecc.c` (scrub interval, error counters, single/double
event callbacks), `power.c` (RUN/SLEEP requests + wake), `tcls.c`
(mismatch counter read, quarantine status), `irq.c` (register ISR into the
S3-T3 table). Rules per driver: no busy-wait without timeout+fault, every
register access through generated accessors, header doc states WCET of
every public function (measured in S6-T4), unit-testable logic separated
from register I/O (mockable).
**Acceptance:** each driver has (a) a host unit test with mocked registers,
(b) at least one RTL-sim integration test in `make fw-test`.

### PHASE S4 EXIT GATE
Intrinsics TB green vs golden model · every driver unit-tested (host) and
integration-tested (RTL sim) · no raw register addresses outside generated
headers (`grep -rn "0x[0-9A-Fa-f]\{5\}" sdk/src/ | grep -v generated` → 0).

════════════════════════════════════════════════════════════════════════════
## PHASE S5 — Execution platforms  [OPUS, ~1 week, parallel with S4]
════════════════════════════════════════════════════════════════════════════

### S5-T1 [OPUS] RTL-sim firmware harness (`make fw-test`)
Unify with TAPEOUT P2-T1's RISCOF harness: one `tb/fw/fw_harness_tb.v`
that loads any `build/*.hex` into the 64 KB TCM model, runs to tohost
write or 5M-cycle watchdog, exit code from the result marker. Makefile:
`make fw-test TEST=<name>` builds firmware test + runs harness; `make
fw-test` runs the suite manifest `verif/sw/manifest.yaml`. This is the
slow-but-true platform; CI required job.

### S5-T2 [OPUS] Verilator fast model
Verilate `aegis_rt_top` (post P1 fixes it should be verilator-clean) into
`sim/vaegis` with a C++ main: hex load, cycle loop, tohost, optional FST.
~100–1000× faster than iverilog; used for the long soak tests and S6-T4
WCET measurement (cycle-exact, same RTL — this is the reference clock).

### S5-T3 [OPUS] Renode platform for developer velocity
`renode/aegis.repl` + `renode/aegis.resc`: rv32 core with the decided ISA
string, 64 KB TCM at 0x0, custom-CSR stubs, console backend, and the
Xdrone custom instructions implemented via Renode's Python/C# custom-
instruction hooks calling the same golden-model math as
`sdk/models/xdrone_model.c` (Renode supports one-line Python custom
instructions and CSRs — use them; RTL co-sim is available later if
needed). Renode is the DEVELOPER platform: fast, no timing truth. Every
Renode-passing test must also pass S5-1 RTL sim in CI nightly — Renode
green alone proves nothing for safety claims (write this in the file
header).
**Acceptance:** hello-world + xdrone smoke run identically (same console
output, same result marker) on Renode, Verilator, and iverilog harnesses —
a `make platform-parity` target diffs the three outputs.

### PHASE S5 EXIT GATE
`make fw-test` suite green (CI required) · Verilator model runs ≥100×
faster than iverilog on the soak test (record numbers) · platform-parity
green across all three.

════════════════════════════════════════════════════════════════════════════
## PHASE S6 — Quality gates  [SONNET, ~1 week]
════════════════════════════════════════════════════════════════════════════

### S6-T1 [SONNET] Static analysis + MISRA
CI jobs: `clang-format --dry-run -Werror` (style file committed);
`cppcheck --addon=misra --enable=all` over firmware/ + sdk/ with a
committed suppression file where EVERY suppression has a rationale comment
(MISRA deviations log `docs/MISRA_DEVIATIONS.md` — the format assessors
expect). Gate: zero unsuppressed findings.

### S6-T2 [SONNET] Host unit tests + coverage
Unity (or CppUTest) harness under `verif/sw/unit/`; drivers tested against
mocked registers; xdrone golden model tested against precomputed vectors.
`gcovr` line+branch coverage published in CI summary; ratchet file like
the hardware side (baseline commit, −0.5% tolerance).

### S6-T3 [SONNET] Stack & memory discipline
`-fstack-usage` aggregation script (`scripts/stack_report.py`) → worst-case
static stack per entry point + ISR; compare against the stack region in
the generated link.ld with margin ≥25%; stack-paint check test on RTL sim
(boot paints, soak runs, test reads high-water). Heap: forbid malloc in
safety builds (`-Wl,--wrap=malloc` trap) except in explicitly tagged demo
apps. Gate fails on margin violation.

### S6-T4 [SONNET] Measurement-based WCET for software
The core is deterministic — exploit it: `scripts/sw_wcet.py` drives the
Verilator model, measures cycle counts of every SDK public function and
ISR path across an input sweep, emits `docs/SW_TIMING.md` with
max-observed + the determinism argument (no cache, fixed-latency units ⇒
max-observed over exhaustive/structured sweep = WCET). Each SDK header's
claimed WCET must match the generated numbers (drift gate).

### PHASE S6 EXIT GATE
MISRA gate green with deviations log · unit coverage baseline committed ·
stack report gate green · SW_TIMING.md generated and header-claims drift
gate green.

════════════════════════════════════════════════════════════════════════════
## PHASE S7 — Executive / RTOS strategy  [OPUS decision + ~1 week]
════════════════════════════════════════════════════════════════════════════

### S7-T1 [OPUS] Decision + minimal safety executive
Write the comparison in DECISIONS.md, then implement the default:
- **Default (implement): static cyclic executive** `sdk/exec/` — fixed
  frame table (e.g. 1 kHz major frame), tasks are functions with S6-T4
  WCET budgets checked at build time (sum ≤ frame), watchdog kicked ONLY
  by the frame scheduler on budget compliance, overrun → SMU fault. This
  is the certifiable pattern (no dynamic scheduling to argue about) and
  what flight-control customers expect at DAL-A analogues.
- FreeRTOS port: optional `ports/freertos/` later for demo breadth — note
  honestly that FreeRTOS itself is not safety-certified; SAFERTOS is the
  certified derivative (IEC 61508 SIL 3 / ISO 26262 ASIL-D, with RISC-V
  availability) and Zephyr's safety scope (targeting IEC 61508 SIL 3) is
  still in progress — so the commercial story for certified customers is
  "our executive, or bring SAFERTOS"; record in SAFETY_MANUAL.
**Acceptance:** executive runs the S9 control demo with 3 tasks + budget
enforcement test (deliberately overrun a task in a test build → SMU fault
observed on RTL sim).

════════════════════════════════════════════════════════════════════════════
## PHASE S8 — Debug & boot story  [OPUS, ~1 week]
════════════════════════════════════════════════════════════════════════════

### S8-T1 [OPUS] Debug decision (SW-007) — human sign-off REQUIRED
No DM/DTM exists in RTL. Options, written up in DECISIONS.md:
(a) integrate a RISC-V Debug Module (e.g. PULP riscv-dbg — SystemVerilog,
needs conversion to the repo's Verilog-2001 policy; weeks, real JTAG);
(b) **ROM/UART monitor** — small resident monitor (peek/poke/load/go +
optional gdb remote-serial subset) behind the console UART; zero RTL cost
beyond S0-T3's UART; recommended for demo silicon;
(c) FPGA-only debug via ILA for bring-up, nothing on silicon.
Whichever: docs/openocd.cfg stays quarantined until real hardware backs it.

### S8-T2 [OPUS] Boot loader (implements TAPEOUT P6-T4)
Per the tapeout vehicle decision: UART loader `firmware/boot_loader/` —
ROM-resident (or reset-vector-resident) loader: receive image (length +
CRC32 framed), write to TCM, verify CRC, jump. Shared framing tool
`scripts/fw_load.py` host side. TB: full load-and-boot over the UART model
— this retires the boot-TB firmware.hex fragility for good.

### PHASE S8 EXIT GATE
Debug decision recorded + implemented path smoke-tested · loader TB green
· `docs/DEBUG.md` describes the real (not fictional) debug workflow.

════════════════════════════════════════════════════════════════════════════
## PHASE S9 — Reference applications & SDK packaging  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### S9-T1 [OPUS] Control reference apps
`apps/foc/` — sensored FOC loop (Clarke/Park, PI current loops, SVPWM
math) using Xdrone where profitable, budgeted under the executive;
`apps/ekf/` — attitude EKF using xdrone_qmul/kalman intrinsics vs the
golden model (error bound asserted). Both run on all three platforms;
both are the FI-campaign workload donors (TAPEOUT P3-T1) and the FPGA
demo payload (P7-T1).

### S9-T2 [SONNET] Fault-demo firmware
`apps/fault_demo/`: runs the EKF loop while printing SMU/TCLS/ECC status;
paired with the FI harness and the FPGA inject switch — the iDEX/ADITI
pitch artifact. Output format designed for a live audience (human-readable
one-line status, fault banner on detection).

### S9-T3 [SONNET] SDK packaging + docs
`sdk/` becomes shippable: README quickstart (container → build → run on
Renode in <10 min), API reference generated (doxygen), examples/, the
HW_SW_CONTRACT and SW_TIMING docs included, versioned `sdk-vX.Y` tags
aligned to RTL tags. LICENSE split honored (Apache core / proprietary
xdrone.h).

### PHASE S9 EXIT GATE
FOC + EKF apps green on all platforms with budget enforcement · fault demo
runs end-to-end under injection · `sdk-v0.1` tag with quickstart verified
from a clean container by CI.

---

# §D — STANDING PROHIBITIONS (software, in addition to TAPEOUT §D)

1. Never modify TOOLCHAIN_PLAN.md or TAPEOUT_PLAN.md.
2. Never hand-write a register address, CSR number, or memory-map constant
   in C/asm — generated headers only (spec/*.yaml is the single source).
3. Never let the ISA string, ABI, or compile flags drift from the S0-T2
   decision; the objdump instruction audit is a required CI gate.
4. Never encode a custom instruction with raw `.word` — `.insn` only.
5. Never claim a software WCET, stack bound, or coverage number without
   the generated evidence file (SW_TIMING.md, stack_report, gcovr).
6. Never treat a Renode-only pass as verification — RTL sim is the truth
   platform; Renode is velocity.
7. Never kick the watchdog from anywhere except the executive's frame
   scheduler.
8. Never use malloc/free in safety-tagged builds; no recursion in ISR or
   executive task code (enforced by cppcheck config).
9. Never resolve a HW/SW contract ambiguity by matching current RTL
   behavior silently — write the contract row, test it, BUGLOG mismatches.
10. Never ship or demo with `-O0` timing numbers or with asserts compiled
    out differently between the measured build and the shipped build —
    one canonical release configuration, defined in the Makefile.
