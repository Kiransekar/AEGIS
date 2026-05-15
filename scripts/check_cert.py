#!/usr/bin/env python3
"""AEGIS-RV Certification Check — Phase 4 Verification Gate
Validates TCL bundle, FMEDA report, and traceability matrix.
"""

import argparse
import json
import sys


REQUIRED_TCL_KEYS = ["toolchain_info", "tcl_assessment"]
REQUIRED_FMEDA_KEYS = ["fmeda"]
REQUIRED_TRACE_KEYS = ["requirements", "traceability"]

DC_TARGETS = {
    "ASIL-D": 0.99,
    "ASIL-C": 0.97,
    "ASIL-B": 0.90,
}


def validate_json_file(path, required_keys):
    """Load and validate a JSON file has required top-level keys."""
    try:
        with open(path, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"[FAIL] File not found: {path}")
        return None
    except json.JSONDecodeError as e:
        print(f"[FAIL] Invalid JSON in {path}: {e}")
        return None

    missing = [k for k in required_keys if k not in data]
    if missing:
        print(f"[FAIL] Missing keys in {path}: {missing}")
        return None

    return data


def check_tcl(data):
    """Validate TCL assessment."""
    assessment = data.get("tcl_assessment", {})
    criteria = assessment.get("criteria", [])
    all_pass = all(c.get("pass", False) for c in criteria)
    if all_pass:
        print(f"[PASS] TCL: All criteria met (Level {assessment.get('tcl_level', '?')})")
    else:
        failed = [c for c in criteria if not c.get("pass", False)]
        print(f"[WARN] TCL: {len(failed)} criteria not met")
        for c in failed:
            print(f"  - {c.get('id', '?')}: {c.get('description', '?')}")
    return all_pass


def check_fmeda(data):
    """Validate FMEDA report."""
    fmeda = data.get("fmeda", {})
    dc = fmeda.get("overall_diagnostic_coverage", 0.0)
    target = DC_TARGETS.get(fmeda.get("asil_target", "ASIL-D"), 0.99)
    met = fmeda.get("dc_target_met", False)

    if met and dc >= target:
        print(f"[PASS] FMEDA: DC = {dc:.2%} >= {target:.0%}")
    else:
        print(f"[FAIL] FMEDA: DC = {dc:.2%} < {target:.0%}")
    return met


def check_traceability(data):
    """Validate traceability matrix."""
    trace = data.get("traceability", [])
    reqs = data.get("requirements", [])

    if not trace:
        print("[FAIL] Traceability: No trace entries found")
        return False

    # Check bidirectional coverage for @SAFETY lines
    safety_traces = [t for t in trace if t.get("tag") == "@SAFETY"]
    total_safety = len(safety_traces)
    covered = sum(1 for t in safety_traces if t.get("rtl_ref") and t.get("test_ref"))

    coverage_pct = (covered / total_safety * 100) if total_safety > 0 else 0
    if coverage_pct >= 100.0:
        print(f"[PASS] Traceability: {covered}/{total_safety} @SAFETY lines covered (100%)")
    else:
        print(f"[FAIL] Traceability: {covered}/{total_safety} @SAFETY lines covered ({coverage_pct:.1f}%)")

    return coverage_pct >= 100.0


def main():
    parser = argparse.ArgumentParser(description='AEGIS-RV Certification Checker')
    parser.add_argument('--bundle', required=True, help='Path to TCL bundle JSON')
    parser.add_argument('--fmeda', required=True, help='Path to FMEDA report JSON')
    parser.add_argument('--trace', required=True, help='Path to traceability JSON')
    args = parser.parse_args()

    all_pass = True

    # Check TCL
    tcl_data = validate_json_file(args.bundle, REQUIRED_TCL_KEYS)
    if tcl_data:
        if not check_tcl(tcl_data):
            all_pass = False
    else:
        all_pass = False

    # Check FMEDA
    fmeda_data = validate_json_file(args.fmeda, REQUIRED_FMEDA_KEYS)
    if fmeda_data:
        if not check_fmeda(fmeda_data):
            all_pass = False
    else:
        all_pass = False

    # Check Traceability
    trace_data = validate_json_file(args.trace, REQUIRED_TRACE_KEYS)
    if trace_data:
        if not check_traceability(trace_data):
            all_pass = False
    else:
        all_pass = False

    if all_pass:
        print("PASS: Phase 4")
        sys.exit(0)
    else:
        print("FAIL: Phase 4")
        sys.exit(1)


if __name__ == '__main__':
    main()
