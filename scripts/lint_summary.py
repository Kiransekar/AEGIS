#!/usr/bin/env python3
"""
AEGIS-RV Lint Summary Aggregator
Aggregates Verilator lint warnings across all modules
"""

import re
import argparse
from pathlib import Path
from collections import defaultdict

def parse_lint_log(log_file):
    """Parse Verilator lint output"""
    warnings = defaultdict(list)
    with open(log_file, 'r') as f:
        for line in f:
            # Match: %Warning-<RULE>: <file>:<line>: <message>
            match = re.search(r'%Warning-(\w+):\s*(.+?):(\d+):\s*(.+)', line)
            if match:
                rule = match.group(1)
                filepath = match.group(2)
                lineno = match.group(3)
                message = match.group(4)
                warnings[rule].append({
                    'file': filepath,
                    'line': lineno,
                    'message': message
                })
    return warnings

def generate_summary(warnings, output_file=None):
    """Generate lint summary report"""
    lines = []
    lines.append("=" * 79)
    lines.append("AEGIS-RV Lint Summary")
    lines.append("=" * 79)
    lines.append("")

    total_warnings = sum(len(v) for v in warnings.values())
    lines.append(f"Total Warnings: {total_warnings}")
    lines.append(f"Unique Rules: {len(warnings)}")
    lines.append("")

    lines.append("Warnings by Rule:")
    lines.append("-" * 40)
    for rule, instances in sorted(warnings.items(), key=lambda x: -len(x[1])):
        lines.append(f"  {rule:30s} : {len(instances):3d} instances")

    lines.append("")
    lines.append("Warnings by File:")
    lines.append("-" * 40)
    by_file = defaultdict(int)
    for rule, instances in warnings.items():
        for inst in instances:
            by_file[inst['file']] += 1
    for filepath, count in sorted(by_file.items(), key=lambda x: -x[1]):
        lines.append(f"  {filepath:50s} : {count:3d} warnings")

    summary = "\n".join(lines)
    print(summary)

    if output_file:
        with open(output_file, 'w') as f:
            f.write(summary + "\n")
        print(f"[✓] Lint summary written to: {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AEGIS-RV Lint Summary")
    parser.add_argument("--log", required=True, help="Verilator lint log file")
    parser.add_argument("--output", help="Output summary file")
    args = parser.parse_args()

    warnings = parse_lint_log(args.log)
    generate_summary(warnings, args.output)
