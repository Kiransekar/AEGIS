<!-- ============================================================================
  AEGIS RISK-CLOSURE ROADMAP — MASTER PLAN v1.0
  ============================================================================
  STATUS: READ-ONLY. AGENTS MUST NOT MODIFY THIS FILE. NO EXCEPTIONS.

  Third plan in the set. Prerequisites: TAPEOUT_PLAN.md phases P0–P5 DONE
  (P6 silicon may run in parallel) and TOOLCHAIN_PLAN.md phases S0–S9 DONE.
  Inherits TAPEOUT_PLAN.md §A AGENT OPERATING PROTOCOL verbatim.
  Risk items use the R-xxx prefix in docs/BUGLOG.md-style tracking, kept in
  docs/RISK_REGISTER.md (created in R0-T1).

  IMPORTANT HONESTY CLAUSE: unlike the previous two plans, several risks
  here are only PARTIALLY closeable by engineering work. Tasks are tagged:
    [OPUS] / [SONNET]  — agent-closeable (artifacts, evidence, automation)
    [HUMAN]            — requires the founder: meetings, signatures, money.
                         Agents PREPARE these to the last inch; they do not
                         EXECUTE them. An agent must never impersonate the
                         founder in outreach, applications, or negotiations.
  A risk is never marked CLOSED by an agent alone — the human confirms in
  docs/RISK_REGISTER.md.

  Repo owner: chmod 444 RISK_PLAN.md ; git update-index --skip-worktree
  RISK_PLAN.md ; add the immutability line to CLAUDE.md.
  ============================================================================ -->

# AEGIS — Risk-Closure Plan v1.0

**Premise (from the 2026-07 strategy review):** 100 MHz @ 130nm is not a
survival risk — it matches the deployed norm of the target market (RAD750
class ≈ 110–200 MHz; ISRO IRIS/Vikram on SCL 180nm; flight-control loops at
1–50 kHz need determinism, not throughput). The real risks are trust,
positioning, incumbent gravity, bus factor, and market entry. This plan
closes what is closeable and shrinks what is not.

---

# §R — THE RISK REGISTER (authoritative list)

| ID | Risk | Severity | Closeable by agents | Residual after this plan |
|----|------|----------|--------------------:|--------------------------|
| R-01 | **Trust deficit** — no third party has reason to believe the core works | CRITICAL | ~70% (evidence machine) | Time-in-market; only shipments close the rest |
| R-02 | **"Good-enough COTS" attack** — system-level redundancy on cheap chips undercuts custom rad-tolerant silicon | HIGH | ~60% (positioning + proof of the defensible ground) | Buyer rationality varies by program |
| R-03 | **Incumbent gravity** — NOEL-V/SHAKTI are free; competing on RTL loses to zero-price | HIGH | ~80% (productize evidence, not RTL) | Incumbent relationships |
| R-04 | **Bus factor = 1** — programs won't design in a single-person vendor | CRITICAL | ~40% (make the project survivable without its author) | Team/partner formation is human work |
| R-05 | **Market entry** — no anchor customer or grant; demos don't schedule themselves | CRITICAL | ~50% (application & pitch packages, demo logistics) | The founder must walk into rooms |
| R-06 | **No flight heritage** — "has it flown?" is the first question in aerospace | HIGH | ~50% (heritage ladder artifacts) | Physics and launch calendars |
| R-07 | **Certification path unpriced** — customers will ask "what does assessment cost/when" | MEDIUM | ~70% (gap analysis + assessor-ready package) | Assessor fees & timelines |
| R-08 | **IP/licensing ambiguity** — Apache core + "proprietary Xdrone" is currently a sentence, not a structure | MEDIUM | ~90% (documents) | Legal counsel review |
| R-09 | **Supply-chain single-source** — one fab story = one point of failure | MEDIUM | ~80% (SCL second-source proven) | Fab business relationships |
| R-10 | **Support credibility** — IP without support SLAs is a hobby to procurement | MEDIUM | ~85% (infra + docs) | Actually answering the phone |

---

# §C — PHASES

Order: R0 → R1 → {R2, R3 parallel} → R4 → R5 → {R6, R7 ongoing}. R8/R9/R10
tasks slot in parallel wherever capacity exists.

════════════════════════════════════════════════════════════════════════════
## PHASE R0 — Risk instrumentation  [SONNET, ~2 days]
════════════════════════════════════════════════════════════════════════════

### R0-T1 [SONNET] Create `docs/RISK_REGISTER.md`
Transcribe §R verbatim, add columns: Owner, Status (OPEN / MITIGATING /
HUMAN-GATE / CLOSED-confirmed-by-human), Evidence links, Review date
(monthly). Wire a CI cron job that fails a scheduled workflow if the
register's review date is >45 days stale — the register must not rot.

### R0-T2 [SONNET] Define the "trust ledger"
`docs/TRUST_LEDGER.md`: a single append-only page listing every externally
verifiable claim AEGIS can make, each with its evidence link — arch-test
badge, FI diagnostic-coverage %, formal proof list, GLS logs, silicon
status, flight hours (starts at 0 — write the 0 honestly). This page IS
the sales asset; every phase below appends to it. Rule: nothing enters
without a link; nothing links to a private artifact.

════════════════════════════════════════════════════════════════════════════
## PHASE R1 — Close R-01: Trust deficit  [~2–3 weeks]
════════════════════════════════════════════════════════════════════════════

The two prior plans built the evidence. This phase makes it *legible to a
stranger with buying authority and 30 minutes*.

### R1-T1 [OPUS] The Evidence Book
`docs/evidence_book/` compiled to a single PDF (via the docs toolchain):
1-page core datasheet (honest numbers only, auto-imported from generated
files), verification summary (arch-test, formal, coverage), FI campaign
results with the SDC rate and dispositions, WCET contract table with
measurement method, safety manual, MISRA deviations log, trace-matrix
statistics, known-limitations section (this section is a trust WEAPON —
incumbents hide theirs). CI rebuilds it from source artifacts; hand-edited
numbers are a build failure.
**Acceptance:** `make evidence_book` produces the PDF from evidence only;
an [OPUS] adversarial-review pass reads it as a skeptical DER/assessor and
files gaps as tasks.

### R1-T2 [SONNET] Reproducibility-as-proof
"Verify it yourself in 30 minutes" — a `verify/README.md` + container that
lets ANY third party re-run: lint, unit suite, arch-test subset, one formal
proof, one FI batch, and diff the outputs against committed baselines. No
other small vendor offers this; open PDK + open flow makes it possible.
**Acceptance:** a fresh machine + the README reproduces the badge results;
CI runs the same script weekly so it never bit-rots.

### R1-T3 [OPUS] Third-party validation targets (prep) + [HUMAN] execution
Prepare submission packages for external eyeballs that convert directly to
credibility: (a) a technical paper for a RISC-V Summit / VLSI-design venue
(India: VLSID conference) on the TCLS+ECC+deterministic-WCET architecture
with the FI numbers; (b) an entry to relevant open-silicon showcases;
(c) an application to the RISC-V International technical community
(working-group participation is citable). Agents draft; the human submits
and presents.
**Human-gate:** submissions sent. **Residual:** acceptance is not ours to
decide.

════════════════════════════════════════════════════════════════════════════
## PHASE R2 — Close R-02: the COTS attack  [~1–2 weeks]
════════════════════════════════════════════════════════════════════════════

### R2-T1 [OPUS] Write the defensible-ground doctrine
`docs/positioning/WHEN_AEGIS.md` — an honest decision tree a customer's
engineer could follow: when system-level COTS redundancy is the right call
(short-lived LEO, non-actuator payloads, reboot-tolerant) and when it is
not (actuator-level control mid-maneuver, silent-data-corruption-as-
mission-kill, sovereignty-mandated supply chains, WCET-audited loops).
Honesty here is the sales strategy: conceding COTS ground we can't win
buys credibility on the ground we can.

### R2-T2 [OPUS] The SDC demonstrator
The killer demo against "just reboot it": a side-by-side run (Verilator or
FPGA) of the EKF app on (a) single unprotected core and (b) TCLS AEGIS,
under identical injected upsets — showing (a) producing *plausible but
wrong* attitude outputs with no error flag (silent corruption, the failure
reboots don't catch) while (b) flags and masks. Scripted, reproducible,
one command, screen-recordable.
**Acceptance:** `make demo-sdc` runs end-to-end; recording script produces
the asset for R5 pitches.

### R2-T3 [SONNET] Competitive fact base
`docs/positioning/LANDSCAPE.md`: sourced, dated, neutral-tone table of the
actual alternatives (Gaisler NOEL-V/LEON, Fraunhofer EMSA5-FS, SHAKTI/
VEGA/IRIS, Microchip SAMRH-class parts, COTS+lockstep MCUs) — what each
certifies, costs (where public), and where AEGIS genuinely differs
(open-flow auditability, evidence reproducibility, deterministic ISA-level
WCET, India-domestic path). Rule: every row cited; no editorializing —
the reader must trust the table more than a brochure.

════════════════════════════════════════════════════════════════════════════
## PHASE R3 — Close R-03: incumbent gravity  [~2 weeks]
════════════════════════════════════════════════════════════════════════════

Free cores win on price of RTL. So the product must not be RTL.

### R3-T1 [OPUS] Productize the evidence package
Define three tiers in `docs/business/OFFERING.md`:
1. **Open tier** (free): core RTL, Apache-2.0, evidence book PDF — the
   funnel and the credibility engine. Giving the RTL away *attacks* the
   incumbents' RTL pricing while making our paid tier the only thing worth
   paying anyone for.
2. **Evidence tier** (paid): the full reproducible verification
   environment, FI framework with customer-workload injection, safety
   manual with assumptions-of-use tailoring, trace matrix in customer
   format, integration support hours.
3. **Program tier** (paid, per-design): Xdrone license, customization,
   SCL/SkyWater tapeout support, assessor-liaison support.
Agents draft the tier docs, license texts (R8), and the delivery checklists
per tier so a sale is executable, not improvised.

### R3-T2 [SONNET] Benchmark harness vs the free alternatives
FPGA-runnable, scripted comparison: AEGIS vs NOEL-V (and SHAKTI E-class if
buildable) on interrupt-latency distribution, jitter under load, control-
loop WCET — the axes where AEGIS's determinism should win and which
brochures never publish. Publish methodology + raw data; if we lose an
axis, publish that too (see R1 honesty doctrine) and file an engineering
task.
**Acceptance:** `bench/README.md` reproduces every published number.

════════════════════════════════════════════════════════════════════════════
## PHASE R4 — Shrink R-04: bus factor  [~2 weeks + ongoing]
════════════════════════════════════════════════════════════════════════════

Agents cannot hire co-founders. They CAN make the project survivable
without its author and make the author's case to institutions.

### R4-T1 [SONNET] The successor test
Adversarial audit: could a competent engineer with zero context take the
repo to a new tapeout? An [OPUS] agent role-plays that engineer using ONLY
committed docs, files every stumble as a documentation bug, and Sonnet
agents fix them. Targets: architecture rationale docs (WHY, not just what),
every script has --help + a doc page, the three plans' decision logs
complete, onboarding path `docs/START_HERE.md` tested end-to-end in a
clean container.
**Acceptance:** the role-play run completes P-cycle tasks (one RTL fix,
one firmware feature, one synth run) with zero questions requiring the
author.

### R4-T2 [OPUS] Institutional anchoring dossiers + [HUMAN] engagement
Prepared, personalized technical briefs (not spam — one each, deep) for
the 5 highest-leverage institutional partners: the IIT-M SHAKTI group
(architecture-level collaboration pitch: AEGIS safety layer on SHAKTI
ecosystem), C-DAC VEGA team, one DRDO lab (CAIR or DARE — flight-computer
angle), ISRO IISU (the IRIS follow-on angle: lockstep + evidence), and one
Tier-1 drone OEM engineering head. Each dossier: their published work,
the specific technical fit, a proposed first joint milestone small enough
to say yes to.
**Human-gate:** meetings. Agents keep dossiers current; they never send.

### R4-T3 [SONNET] Continuity mechanics
Boring but real closures: LICENSE/copyright hygiene so the project is
fork-survivable, release artifacts mirrored (Zenodo DOI per release —
also a citability win), CI runnable by anyone (no personal-account
secrets), maintainer documentation, and a `GOVERNANCE.md` stating what
happens to the open tier if the company stops.

════════════════════════════════════════════════════════════════════════════
## PHASE R5 — Close R-05: market entry engine  [~2–3 weeks, then ongoing]
════════════════════════════════════════════════════════════════════════════

### R5-T1 [OPUS] Grant application package (iDEX / ADITI / TDF)
Everything except the signature: problem statement mapped to current
open challenges (agents monitor the iDEX challenge list and flag matches),
technical volume auto-assembled from the Evidence Book, milestone plan
derived from the remaining TAPEOUT phases, budget template, compliance
checklist per scheme's rules. Kept perpetually current so any opening can
be answered inside a week.
**Human-gate:** registration, submission, pitch day.

### R5-T2 [SONNET] The pitch stack
From the R2-T2 recording and Evidence Book: a 10-slide technical pitch
(engineer audience), a 6-slide program pitch (procurement audience), a
2-page leave-behind, and a demo-day runbook (hardware checklist, failure
recovery script — demos that die on stage create anti-trust). All
regenerate from source data; numbers can never drift from evidence.

### R5-T3 [SONNET] Pilot-program kit
What a first customer actually signs up for: `docs/business/PILOT.md` —
90-day evaluation structure, what we provide (FPGA board image, SDK,
support SLA), what they provide (workload, feedback), success criteria,
and the conversion path to the Program tier. A defined pilot converts a
vague "interesting, stay in touch" into a schedulable decision.

════════════════════════════════════════════════════════════════════════════
## PHASE R6 — Shrink R-06: flight heritage ladder  [ongoing, months]
════════════════════════════════════════════════════════════════════════════

Heritage cannot be manufactured, but the ladder can be climbed rung by
cheap rung, and every rung is citable in the trust ledger.

- **R6-T1 [SONNET] Rung 0 — soak evidence.** Automated 30-day continuous
  FPGA soak: EKF+FOC under periodic fault injection, telemetry logged,
  uptime/fault-response stats auto-appended to the trust ledger weekly.
- **R6-T2 [OPUS] Rung 1 — environmental hours.** Prep packages for cheap
  environmental exposure: thermal-cycling rig plan (bench-grade), and a
  high-altitude balloon flight kit (AEGIS FPGA board + logger; balloon
  flights are near-free heritage: radiation flux, −60 °C, real telemetry).
  Agents design the payload firmware, logging format, and post-flight
  analysis scripts. **[HUMAN]**: fly it (university ballooning groups in
  TN/Karnataka run these routinely).
- **R6-T3 [OPUS] Rung 2 — drone flight hours.** Flight-hour logbook
  format + onboard black-box firmware so that the moment any pilot/OEM
  partner flies AEGIS-in-the-loop (even shadow-mode: computing but not
  actuating — design this mode explicitly, it slashes partner risk),
  every hour is captured, signed, and ledger-appended.
- **R6-T4 [HUMAN] Rung 3 — orbital rideshare.** When silicon exists:
  cubesat payload slot (Indian student sats, PSLV PoEM platform is the
  natural target). Agents maintain the payload ICD and readiness package;
  humans buy the ride.

════════════════════════════════════════════════════════════════════════════
## PHASE R7 — Close R-07/R-08/R-09/R-10: the professionalization batch
════════════════════════════════════════════════════════════════════════════

- **R7-T1 [OPUS] (R-07) Certification gap analysis.** A clause-by-clause
  self-assessment against ISO 26262-5/-6 and DO-254 objectives: satisfied
  (link evidence) / partially / gap (task or cost note). Output
  `docs/CERT_GAP_ANALYSIS.md` — walking into an assessor meeting with this
  document converts an unpriceable risk into a quotable project.
  **[HUMAN]**: get one exploratory quote from TÜV/exida-class assessor.
- **R7-T2 [SONNET] (R-08) IP structure drafts.** Clean LICENSE split
  (Apache-2.0 core with explicit file manifest; Xdrone proprietary license
  text with evaluation clause; contributor agreement; trademark note on
  the AEGIS name — check for collisions and file the finding).
  **[HUMAN]**: lawyer review before any paid deal.
- **R7-T3 [OPUS] (R-09) Second-source proof.** Execute the SCL-180
  porting study from TOOLCHAIN/TAPEOUT plans to a synthesized-and-STA'd
  netlist on a 180nm-representative library (IHP SG13 or educational 180nm
  kit as public proxy if SCL PDK access is gated) — turning "portable in
  principle" into a report with numbers. Supply-chain slide writes itself.
- **R7-T4 [SONNET] (R-10) Support credibility infra.** Issue templates
  with response-target labels, a public roadmap page, versioned errata
  process (`docs/ERRATA.md` — professional vendors publish errata;
  hobbyists hide bugs; our audit trail becomes marketing), security/bug
  contact, and a documented support SLA menu per offering tier.

---

# §D — STANDING RULES FOR THIS PLAN

1. Never modify RISK_PLAN.md, TAPEOUT_PLAN.md, or TOOLCHAIN_PLAN.md.
2. Never mark a risk CLOSED without human confirmation in RISK_REGISTER.md.
3. Never let an agent send outreach, submit applications, sign, or
   impersonate the founder — prepare to the last inch, then HUMAN-GATE.
4. Every externally visible number flows from a committed evidence
   artifact; the trust ledger is append-only and fully linked.
5. Publish losses too: a benchmark we lose or a gap we have goes in the
   document with a task ID, not in a drawer. Honesty is the moat no
   incumbent can cheaply copy.
6. Demos must be reproducible by one command and rehearsed by runbook;
   a demo that fails in front of a buyer sets R-01 back months.
7. The register is reviewed monthly; a stale register is a CI failure.
