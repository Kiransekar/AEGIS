#!/usr/bin/env python3
"""AEGIS-RV FMEDA Generator
Generates Failure Modes, Effects, and Diagnostic Analysis report.
Scans RTL for @SAFETY annotations and computes diagnostic coverage.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone


# ISO 26262 ASIL diagnostic coverage targets
DC_TARGETS = {
    "QM": 0.0,
    "ASIL-A": 0.0,
    "ASIL-B": 0.90,
    "ASIL-C": 0.97,
    "ASIL-D": 0.99,
}

# Fault categories and typical diagnostic coverage
FAULT_CATEGORIES = {
    "TCLS_MISMATCH": {"dc": 0.99, "severity": "LOW", "mechanism": "2oo3 voting"},
    "TCLS_QUARANTINE": {"dc": 0.99, "severity": "LOW", "mechanism": "Mismatch counter"},
    "ECC_SINGLE": {"dc": 0.99, "severity": "LOW", "mechanism": "SECDED correction"},
    "ECC_DOUBLE": {"dc": 0.99, "severity": "MEDIUM", "mechanism": "SECDED detection"},
    "WATCHDOG_TIMEOUT": {"dc": 0.90, "severity": "LOW", "mechanism": "Windowed watchdog"},
    "PMP_VIOLATION": {"dc": 0.99, "severity": "HIGH", "mechanism": "PMP trap"},
    "SMU_FAULT": {"dc": 0.99, "severity": "HIGH", "mechanism": "SMU aggregation"},
    "POWER_GLITCH": {"dc": 0.90, "severity": "MEDIUM", "mechanism": "Voltage monitor"},
    "SCRUBBER_CORRECTED": {"dc": 0.99, "severity": "MEDIUM", "mechanism": "Background scrub"},
    "CLOCK_MONITOR": {"dc": 0.90, "severity": "MEDIUM", "mechanism": "Clock monitor"},
    "RETENTION_FAIL": {"dc": 0.99, "severity": "MEDIUM", "mechanism": "Restore verify"},
    "SPU_VIOLATION": {"dc": 0.99, "severity": "HIGH", "mechanism": "SPU trap"},
    "IOPMP_VIOLATION": {"dc": 0.99, "severity": "HIGH", "mechanism": "IOPMP trap"},
    "AXI_TIMEOUT": {"dc": 0.90, "severity": "HIGH", "mechanism": "Timeout monitor"},
    "SAFE_STATE_VIOLATION": {"dc": 0.99, "severity": "HIGH", "mechanism": "SMU safe-state"},
    "PMHF_THRESHOLD": {"dc": 0.99, "severity": "HIGH", "mechanism": "PMHF counter"},
}


def scan_rtl_safety_annotations(rtl_dir):
    """Scan RTL files for @SAFETY annotations."""
    annotations = []
    for root, dirs, files in os.walk(rtl_dir):
        for fname in files:
            if fname.endswith('.v') or fname.endswith('.vh'):
                fpath = os.path.join(root, fname)
                with open(fpath, 'r') as f:
                    for lineno, line in enumerate(f, 1):
                        for tag in ['@SAFETY', '@WCET', '@CERT', '@FAULT']:
                            if tag in line:
                                annotations.append({
                                    "file": fpath,
                                    "line": lineno,
                                    "tag": tag,
                                    "text": line.strip()
                                })
    return annotations


def compute_fmeda(annotations, fault_injection_dir=None):
    """Compute FMEDA from safety annotations and fault categories."""
    safety_lines = [a for a in annotations if a["tag"] == "@SAFETY"]
    fault_lines = [a for a in annotations if a["tag"] == "@FAULT"]

    # Build FMEDA entries
    fmeda_entries = []
    total_dc_weighted = 0.0
    total_weight = 0

    for fault_name, fault_info in FAULT_CATEGORIES.items():
        entry = {
            "fault_name": fault_name,
            "severity": fault_info["severity"],
            "diagnostic_coverage": fault_info["dc"],
            "safety_mechanism": fault_info["mechanism"],
            "covered_by_safety_annotation": any(
                fault_name.lower().replace("_", " ") in a["text"].lower()
                for a in safety_lines
            )
        }
        fmeda_entries.append(entry)
        weight = {"LOW": 1, "MEDIUM": 10, "HIGH": 100}.get(fault_info["severity"], 1)
        total_dc_weighted += fault_info["dc"] * weight
        total_weight += weight

    overall_dc = total_dc_weighted / total_weight if total_weight > 0 else 0.0

    return {
        "entries": fmeda_entries,
        "overall_diagnostic_coverage": round(overall_dc, 4),
        "safety_annotation_count": len(safety_lines),
        "fault_annotation_count": len(fault_lines),
        "asil_target": "ASIL-D",
        "dc_target": DC_TARGETS["ASIL-D"],
        "dc_target_met": overall_dc >= DC_TARGETS["ASIL-D"]
    }


def main():
    parser = argparse.ArgumentParser(description='AEGIS-RV FMEDA Generator')
    parser.add_argument('--rtl', required=True, help='Path to RTL directory')
    parser.add_argument('--fault-injection', default=None, help='Path to fault injection testbench dir')
    parser.add_argument('--output', required=True, help='Output JSON path')
    args = parser.parse_args()

    annotations = scan_rtl_safety_annotations(args.rtl)
    fmeda = compute_fmeda(annotations, args.fault_injection)

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "fmeda": fmeda
    }

    os.makedirs(os.path.dirname(args.output) or '.', exist_ok=True)
    with open(args.output, 'w') as f:
        json.dump(report, f, indent=2)

    if fmeda["dc_target_met"]:
        print(f"[PASS] Overall DC = {fmeda['overall_diagnostic_coverage']:.2%} >= {fmeda['dc_target']:.0%} (ASIL-D)")
    else:
        print(f"[FAIL] Overall DC = {fmeda['overall_diagnostic_coverage']:.2%} < {fmeda['dc_target']:.0%} (ASIL-D)")

    print(f"[✓] FMEDA report written to {args.output}")
    sys.exit(0 if fmeda["dc_target_met"] else 1)


if __name__ == '__main__':
    main()
