# AEGIS Industry-Standards Audit & Remediation Report

Date: 2026-07-06 · Scope: full repository at commit b82f887 (master)
Method: fresh clone, independent build/lint/simulation reproduction, RTL review.

## Executive summary

AEGIS is an unusually well-documented hobby-to-professional-grade project: the docs tree, safety annotations, formal harnesses, and traceability tooling are ahead of most open-source cores. However, the audit found that the advertised verification results did not reproduce from a fresh clone, and reproducing them independently exposed **two functional RTL bugs, one of which is a critical ISA decode error masked by a simulation/synthesis mismatch**. For a project whose entire value proposition is safety certifiability, reproducibility and sim/synth equivalence are the standards that matter most, and both were broken. This report documents what was found, what was fixed in the attached patch, and what remains.

## Critical findings

### C1 — SUB/SRA misclassified as M-extension (fixed in patch)

In `rtl/core/rt_decoder.v`, M-extension detection was `(opcode == OP_REG) && funct7[5] && !funct7[4]`. RISC-V M-extension instructions have funct7 = 0000001, but SUB and SRA have funct7 = 0100000, which satisfies the old predicate. In hardware, **SUB decodes as MUL**. The synthesized netlist referenced in the latest commit ("69,705 cells") contains this bug.

The unit tests passed anyway because of finding C2 below: the decoder's hand-written sensitivity list `always @(i_instr or i_instr_valid)` caused Icarus to evaluate the decode block before the derived wire `is_m_ext` updated, so simulation read a stale (correct-by-accident) value. Synthesis ignores sensitivity lists, so the silicon behavior diverges from the passing simulation — the textbook sim/synth mismatch that DO-254/ISO 26262 processes exist to catch. Fix applied: `is_m_ext = (opcode == OP_REG) && (funct7 == 7'b0000001)`, and the block converted to `always @*`. All 24 unit testbenches pass with both changes.

### C2 — "No always @*" style rule is unsound (fixed in decoder; policy change recommended)

The coding standard bans `always @*` "to avoid iverilog sensitivity issues." Icarus Verilog has supported `@*` correctly for two decades; the rule as written *causes* the exact hazard it claims to avoid, and it directly masked C1. Recommend updating `docs/RTL_STYLE_GUIDE.md`: combinational logic must use `always @*` (or continuous assign); hand-written sensitivity lists should be a lint error, not a house style. Verilator's 163 BLKSEQ warnings on the decoder all stemmed from this one block and are now gone.

### C3 — Peripheral address decode is dead logic (NOT fixed; needs a design decision)

`rtl/memory/memory_mux.v` compares the 19-bit `i_addr` against constants like `19'h80000`, `19'hA0000`, `19'hB0000`. These require 20 bits and silently truncate (0x80000 → 0x00000, 0xA0000 → 0x20000). Consequences as written: `is_scratchpad = (i_addr < 0)` is always false, and the CSR/Xdrone/SMU/power windows land at the wrong addresses. The 512 KB scratchpad already consumes the full 19-bit space, so the memory map in `docs/MEMORY_MAP.md` is unimplementable on this bus. Two coherent options: widen the address bus to 20 bits end-to-end (core → mux → tops), or move peripheral windows inside the 19-bit space and shrink the scratchpad. This ripples through `aegis_rt_core.v`, `aegis_rt_top.v`, and the CSR map generator, so it was deliberately left for you rather than patched blind. Whichever you choose, add a testbench that exercises every region boundary — the current suite never caught this because no test performs a peripheral-window access through the mux.

### C4 — Advertised results don't reproduce from a fresh clone (fixed in patch)

`make sim` failed immediately on a clean checkout: the Verilator-based `sim_%` rule never passed `-Irtl/security` for `smu_fault_codes.vh`, and more fundamentally it tried to build plain-Verilog testbenches with `verilator --cc --exe` without any C++ harness, which cannot work. The 24/24 pass claim in the README was evidently produced by hand-run iverilog commands, not the checked-in build system. The patch rewrites `sim_%` around Icarus (matching how the testbenches are written), adds the include path, and — importantly — greps the log for failure markers, because `vvp` returns exit code 0 even when tests print FAIL, so the old rule could never have failed a red test. A `sim_integration` target was added, and the four boot/ISA testbenches that require `firmware/build/firmware.hex` (RISC-V GCC toolchain) are excluded from the default target so a toolchain-free clone is green.

## High-priority findings

**No CI.** A safety-oriented IP with zero automated gating is the single largest process gap. The patch adds `.github/workflows/ci.yml` with three jobs: Verilator lint (fails on hard errors, publishes a warning summary), the full iverilog unit + integration suite on every push and PR, and a SymbiYosys formal job on master pushes. Once the warning backlog is cleared, flip the lint job to zero-tolerance — certification audits will expect a clean, enforced lint baseline with formally dispositioned waivers only.

**Formal build artifacts committed to git.** Roughly 3,600 lines of SymbiYosys outputs (`model/`, `engine_0/`, copied `src/` trees) were checked in under `sby/`. These are generated per-run and make diffs noisy; the patch untracks them and extends `.gitignore`.

**Lint backlog (430 warnings).** After the decoder fix the biggest remaining classes are UNUSEDSIGNAL (153), PINCONNECTEMPTY (44), and WIDTHEXPAND/WIDTHTRUNC (36). Most are benign, but seven UNDRIVEN warnings in `aegis_rt_top.v` (`xdrone_valid`, `irq_ack`, config-register bit ranges) look like unfinished integration wiring rather than style noise, and one SYNCASYNCNET warning on `id_instr` in `aegis_rt_core.v` (flopped by both sync and async logic) deserves a design review since mixed reset domains on one register are a classic CDC/reset hazard. Four SELRANGE warnings in `rv32c_expander.v` (indexing bit 5 of a 5-bit field) should be checked against the RVC spec — they may be another latent decode bug of the C1 variety.

**Truncated constants contradict the style guide.** The standard mandates explicit sized literals, yet iverilog reported truncations in `rt_decoder.v` (`7'hE0`, fixed in patch — it silently equaled the existing `7'h60` term) and the `memory_mux.v` constants of C3. Recommend adding `-Wselrange -Wwidth`-clean as a CI gate and treating any truncation warning as an error.

## Medium-priority recommendations

The README's test table drifts from reality: it lists testbenches that don't exist (`rt_alu_tb`, `rt_branch_unit_tb`, `rt_csr_unit_tb`, `rt_register_file_tb`, `rt_muldiv_tb` exists but others don't) while omitting ones that do (`aegis_isa_compliance_tb`, three boot TBs). Generate that table from `find tb -name '*_tb.v'` in CI, or drop it in favor of a badge driven by the workflow. The duplicate `firmware/` and `fw/` directories should be merged — `fw/rt_csr_map.h` is generated output of `scripts/gen_csr_map.py` and belongs in `firmware/generated/` or in `.gitignore`. Consider renaming `master` to `main`, adding a `CONTRIBUTING.md`, tagging a `v0.1.0` release once CI is green, and pinning tool versions (the README says "Yosys 0.35+"; CI should pin exact versions for certification reproducibility). Finally, `CLAUDE.md` at the repo root is fine for AI-assisted development, but the certification story will be stronger if the human-review evidence (who reviewed what, against which clause) lives in the traceability system rather than implied.

## For the certification claims specifically

The badges and README currently state ASIL-D/DAL-A targets alongside "24/24 passing." Given C1 and C3, soften the language to "designed for certifiability" until: (1) an independent ISA compliance suite runs (riscv-arch-test / RISCOF, not hand-written directed tests — a hand-written suite passed while SUB was broken); (2) gate-level simulation of the synthesized netlist runs the same suite, which would have caught C1 immediately; (3) lint is zero-warning with dispositioned waivers; and (4) coverage is actually measured (the file headers claim "100% line" targets but no coverage flow exists in the Makefile — Verilator's `--coverage` or Icarus+covered can provide this).

## What's in the attached patch

`aegis_improvements.patch` (apply with `git apply` from the repo root) contains: the `is_m_ext` fix, the `always @*` conversion, the `7'hE0` dead-term removal, the rewritten `sim`/`sim_%`/`sim_integration` Makefile rules, the `.gitignore` additions with untracking of 3,617 lines of committed sby artifacts, and the new CI workflow. Verified post-patch: all 24 unit testbenches and all 3 integration testbenches pass under `make sim` and `make sim_integration` on a clean Ubuntu 24 container with only `iverilog` installed.
