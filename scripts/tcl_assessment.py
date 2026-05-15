#!/usr/bin/env python3
"""AEGIS-RV Toolchain Confidence Level (TCL) Assessment
Generates TCL bundle for ISO 26262 tool qualification evidence.
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone


def get_toolchain_info(toolchain_path, isa):
    """Extract toolchain version and configuration info."""
    info = {
        "toolchain_path": toolchain_path,
        "target_isa": isa,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "tools": {}
    }

    tool_prefix = os.path.join(toolchain_path, "bin", "riscv64-unknown-elf-")

    tools = [
        ("gcc", "--version"),
        ("ld", "--version"),
        ("objcopy", "--version"),
        ("gdb", "--version"),
    ]

    for tool_name, version_flag in tools:
        tool_path = tool_prefix + tool_name
        try:
            result = subprocess.run(
                [tool_path, version_flag],
                capture_output=True, text=True, timeout=10
            )
            info["tools"][tool_name] = {
                "path": tool_path,
                "version": result.stdout.strip().split('\n')[0],
                "available": True
            }
        except (FileNotFoundError, subprocess.TimeoutExpired):
            info["tools"][tool_name] = {
                "path": tool_path,
                "version": "NOT FOUND",
                "available": False
            }

    return info


def assess_tcl(info, isa):
    """Assess Tool Confidence Level per ISO 26262-8."""
    # GCC for safety-critical embedded: typically TCL2 or TCL3
    # Requires qualification for TCL3+ usage
    all_available = all(t["available"] for t in info["tools"].values())

    tcl_level = 3 if all_available else 0
    qualification_required = tcl_level >= 3

    assessment = {
        "tcl_level": tcl_level,
        "qualification_required": qualification_required,
        "tool_class": "TY.2" if tcl_level >= 2 else "TY.1",
        "all_tools_available": all_available,
        "isa_compliance": isa,
        "safety_standard": "ISO 26262-8:2018",
        "criteria": [
            {"id": "TCL.1", "description": "Tool version identified", "pass": all_available},
            {"id": "TCL.2", "description": "Tool configuration documented", "pass": all_available},
            {"id": "TCL.3", "description": "Tool validation evidence available", "pass": False},
        ]
    }

    return assessment


def main():
    parser = argparse.ArgumentParser(description='AEGIS-RV TCL Assessment')
    parser.add_argument('--toolchain', required=True, help='Path to RISC-V toolchain')
    parser.add_argument('--isa', default='rv32imacf', help='Target ISA string')
    parser.add_argument('--output', required=True, help='Output JSON path')
    args = parser.parse_args()

    info = get_toolchain_info(args.toolchain, args.isa)
    assessment = assess_tcl(info, args.isa)

    bundle = {
        "toolchain_info": info,
        "tcl_assessment": assessment
    }

    os.makedirs(os.path.dirname(args.output) or '.', exist_ok=True)
    with open(args.output, 'w') as f:
        json.dump(bundle, f, indent=2)

    all_pass = all(c["pass"] for c in assessment["criteria"])
    if all_pass:
        print(f"[PASS] TCL assessment complete: Level {assessment['tcl_level']}")
    else:
        print(f"[WARN] TCL assessment incomplete — some criteria not met")
        for c in assessment["criteria"]:
            if not c["pass"]:
                print(f"  - {c['id']}: {c['description']}")

    print(f"[✓] Bundle written to {args.output}")
    sys.exit(0 if all_pass else 1)


if __name__ == '__main__':
    main()
