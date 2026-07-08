<!-- ============================================================================
  AEGIS TAPEOUT ROADMAP — MASTER PLAN v2.0 (DETAILED)
  ============================================================================
  STATUS: READ-ONLY. AGENTS MUST NOT MODIFY THIS FILE. NO EXCEPTIONS.

  Rules of engagement for every agent session that reads this file:

    1. NEVER edit, append to, reformat, re-wrap, "fix typos in", or mark
       tasks complete inside this file. Treat write access as absent.
    2. ALL progress   -> docs/PROGRESS.md   (schema defined in §A.4)
       ALL decisions  -> docs/DECISIONS.md  (schema defined in §A.5)
       ALL bug finds  -> docs/BUGLOG.md     (schema defined in §A.6)
    3. If a task here is wrong, impossible, or overtaken by events:
       record it in docs/DECISIONS.md with rationale, choose the closest
       compliant action, continue. Do NOT rewrite the plan.
    4. If you believe you must edit this file, you are wrong. Stop and
       write your reasoning to docs/DECISIONS.md instead.

  Repo owner — enforce mechanically after committing this file:
      chmod 444 TAPEOUT_PLAN.md
      git update-index --skip-worktree TAPEOUT_PLAN.md
  Add to CLAUDE.md (verbatim):
      "TAPEOUT_PLAN.md is the immutable master plan. Never modify it.
       Progress goes to docs/PROGRESS.md, decisions to docs/DECISIONS.md,
       bugs to docs/BUGLOG.md. Read TAPEOUT_PLAN.md §A before any work."
  ============================================================================ -->

# AEGIS — End-to-End Tapeout Plan v2.0

| Field | Value |
|---|---|
| Target | Fabricable, honest, fully traceable RV32IMACF safety core |
| Process | SkyWater SKY130, `sky130_fd_sc_hd` std cells, open flow |
| Tools | Icarus 12+, Verilator 5.x, Yosys 0.38+, OpenROAD 2.0+, SymbiYosys, Magic, netgen, KLayout |
| Signoff clock | **100 MHz (10.0 ns)** at TT 025C 1v80, 300 ps uncertainty. 240 MHz is dead; never write it anywhere again |
| Positioning | Deterministic fault-tolerant flight/mission controller (UAV + space); SCL-180nm portability preserved |
| Tapeout vehicle | Decided in P6-T1 (ChipIgnite-class shuttle vs Tiny Tapeout tile) |
| Plan version | v2.0 — supersedes v1.0; task IDs are stable and unchanged |

---

# §A — AGENT OPERATING PROTOCOL (read fully before ANY task)

## A.1 Session startup checklist (every session, no skipping)

Run these in order and paste outputs into your working notes before editing
anything:

```bash
git status --short                    # must be clean; if dirty, STOP and ask
git log --oneline -5                  # know where you are
cat docs/PROGRESS.md | tail -30       # know what's done
cat docs/DECISIONS.md | tail -30      # know what's been decided
make sim 2>&1 | tail -5               # must be green BEFORE you start
```

If `make sim` is red at session start: your first task is to bisect and fix
the regression (log in docs/BUGLOG.md), regardless of what you were asked to
do. Never build on a red baseline.

## A.2 Model routing & orchestration

- **[OPUS]** tasks -> `claude-opus-4-8`. These involve cross-module
  reasoning, RTL redesign, timing closure, formal debug, or irreversible
  decisions. An Opus session may NOT delegate the core reasoning of an
  [OPUS] task to a subagent; it may delegate mechanical legwork.
- **[SONNET]** tasks -> `claude-sonnet-4-6`. Mechanical, parallelizable,
  per-file work. Pattern: the Opus orchestrator spawns one Sonnet subagent
  per file/unit, gives each the EXACT diff specification, collects diffs,
  reviews every diff line-by-line, and commits only after review.
- Subagent prompts MUST include: (a) the task ID, (b) the acceptance
  command(s) the subagent must run and paste, (c) the sentence "Do not
  modify any file other than <list>", (d) the sentence "Do not modify
  TAPEOUT_PLAN.md".
- A subagent that needs to touch a file outside its list must return and
  report, not improvise.

## A.3 Commit & branch discipline

- Branch per task: `task/P2-T3-sequential-divider`. Merge to master only
  with CI green. No direct commits to master except docs-only changes.
- Commit message format (enforced by convention, checked in review):
  ```
  [P1-T3] Replace combinational divider with radix-2 sequential unit

  Why: 1,136-level critical path through $signed division (see BUGLOG#7).
  Evidence: sim/rt_muldiv.log (2,048 random cases vs reference), STA delta
  in syn/reports/summary.md.
  Trace: @CERT AEGIS-RT-MULDIV-001 updated; ISO 26262-6 §7.4.14 (WCET).
  ```
- One logical change per commit. A commit that mixes an RTL fix with a doc
  reformat will be rejected in review.

## A.4 docs/PROGRESS.md schema (create in P0-T5 exactly like this)

```markdown
| Task | Date | Model | Branch | Evidence | Status |
|------|------|-------|--------|----------|--------|
| P0-T1 | 2026-07-08 | sonnet-4-6 | task/P0-T1-purge-artifacts | CI run #14 | DONE |
```
Status ∈ {TODO, IN-PROGRESS, BLOCKED(reason), DONE, WONTDO(link to DECISIONS)}.
Evidence must be a checked-in file path, CI run, or tagged log — never prose.

## A.5 docs/DECISIONS.md schema

```markdown
## D-003: Scratchpad size reduced to 64 KB (2026-07-09, P1-T2)
Context: 19-bit bus cannot hold 0x80000+ peripheral constants; OpenRAM
practical limits ~4KB/macro, silicon data shows 20-40 MHz macro speed.
Options considered: (a) widen bus to 20 bits, keep 512KB fiction;
(b) 64KB + redrawn map. Chosen: (b). Consequences: link.ld, MEMORY_MAP.md,
gen_memory_map.py, firmware heap config all updated in same branch.
```

## A.6 docs/BUGLOG.md schema

```markdown
## BUG-007: SUB decoded as MUL (is_m_ext predicate wrong)  [FIXED]
Found: 2026-07-06 audit. RTL: rt_decoder.v is_m_ext used funct7[5]&&!funct7[4]
which matches SUB/SRA (funct7=0x20). Masked by: hand sensitivity list
(sim/synth mismatch). Fix: funct7==7'b0000001. Test: rt_decoder_tb SUB case
+ riscv-arch-test rv32i_m/M. Lesson -> style rule P1-T6.
```
Every bug gets an entry BEFORE the fix commit, updated after.

## A.7 The evidence rule (zero tolerance)

Never write a number (MHz, %, cycles, cells, mm², test counts) into README,
docs, or code comments unless a checked-in artifact proves it, and the text
links to that artifact. When you delete a false claim, keep a tombstone in
docs/BUILD_LOG.md: what was claimed, why it was wrong, what replaced it.

## A.8 The red-before-green rule

For every functional bug: (1) write/extend a test that FAILS on current RTL,
commit it on the task branch with `[Pn-Tm][red]` prefix and the failing log;
(2) fix the RTL; (3) commit fix with the passing log. CI on the branch may be
red between (1) and (2) — that is the only sanctioned red.

## A.9 When uncertain

Ambiguity resolution order: (1) this plan; (2) docs/DECISIONS.md;
(3) the RISC-V ISA spec (riscv-spec-20191213 for unprivileged, privileged
v1.12) — the spec ALWAYS beats existing AEGIS RTL behavior; (4) ask the
human via a BLOCKED status + a written question in PROGRESS.md. Never guess
silently on ISA semantics, memory maps, or constraint values.

## A.10 Environment bootstrap (run once per fresh container)

```bash
sudo apt-get update && sudo apt-get install -y \
  iverilog verilator yosys gtkwave python3-pip git make
pip install --break-system-packages riscof
# OSS CAD Suite for sby+solvers+openroad-adjacent tools:
curl -sL <oss-cad-suite release tgz> | tar xz && export PATH=$PWD/oss-cad-suite/bin:$PATH
# Sky130 liberty (for STA/synth): use OpenROAD-flow-scripts platform files,
# vendored under third_party/sky130hd/ (P5-T0 vendors them; do not re-download ad hoc).
make env_check
```
Record tool versions in docs/PROGRESS.md at first use; pin them in CI.

---

# §B — KNOWN DEFECT REGISTER (context you must not rediscover)

These were found in the 2026-07 external audit. Line numbers are approximate
(the audit patch shifts them) — locate by content, not line number.

| ID | File | Defect | Status |
|---|---|---|---|
| BUG-001 | `rtl/core/rt_decoder.v` | `is_m_ext = funct7[5]&&!funct7[4]` matches SUB/SRA → SUB executes as MUL in hardware | FIXED in audit patch — verify applied (P1-T1) |
| BUG-002 | `rtl/core/rt_decoder.v` | `always @(i_instr or i_instr_valid)` hand sensitivity list read stale derived wires; masked BUG-001 (sim/synth mismatch) | FIXED in audit patch — verify |
| BUG-003 | `rtl/core/rt_decoder.v` | `7'hE0` literal truncates to `7'h60` (dead redundant term in FPU int-writeback check) | FIXED in audit patch — verify |
| BUG-004 | `rtl/memory/memory_mux.v` | 19-bit `i_addr` compared to `19'h80000/19'hA0000/...` — constants need 20 bits, truncate; `is_scratchpad=(i_addr<0)`=always false; entire peripheral decode dead | OPEN → P1-T2 |
| BUG-005 | `rtl/core/rt_muldiv.v` | DIV/REM implemented with combinational `/` `%` → ~1,136 gate levels; "4-cycle" is a wait counter around it; no multicycle SDC exists | OPEN → P1-T3 |
| BUG-006 | `Makefile` | Original `sim_%` used `verilator --cc --exe` on plain-Verilog TBs (impossible) + missing `-Irtl/security` + vvp exit code never failed red tests | FIXED in audit patch — verify |
| BUG-007 | `rtl/aegis_rt_top.v` | 7× UNDRIVEN: `xdrone_valid`, `xdrone_opcode`, `irq_ack`, bits of `rt_cfg[31:16,3:0]`, `ecc_scrub_cfg`, `power_cfg[5:0]` — unfinished integration wiring | OPEN → P1-T5 |
| BUG-008 | `rtl/core/aegis_rt_core.v` | SYNCASYNCNET: `id_instr` flopped as both synchronous and asynchronous — mixed reset/clocking on one register | OPEN → P1-T5 |
| BUG-009 | `rtl/core/rv32c_expander.v` | 4× SELRANGE: reads bit 5 (and 5:2) of 5-bit fields at four sites — suspected RVC decode bug of the BUG-001 family | OPEN → P1-T5 |
| BUG-010 | `rtl/aegis_rt_top.v` | Port-width padding warnings: `i_scrub_interval` 31 vs 32 bits; `i_csr_addr` 16 vs 32 bits into pmp_lite | OPEN → P2-T2 |
| BUG-011 | repo | ~3,617 lines of sby build outputs committed (`model/`, `engine_0/`, copied `src/`) | FIXED in audit patch — verify untracked |
| BUG-012 | README/docs | Unverifiable claims: 240 MHz, "24/24 passing" (lists nonexistent TBs `rt_alu_tb`, `rt_branch_unit_tb`, `rt_csr_unit_tb`, `rt_register_file_tb`), ASIL-D/DAL-A badges, "100% line coverage" headers, "69,705 cells @ 240 MHz" commit claim (timing never checked) | OPEN → P0-T3 |
| BUG-013 | `tb/core/aegis_boot*` + ISA TB | 4 testbenches require `firmware/build/firmware.hex` (RISC-V GCC) and fail without it; excluded from default `make sim` by audit patch | Handled — P2-T1 supersedes with RISCOF |
| BUG-014 | `rt_muldiv.v` | Three parallel 32×32 combinational multiplies (signed×signed, signed×unsigned, unsigned×unsigned) — 3× multiplier area | OPEN → P1-T4 |

---

# §C — THE PHASES

Dependency graph: P0 → P1 → P2 → {P3, P4 in parallel} → P5 → P6; P7 parallel
from P3 onward. Never start Pn+1 while Pn exit gate is red, except where
"overlap" is stated.

════════════════════════════════════════════════════════════════════════════
## PHASE 0 — Repo hygiene & honesty reset  [SONNET, ~1–2 days]
════════════════════════════════════════════════════════════════════════════

### P0-T1 [SONNET] Purge committed build artifacts
**Files:** `.gitignore`, everything under `sby/*/`
**Procedure:**
1. `git ls-files | grep -E 'sby/.*/(model|engine_[0-9]+|src)/' > /tmp/purge.txt`
   Also grep for `logfile.txt`, `*.sqlite`, `status`, `PASS`, `FAIL` under sby/.
2. Inspect /tmp/purge.txt manually: KEEP any hand-written `.sby` config and
   any hand-written SVA/property `.sv`/`.v` that lives at the sby dir top
   level. The copied `src/*.v` files are duplicates of rtl/ — verify with
   `diff` before deleting; if a copy differs from rtl/, STOP: that's an
   undocumented fork → log to BUGLOG and ask.
3. `git rm -r --cached` the artifact paths; confirm `.gitignore` already has
   the `sby/**/model/` etc. patterns from the audit patch; add any missing.
4. **Do NOT rewrite git history** (no filter-branch/filter-repo) — the
   history is evidence.
**Acceptance:** `git ls-files | grep -cE 'sby/.*/(model|engine|src)/'` → `0`;
`make sim` green; sby configs still present (`find sby -name '*.sby' | wc -l`
unchanged from before).
**Common mistake:** deleting the `.sby` property files themselves. They are
the product; the run directories are the trash.

### P0-T2 [SONNET] Merge `fw/` into `firmware/`
**Procedure:** move generation of `rt_csr_map.h` (from
`scripts/gen_csr_map.py`) to output `firmware/generated/rt_csr_map.h`;
update `firmware/Makefile` include path and any `#include` in
`firmware/*.c`; `git rm -r fw/`; add `firmware/generated/` to `.gitignore`;
add a `make csr_headers` target that regenerates it.
**Acceptance:** `test ! -d fw`; `make csr_headers && ls firmware/generated/rt_csr_map.h`;
grep shows no remaining reference to `fw/` anywhere
(`grep -rn '\bfw/' --include='*' . | grep -v '.git/'` → empty).

### P0-T3 [SONNET] Strip false/unproven claims (BUG-012)
**Files:** `README.md`, badge URLs, `docs/*.md`, RTL file headers.
**Procedure — do ALL of these:**
1. README: every "240 MHz" / "4.167 ns" → "100 MHz signoff target (evidence:
   docs/TIMING.md, populated in P5)". Recompute the WCET table's ns column
   at 10.0 ns/cycle or delete the ns column until P5.
2. README: delete the hand-written 24-row test table. Replace with: CI badge
   + the sentence "The authoritative test list is `find tb -name '*_tb.v'`;
   results: see latest CI run." (Nonexistent TBs listed in BUG-012 vanish
   with the table.)
3. Badges: `Safety-ASIL--D_/_DAL--A-red` badge → `Safety-designed_for_certifiability-blue`.
   `Tests-24%2F24_passing` → the dynamic GitHub Actions workflow badge.
   `Clock-240_MHz` → `Clock-100_MHz_target`.
4. RTL headers: `grep -rn "Coverage Target: 100%" rtl/` → replace each with
   `Coverage: measured in CI (make coverage)`. Same for `Clock: 240 MHz`
   header lines → `Clock: 100 MHz signoff target`.
5. Append a "Corrections" section to `docs/BUILD_LOG.md` (tombstones per
   §A.7) covering: 240 MHz, 24/24, ASIL/DAL badges, the "69,705 cells @
   0.558mm² @ 240 MHz" commit-message claim (state: cell/area plausible,
   timing claim invalid — no STA was run).
6. `docs/CERTIFICATION.md`: reframe from "certification targets" to
   "certification methodology alignment"; explicitly state no assessment has
   occurred.
**Acceptance:** `grep -rniE '240 ?MHz|24/24|ASIL-D|DAL-A' README.md docs/ rtl/ | grep -v BUILD_LOG` → empty;
CI green.
**Common mistake:** deleting the WCET *cycle* numbers. Cycles stay (they get
verified in P3-T2); only unverified *time* and *frequency* claims go.

### P0-T4 [SONNET] WCET table evidence annotation
For each WCET row in README/docs, add an Evidence column: either a testbench
path + log, or the literal text `target — unverified (P3-T2)`.
**Acceptance:** every row has a non-empty Evidence cell.

### P0-T5 [SONNET] Create tracking docs
Create `docs/PROGRESS.md`, `docs/DECISIONS.md`, `docs/BUGLOG.md` with the
§A.4/A.5/A.6 schemas, pre-populated: PROGRESS with all task IDs as TODO;
BUGLOG with §B entries BUG-001..014 verbatim.
**Acceptance:** files exist; BUGLOG contains 14 entries.

### P0-T6 [SONNET] Archive stale planning docs
`git mv Phase.md docs/HISTORY_phases.md`; prepend "ARCHIVED — superseded by
TAPEOUT_PLAN.md" banner. Check `CLAUDE.md` for stale instructions that
contradict this plan (e.g., the "no always @*" rule); update CLAUDE.md to
defer to this plan and docs/RTL_STYLE_GUIDE.md.
**Acceptance:** `CLAUDE.md` contains the immutability sentence from the
header of this file.

### PHASE 0 EXIT GATE (run all; paste into PROGRESS.md)
```bash
git ls-files | grep -cE 'sby/.*/(model|engine|src)/'         # 0
test ! -d fw && echo OK                                       # OK
grep -rniE '240 ?MHz|ASIL-D|DAL-A' README.md rtl/ | wc -l     # 0
make sim 2>&1 | grep -c FAILED                                # 0
```

════════════════════════════════════════════════════════════════════════════
## PHASE 1 — Correctness & constraints reset  [~3–5 days]
════════════════════════════════════════════════════════════════════════════

### P1-T1 [OPUS] Verify audit patch applied (BUG-001/002/003/006/011)
**Procedure:** confirm each fix by content:
```bash
grep -n "funct7 == 7'b0000001" rtl/core/rt_decoder.v          # BUG-001 fixed
grep -cn "always @(i_instr" rtl/core/rt_decoder.v             # 0 (BUG-002)
grep -n "7'hE0" rtl/core/rt_decoder.v                         # empty (BUG-003)
grep -n "iverilog -g2012 -Irtl/security" Makefile             # BUG-006 fixed
```
If any check fails, apply `aegis_improvements.patch` (repo root or request
from owner) with `git apply --check` first. Then run the full suite:
`make sim && make sim_integration` — expect 24 unit + 3 integration green.
**Acceptance:** all greps as annotated; suites green; PROGRESS updated with
the log path.

### P1-T2 [OPUS] Memory map redesign (BUG-004) — THE big decision
**Context:** 512 KB fills all 19 address bits; peripherals at 0x80000+ can't
exist. OpenRAM reality (silicon-tested ~20–40 MHz, ~4 KB practical macros)
kills 512 KB anyway.
**Mandated decision (record as D-00x, deviate only with written rationale):**
adopt **Option B — 64 KB scratchpad + redrawn map**, bus stays ≥20 bits so
every constant fits with headroom. Concrete map (use exactly this unless
DECISIONS.md says otherwise):

| Region | Base | Top | Size |
|---|---|---|---|
| Scratchpad TCM | 0x00000 | 0x0FFFF | 64 KB |
| CSR window | 0x80000 | 0x80FFF | 4 KB |
| Xdrone | 0x90000 | 0x90FFF | 4 KB |
| SMU | 0xA0000 | 0xA0FFF | 4 KB |
| Power | 0xB0000 | 0xB0FFF | 4 KB |

i.e. keep the documented map, widen `i_addr`/`o_sp_addr` and friends to
**20 bits [19:0]**, and size ALL comparison constants as `20'h...`.
**Files rippled:** `memory_mux.v`, `scratchpad_ctrl.v`, `scratchpad_bank.v`
(depth param), `aegis_rt_core.v` (o_sp_addr width), `aegis_rt_top.v`,
`docs/MEMORY_MAP.md`, `scripts/gen_memory_map.py`, `firmware/link.ld`
(RAM LENGTH = 64K), `firmware/Makefile`.
**Red-first test (write BEFORE the fix):** `tb/memory/memory_map_tb.v` that,
for EVERY region: reads/writes base, base+4, top-3, top; asserts exactly one
region-select is high per access; asserts an access to an unmapped hole
(e.g. 0x70000) raises the fault path. This TB must FAIL on current RTL
(scratchpad never selected) — commit the failing log per §A.8.
**Acceptance:** memory_map_tb green; ZERO iverilog "constant truncated"
warnings from memory_mux (`iverilog ... 2>&1 | grep -c truncated` → 0 for
this file); full suite green; MEMORY_MAP.md regenerated by script, not
hand-edited.
**Common mistakes:** (a) fixing constants to 19-bit values that "fit" by
moving peripherals — do not invent a new map beyond the table above;
(b) forgetting link.ld → firmware silently links against ghost RAM;
(c) leaving `o_sp_addr [18:0]` in the core while the mux is 20-bit — widths
must match end-to-end, verify with `verilator --lint-only -Wall`.

### P1-T3 [OPUS] Sequential divider (BUG-005)
**Spec (implement exactly):** non-restoring radix-2, 32 iterations + 2
setup/fixup cycles = **fixed 34-cycle latency, data-independent** (never
early-terminate — determinism is the product). Interface unchanged
(`i_valid/o_done` handshake already exists via the wait counter — replace
counter semantics with real iteration count; update any decoder/pipeline
stall assumption from 4 → 34 cycles).
**RISC-V semantics (spec v20191213 §7.2 — the spec wins over old RTL):**

| Case | DIV | DIVU | REM | REMU |
|---|---|---|---|---|
| b = 0 | −1 (all ones) | 2³²−1 | a | a |
| a = −2³¹, b = −1 | −2³¹ | n/a | 0 | n/a |

**Red-first test:** extend `rt_muldiv_tb.v`: (1) the 4 corner cases above,
(2) 2,048 pseudorandom (a,b) pairs checked against a `/`-and-`%` reference
model kept inside `ifdef SIMULATION`, (3) an assertion that o_done always
arrives exactly 34 cycles after i_valid (determinism check), (4) back-to-back
operations. Seed the PRNG with a fixed constant for reproducibility.
**Also update:** `@WCET` header (DIV = 34), README WCET row, decoder/pipeline
stall logic + `rt_pipeline_tb.v` case where an interrupt arrives mid-divide
(interrupt latency contract must hold — divide is abandoned-and-restarted or
completed; DECIDE, document in DECISIONS.md, and test the chosen behavior).
**Acceptance:** rt_muldiv_tb green incl. determinism assertion; pipeline TB
green; `yosys synth` of rt_muldiv alone shows no `$div`/`$mod` cells
(`yosys -p 'read_verilog rt_muldiv.v; synth; stat' | grep -c '\$div'` → 0).

### P1-T4 [OPUS] FPU + multiplier restructure (BUG-014, FPU audit)
1. Inspect `rt_fpu.v`: if FDIV.S/FSQRT.S use combinational `/` or
   iterative-unrolled logic, convert to fixed-latency sequential (suggest
   Goldschmidt or digit-recurrence; latency documented; determinism
   assertion in TB like P1-T3).
2. Multiplier: replace the 3 parallel 33×33 products with ONE signed 33×33
   multiply using sign-extended operands (`{a[31]&sgn_a, a} * {b[31]&sgn_b, b}`
   pattern) selected per MUL/MULH/MULHSU/MULHU; keep 2-cycle registered
   output.
3. Cross-check FP decode against RISC-V F spec tables: FCVT.W.S=0x60,
   FCVT.S.W=0x68, FMV.X.W & FCLASS=0x70 (funct3 distinguishes), FMV.W.X=0x78,
   FEQ/FLT/FLE=0x50 with funct3 010/001/000 — note current decoder maps
   0x50 to FSGNJ; the REAL FSGNJ funct7 is **0x10**. Verify against spec and
   fix; add directed TB cases for every FPMATH funct7 legal value and one
   illegal value.
**Acceptance:** rt_fpu_tb extended + green; single multiplier confirmed by
`stat` cell count drop; decode table in TB mirrors the spec table above.

### P1-T5 [OPUS] Structural red flags (BUG-007/008/009)
1. **BUG-008 first** (it can invalidate everything): find why `id_instr` is
   seen as both sync and async. Rule: ALL state uses
   `always @(posedge i_clk or negedge i_rst_n)` with async assert / sync
   deassert handled by a reset synchronizer at the top level (add
   `rtl/core/rt_reset_sync.v`, 2-flop). No register may be written from two
   always blocks.
2. **BUG-007:** for each UNDRIVEN signal in `aegis_rt_top.v`, decide wire-up
   vs documented tie-off. `irq_ack` and `xdrone_valid` look like missing
   core↔top connections — trace the intended path in ARCHITECTURE.md §3 and
   connect. Config bits genuinely reserved get
   `assign x = '0; // reserved, see D-00x`.
3. **BUG-009:** for each SELRANGE site in `rv32c_expander.v`, open the RVC
   spec table for that instruction format (CI/CSS/CIW/CL/CS/CB/CJ), write
   the expected bit mapping as a comment, fix the index, and add a directed
   TB case in a new `tb/core/rv32c_expander_tb.v` covering every RVC opcode
   the expander claims to support + C.ADDI4SPN with nonzero imm + one
   reserved encoding (must set illegal).
**Acceptance:** verilator -Wall shows 0 UNDRIVEN/SELRANGE/SYNCASYNCNET;
new expander TB green; full suite green.

### P1-T6 [SONNET] Style guide amendment
Rewrite the offending rules in `docs/RTL_STYLE_GUIDE.md`:
- DELETE: "No `always @*` … iverilog sensitivity issues" (this rule caused
  BUG-002 masking BUG-001 — cite BUGLOG in the doc).
- ADD: combinational = `always @*` or `assign`, hand sensitivity lists
  forbidden; sequential = the P1-T5 template only; no `/ %` outside
  dedicated sequential units; all literals sized, truncation warnings are
  errors; one driver per signal; every FSM has default + documented safe
  state re-encode on illegal state (add where missing — grep FSMs).
**Acceptance:** doc updated; CLAUDE.md points to it.

### P1-T7 [SONNET] Single-source clock constraints
Create `constraints/clocks.tcl` defining `set RT_CLK_PERIOD 10.0` +
uncertainty 0.3 + io delays; make `syn/*.tcl`, `openroad/*.tcl`,
`openroad/constraints/rt_domain.sdc`, `constraints/aegis.sdc` all source or
match it. Grep-audit: `grep -rn '4\.167\|240' syn/ openroad/ constraints/`
→ empty.
**Acceptance:** that grep is empty; `make synth` (dry) still runs.

### PHASE 1 EXIT GATE
```bash
make sim && make sim_integration                                    # green
verilator --lint-only -Wall -Irtl/security -f rtl/rtl_list.f 2>&1 \
  | grep -cE 'UNDRIVEN|SELRANGE|SYNCASYNCNET|BLKSEQ'                # 0
grep -rn "4\.167\|240 MHz" syn/ openroad/ constraints/ rtl/ | wc -l # 0
iverilog -g2012 -Irtl/security -o /dev/null $(grep -v '^#' rtl/rtl_list.f) \
  2>&1 | grep -c truncated                                          # 0
```

════════════════════════════════════════════════════════════════════════════
## PHASE 2 — Independent verification  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### P2-T1 [OPUS] riscv-arch-test via RISCOF
**Why:** hand-written tests passed while SUB was broken. Only external
suites count as ISA evidence.
**Procedure:**
1. `pip install riscof`; plugins: reference = Sail (preferred) or Spike.
2. Write the DUT plugin `verif/riscof/aegis/`: model YAML (RV32IMC first —
   add F only after P1-T4 lands), linker script matching the P1-T2 map
   (code+data inside 64 KB, tohost symbol), and a runner that compiles each
   test with riscv32 gcc, converts to hex, runs
   `iverilog` on `aegis_rt_top` + a `tb/riscof_harness_tb.v` you create:
   loads hex into scratchpad model, releases reset, watches the tohost
   write, dumps the signature memory range to file.
3. Watchdog: harness kills a test at 2,000,000 cycles → FAIL (log it).
4. Run RV32I, M, C suites. EVERY mismatch → BUGLOG entry → red-first fix.
   Known risk areas: RVC (BUG-009), M (BUG-001 family), misaligned access
   behavior, mtvec/mepc/mcause semantics vs privileged spec.
5. CI: add job `arch-test` (required, on PR) running the I+M+C signature
   comparison; cache the toolchain.
**Acceptance:** RISCOF report: 100% signature match RV32IMC; report HTML
committed under `verif/riscof/reports/` (small) or CI artifact (large);
CI job required-green.
**Common mistakes:** (a) "fixing" a mismatch by editing the test or the
signature range — forbidden; (b) running with SAFETY_MODE undefined while
`make sim` defines it — keep defines identical to production build;
(c) letting the harness memory model differ in size/latency from the real
map — it must load within 64 KB or tests overflow silently.

### P2-T2 [SONNET, orchestrated by OPUS] Lint burn-down to zero
**Procedure:** orchestrator generates the warning inventory
(`verilator --lint-only -Wall ... 2>&1 | sort by file`), spawns one Sonnet
subagent per file with: the file, its warnings, the style guide, and the
rule "change behavior = forbidden; if a fix would change behavior, return
BLOCKED with analysis." Categories:
- UNUSEDSIGNAL: delete if truly dead; if intentionally unused port bits,
  `wire _unused = &{1'b0, sig};` pattern or a scoped waiver with rationale.
- PINCONNECTEMPTY: make explicit `.port()` → `.port(/* unused: reason */)`
  or connect.
- WIDTHEXPAND/TRUNC: explicit `$unsigned`/part-select with a comment, or fix
  the actual width bug (BUG-010 items are real bugs: widen
  `i_scrub_interval` source to 32, `i_csr_addr` — decide 16 vs 32 per
  CSR_SPEC.md and make both sides agree).
- Orchestrator reviews EVERY diff; any diff touching >1 file or changing an
  expression's value is escalated to an [OPUS] mini-review.
Then: remove `|| true` from the CI lint job; lint failures now block.
**Acceptance:** `verilator --lint-only -Wall -f rtl/rtl_list.f -Irtl/security`
exits 0 with 0 warnings; waiver file diff reviewed — every new waiver has a
safety rationale ≥2 sentences; full suite + arch-test green (proves no
behavior change).

### P2-T3 [OPUS] Formal property revival
For each `.sby` under sby/: run, triage into {PASS, harness-broken,
property-false}. Fix harnesses (they reference stale copied src/ — point
them at rtl/ via `[files]` sections). Minimum green set (create missing):
1. `tcls_voter`: ∀ single-input corruption, output equals majority AND
   fault flag rises within 1 cycle.
2. `smu`: from any HIGH-severity fault assertion, safe-state output within
   ≤4 cycles (bounded liveness, k=6).
3. `ecc_secdec_32`: encode→flip any 1 bit→decode == original ∧ corrected
   flag; flip any 2 bits → detected flag (exhaustive over bit positions via
   symbolic index).
4. `memory_mux` (NEW): exactly-one-hot region select ∨ fault, ∀ addresses.
5. `rt_muldiv` (NEW): bounded check 8-bit operand slice vs `/` reference;
   plus `o_done` timing invariant (34 cycles).
6. `no_deadlock` on exception handler: re-enable, must PASS not just cover.
Makefile: `make formal` runs the green set; CI nightly job.
**Acceptance:** `make formal` exits 0; each property file has a header
comment stating WHAT is proven and the bound; sby outputs still gitignored.

### P2-T4 [SONNET] Coverage flow
`make coverage`: verilator `--coverage --coverage-line --coverage-toggle`
build of unit TBs (verilator-compatible ones; keep iverilog as the default
sim), `verilator_coverage --annotate`, emit total % into
`coverage/summary.txt` + CI job summary. Add a ratchet: CI fails if line
coverage drops >0.5% vs the committed `coverage/baseline.txt` (update
baseline only in dedicated `[coverage-baseline]` commits).
**Acceptance:** number published in CI; baseline committed; NO coverage
claims anywhere except generated files.

### PHASE 2 EXIT GATE
RV32IMC arch-test 100% · lint 0 warnings, CI-blocking · `make formal` green
· coverage baseline committed · all of Phase 1 gate still green.

════════════════════════════════════════════════════════════════════════════
## PHASE 3 — Safety verification campaign  [~1–2 weeks, may overlap P4]
════════════════════════════════════════════════════════════════════════════

### P3-T1 [OPUS] Fault-injection framework
**Deliverables:** `scripts/fault_inject.py` + `tb/fi/fi_harness_tb.v` +
`docs/FI_REPORT.md` (generated).
**Design (follow exactly):**
1. Target lists are auto-extracted: a Yosys script dumps all FF names of
   `aegis_rt_tcls_top` (after P3-T3) grouped by hierarchy: pipeline regs,
   regfile, FSM state regs, scratchpad model array, SMU/voter internals.
2. Injection method: iverilog `force`/`release` driven by a generated
   per-run `+fault=<path>:<bit>:<cycle>` plusarg, one fault per run
   (single-fault model first; dual-fault campaign optional later).
3. Workload: fixed firmware loop (FOC iteration + Kalman step + memory
   sweep) with a golden end-state signature.
4. Classification per run: DETECTED_TCLS / DETECTED_ECC / DETECTED_SMU /
   DETECTED_WDT / BENIGN (signature matches, no flag) / **SDC** (signature
   differs, no flag — the bad bucket).
5. Campaign size: ≥10,000 runs, stratified across target groups; fixed RNG
   seed; parallelize with `make -j`.
6. Output: JSON per run → aggregator → diagnostic-coverage table per fault
   class → regenerate `docs/fmeda_report.json` and FI_REPORT.md. SDC rate
   is THE headline number; publish it honestly whatever it is.
**Acceptance:** campaign reproducible from one command
(`make fi CAMPAIGN=full`); report generated; every SDC case gets a BUGLOG
entry with waveform (`TRACE=1` rerun of that exact fault) and a disposition
(fix / accept-with-rationale).

### P3-T2 [SONNET] WCET verification of every contract row
For each row (interrupt entry, shadow swap, context switch, TCLS
quarantine, SMU→safe-state, power transition): a directed TB or formal
cover measuring the count under adversarial timing — interrupt asserted
the cycle a 34-cycle divide starts, during Xdrone kalman, during an ECC
scrub collision, during an FPU op. `scripts/wcet_analyzer.py` parses logs →
generates `docs/TIMING_CONTRACTS.md`. README WCET table becomes a pointer
to that generated file.
**Acceptance:** generated table covers 100% of rows; any contract miss is a
BUGLOG entry and either an RTL fix or a documented contract change (both
via DECISIONS.md).

### P3-T3 [OPUS] TCLS at the top level
Currently one core is instantiated. Create `rtl/aegis_rt_tcls_top.v`:
3× `aegis_rt_core` (identical, no diversity — document), inputs fanned out,
outputs through `tcls_voter` per bus group (sp_addr/wdata/we/re, irq_vector,
xdrone), `tcls_mismatch_counter` feeding SMU fault 0x01/0x02, quarantine =
majority-2 continue + flag. Clock/reset common (CDC-free by construction —
state this in the header). Update `rtl/rtl_list.f`, add
`tb/integration/tcls_top_tb.v` (normal op + forced single-core corruption →
outputs unaffected + fault flagged) and re-point the P3-T1 campaign here.
Record post-synth area of tcls_top vs single core in DECISIONS.md (expect
≈3.2×).
**Acceptance:** tcls_top TB green; FI campaign runs against tcls_top;
single-core top retained as the area-constrained config.

### P3-T4 [SONNET] Traceability gate in CI
`scripts/cert_traceability.py` must: scan rtl/ for `@CERT` tags, scan
docs/VERIFICATION_PLAN.md requirement IDs, cross-link to tb/+sby/ evidence,
emit `docs/TRACE_MATRIX.md`, exit non-zero on any orphan (RTL without
requirement, requirement without test). Add CI job `trace` (required).
Fix all orphans it finds (that IS the task — expect several).
**Acceptance:** `python3 scripts/cert_traceability.py --check` exits 0 in CI.

### PHASE 3 EXIT GATE
FI report published with SDC rate + dispositions · TIMING_CONTRACTS.md
generated, 100% rows · tcls_top verified · trace job green.

════════════════════════════════════════════════════════════════════════════
## PHASE 4 — Physical memory reality  [~1 week, overlaps P3]
════════════════════════════════════════════════════════════════════════════

### P4-T1 [OPUS] OpenRAM/sky130 macro integration
1. Vendor macros into `third_party/sky130_sram_macros/` (LEF/GDS/lib/verilog
   behavioral) — pin the commit hash in a README there.
2. 64 KB plan with `sky130_sram_1kbyte_1rw1r_32x256_8`-class macros:
   64× 1KB (grouped 4 banks × 16) OR generate 2KB/4KB OpenRAM configs to cut
   macro count — decide by floorplan trial in P6, start with 1KB known-good.
3. **ECC width:** SECDED(39,32) needs 39 bits/word. Mandated layout: data in
   32-bit macros + a parallel 8-bit-wide macro column for the 7 ECC bits
   (bit 8 unused, tied) — same address, same enables, single logical port.
   Wrap in `scratchpad_bank_phys.v`; behavioral `scratchpad_bank.v` remains
   for sim under `ifdef SIMULATION` with IDENTICAL 1-cycle registered-read
   timing (write a tiny equivalence TB driving both models with the same
   random stimulus and comparing).
4. Synthesis flow: macros are blackboxes (`read_liberty -lib` their .lib);
   verify `make synth PDK=sky130` elaborates with no unresolved modules.
**Acceptance:** equivalence TB green; synth netlist instantiates macro cells;
FI campaign still green (it uses the behavioral model — note this limitation
in FI_REPORT.md).

### P4-T2 [SONNET] 2-cycle read fallback config
Add parameter `SP_READ_LATENCY` (1|2) through scratchpad_ctrl → core stall
logic. Reason: silicon reports show these macros can miss their hardened
frequency. Both configs must pass the full suite + arch-test; WCET contracts
re-measured for latency=2 and recorded as a second column.
**Acceptance:** CI matrix runs both configs on the smoke + arch-test subset.

### PHASE 4 EXIT GATE
Both latency configs green everywhere · macros vendored+pinned ·
equivalence TB green · synth elaborates with macros.

════════════════════════════════════════════════════════════════════════════
## PHASE 5 — Synthesis & timing closure  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### P5-T0 [SONNET] Vendor the PDK timing views
`third_party/sky130hd/`: tt_025C_1v80, ss_100C_1v60, ff_n40C_1v95 .lib files
(from OpenROAD-flow-scripts platform dir), LEF/tech-LEF, pinned by source
URL + hash in a README. All flows reference ONLY this vendored copy.

### P5-T1 [OPUS] Honest synthesis + STA baseline
`make synth PDK=sky130` → Yosys mapped netlist → **OpenSTA** (inside
OpenROAD: `read_liberty` all corners, `read_verilog` netlist, `link`,
`read_sdc constraints/`, `report_checks -path_delay max -corner tt`).
Commit to `syn/reports/summary.md`: cell count, area (µm²), WNS/TNS at
TT and SS, top-5 critical paths (start/end/slack). CI job posts WNS into
the run summary. Yosys `abc -D` alone is NOT a timing signoff — STA or it
didn't happen.
**Acceptance:** summary.md exists with real numbers; README links to it
(numbers appear ONLY via the link).

### P5-T2 [OPUS] Critical-path closure loop
Iterate to WNS ≥ +0.3 ns at TT/10 ns (stretch 8.5 ns):
likely offenders in order — decoder→regfile→ALU→branch resolve in one EX
cycle (consider registering branch target), Xdrone qmul input muxing
(register operands), CSR read mux, ECC decode in the load path (check
whether decode fits with SP_READ_LATENCY=1; if not, latency=2 becomes
default — DECISIONS.md). EVERY accepted restructure: full suite +
arch-test + FI smoke re-run before merge. No path may be "fixed" with an
undocumented false_path.
**Acceptance:** WNS ≥ +0.3 ns TT documented in summary.md; SS corner
reported (target ≥ 0, else note derate plan); suites green.

### P5-T3 [SONNET] Multicycle/false-path constraint file
`constraints/exceptions.sdc`: one entry per exception, each with a comment
naming the RTL structure guaranteeing it (e.g., divider iteration register
loop is N-cycle by FSM construction → `set_multicycle_path`). Reviewed by
[OPUS] before merge. Blanket `set_false_path -from [all_inputs]` style
lines are forbidden.

### P5-T4 [SONNET] Gate-level simulation (the BUG-001 catcher)
`make gls`: functional (zero-delay, `-DFUNCTIONAL -DUNIT_DELAY=#1` per
sky130 verilog models) iverilog run of the mapped netlist + sky130 cell
models on: smoke TB + 20-test arch-test subset (I: add/sub/logic; M: mul/div;
C: subset). Nightly CI job.
**Acceptance:** GLS green; a deliberately re-introduced BUG-001 (on a
scratch branch, reverted) is demonstrated to FAIL GLS — commit that
demonstration log as `docs/evidence/gls_catches_bug001.log`.

### PHASE 5 EXIT GATE
STA WNS ≥ +0.3 ns @ TT 10 ns with committed reports · exceptions.sdc fully
justified · GLS nightly green · honest area/fmax table live in README via
generated link.

════════════════════════════════════════════════════════════════════════════
## PHASE 6 — P&R, DFT, signoff, tapeout  [~2–4 weeks]
════════════════════════════════════════════════════════════════════════════

### P6-T1 [OPUS] Vehicle decision (human sign-off REQUIRED)
Write a one-page comparison in DECISIONS.md: (a) Tiny Tapeout tile — cheap,
tiny; single core + SMU + UART demo only, no SRAM macros; (b) ChipIgnite-
class ~10 mm² — full tcls_top + 64 KB ECC RAM + UART/SPI/PWM/GPIO; (c) defer
silicon, FPGA-only (P7-T1) + SCL-180 pitch. Include cost, calendar, and
what each proves to a customer. **BLOCKED until the human picks.** All P6
tasks below assume (b); scale down per decision.

### P6-T2 [OPUS] OpenROAD flow bring-up
Base on existing `openroad/*.tcl` but treat them as untested. Order:
floorplan (SRAM macros placed first, pins toward core logic, halo/blockage
set) → PDN (check IR after) → global/detail place → CTS (target skew
<100 ps) → route → filler. Gate each stage on its report: no overflow in
GRT, hold fixed at SS (`repair_timing -hold`), setup preserved. Keep per-
stage ODBs as CI artifacts (gitignored locally).
**Acceptance:** routed DB, zero DRC from the router, post-route STA meets
P5 targets with routed parasitics (SPEF-based).

### P6-T3 [OPUS] DFT decision & the scan warning
`rt_dft_scan.v` exists and TBs print `[DFT WARNING] Scan enable active`.
Either: (a) real scan insertion through the flow + ATPG-lite plan, or
(b) descope scan for the demo chip, tie scan_en low through a documented
fuse/strap, and DELETE the warning path. Decide (DECISIONS.md), implement,
and make the TB output clean either way — a warning nobody acts on is worse
than none.

### P6-T4 [SONNET] Chip wrapper, pads, boot
Harness template per vehicle (Caravel-style or TT). Pin map →
`docs/PINOUT.md` (generated from a YAML source of truth). Boot path: decide
ROM stub vs UART loader vs SPI-flash XIP-copy (recommend UART loader into
TCM for demo silicon — simplest); firmware `boot.S` adjusted; boot TB
updated to the chosen path (this finally retires the BUG-013 firmware.hex
dependency: the loader TB generates its own image).

### P6-T5 [OPUS] Signoff
Magic DRC + KLayout DRC (both, on final GDS) · netgen LVS vs final netlist
· antenna check · STA all three corners with SPEF · GLS smoke on the final
netlist (SDF if runtime allows, else functional + documented gap). Every
report archived under a `v1.0-tapeout-candidate` git tag as CI release
artifacts. ANY waived violation: DECISIONS.md entry with screenshot/report
excerpt.

### P6-T6 [SONNET] Tapeout package + release
GDS, DEF, gate netlist, all signoff reports, TRACE_MATRIX.md, FI_REPORT.md,
TIMING_CONTRACTS.md, fmeda_report.json, RELEASE_NOTES.md in which EVERY
claim is a link to evidence. Tag `v1.0`. Submit per vehicle instructions.

### PHASE 6 EXIT GATE
DRC clean (both tools) · LVS clean · STA clean all corners w/ SPEF · GLS
green · tagged release with complete evidence package · shuttle submitted.

════════════════════════════════════════════════════════════════════════════
## PHASE 7 — Post-tapeout / market track  [parallel from P3]
════════════════════════════════════════════════════════════════════════════

- **P7-T1 [SONNET]** FPGA demo (Artix/Kintex board): tcls_top at 50 MHz,
  FOC/EKF loop, physical switch injecting faults, LEDs/UART showing
  detection — the iDEX/ADITI pitch artifact. Separate `fpga/` dir, own
  constraints, does NOT pollute the ASIC rtl_list.
- **P7-T2 [SONNET]** `docs/SCL180_PORTING.md`: cell-library mapping table
  (sky130hd → SCL 180 equivalents), SRAM strategy on SCL, expected timing
  derate (~1.5–2× period), what changes in constraints/ and syn/ — the
  ISRO/DRDO route document.
- **P7-T3 [SONNET]** `docs/SAFETY_MANUAL.md` skeleton: assumptions of use,
  fault model, diagnostic-coverage table (imported from FI_REPORT), safe-
  state definition, integration requirements (clock quality, reset, brownout),
  known limitations (honestly: FI ran on behavioral SRAM; no scan ATPG; etc.).

---

# §D — STANDING PROHIBITIONS (all phases, all agents, no exceptions)

1. Never modify TAPEOUT_PLAN.md.
2. Never reintroduce hand-written sensitivity lists (`always @(a or b)`).
3. Never use `/` or `%` in synthesizable RTL outside a dedicated,
   fixed-latency sequential unit.
4. Never commit generated artifacts: sby run dirs, sim logs, VCD/FST,
   coverage DBs, synth netlists (exception: tagged release artifacts),
   OpenROAD ODBs.
5. Never write a performance/safety/coverage number without a linked,
   checked-in evidence file.
6. Never claim ASIL-x / DAL-x / SIL-x. Only "designed to <standard>
   methodology" until an external assessor signs.
7. Never "fix" a failing external test (riscv-arch-test) by editing the
   test, the signature range, or the reference model.
8. Never merge with red CI. Never start work on a red baseline (§A.1).
9. Never rewrite git history.
10. Never let a subagent commit its own diff — orchestrator reviews first.
11. Never resolve ISA ambiguity from existing AEGIS behavior — the RISC-V
    spec is the authority (§A.9).
12. Never add an SDC exception (false path / multicycle) without a comment
    naming the RTL structure that justifies it and an [OPUS] review.
