#!/usr/bin/env python3
"""AEGIS-RV Signoff Checker — Phase 3 Verification Gate
Checks WNS/TNS from timing report and DRC violations from DRC report.
"""

import argparse
import json
import re
import sys


def check_timing(timing_rpt):
    """Parse timing report, return (wns, tns)."""
    wns = None
    tns = None
    try:
        with open(timing_rpt, 'r') as f:
            for line in f:
                m = re.search(r'wns\s+([\-\d.]+)', line, re.IGNORECASE)
                if m:
                    wns = float(m.group(1))
                m = re.search(r'tns\s+([\-\d.]+)', line, re.IGNORECASE)
                if m:
                    tns = float(m.group(1))
    except FileNotFoundError:
        print(f"[FAIL] Timing report not found: {timing_rpt}")
        return None, None

    return wns, tns


def check_drc(drc_rpt):
    """Parse DRC report, return violation count."""
    violations = None
    try:
        with open(drc_rpt, 'r') as f:
            content = f.read()
            m = re.search(r'(?:total\s+)?violations?\s*[:=]?\s*(\d+)', content, re.IGNORECASE)
            if m:
                violations = int(m.group(1))
            else:
                # If file exists but no violations pattern, assume 0
                violations = 0
    except FileNotFoundError:
        print(f"[FAIL] DRC report not found: {drc_rpt}")
        return None

    return violations


def main():
    parser = argparse.ArgumentParser(description='AEGIS-RV Signoff Checker')
    parser.add_argument('--wns', required=True, help='Path to timing report')
    parser.add_argument('--drc', required=True, help='Path to DRC report')
    args = parser.parse_args()

    all_pass = True

    # Check timing
    wns, tns = check_timing(args.wns)
    if wns is None:
        all_pass = False
    elif wns < 0.0:
        print(f"[FAIL] WNS = {wns:.3f}ns (must be >= 0.000ns)")
        all_pass = False
    else:
        print(f"[PASS] WNS = {wns:.3f}ns (>= 0.000ns)")

    if tns is None:
        all_pass = False
    elif tns != 0.0:
        print(f"[FAIL] TNS = {tns:.3f}ns (must be 0.000ns)")
        all_pass = False
    else:
        print(f"[PASS] TNS = {tns:.3f}ns (== 0.000ns)")

    # Check DRC
    violations = check_drc(args.drc)
    if violations is None:
        all_pass = False
    elif violations != 0:
        print(f"[FAIL] DRC violations = {violations} (must be 0)")
        all_pass = False
    else:
        print(f"[PASS] DRC violations = 0")

    if all_pass:
        print("PASS: Phase 3")
        sys.exit(0)
    else:
        print("FAIL: Phase 3")
        sys.exit(1)


if __name__ == '__main__':
    main()
