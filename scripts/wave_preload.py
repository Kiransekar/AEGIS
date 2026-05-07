#!/usr/bin/env python3
"""
AEGIS-RV GTKWave Preload Script
Generates .gtkw files with signal group hierarchies for common modules
"""

import sys
from pathlib import Path

def generate_gtkw(module_name, signals, output_file):
    """Generate a GTKWave preload file"""
    with open(output_file, 'w') as f:
        f.write("[*]\n")
        f.write("[*] AEGIS-RV GTKWave Preload\n")
        f.write(f"[*] Module: {module_name}\n")
        f.write("[*]\n")
        f.write("[dumpfile] sim/{}.vcd\n".format(module_name))
        f.write("[savefile] {}\n".format(output_file))
        f.write("[timestart] 0\n")
        f.write("[size] 1920 1080\n")
        f.write("[pos] -1 -1\n")
        f.write("*-6.000000 0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1\n")
        f.write("[treeopen] dut.\n")
        f.write("[treeopen] dut.u_smu.\n")
        f.write("[treeopen] dut.u_power.\n")
        f.write("\n")

        # Signal groups
        for group_name, group_signals in signals.items():
            f.write(f"[-] {group_name}\n")
            for sig in group_signals:
                f.write(f"    dut.{sig}\n")
            f.write("\n")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: wave_preload.py <module_name> <output_file>")
        sys.exit(1)

    module = sys.argv[1]
    output = sys.argv[2]

    # Default signal groups
    signals = {
        "Clock & Reset": ["i_clk", "i_rst_n"],
        "Fault Interface": ["i_fault_code[7:0]", "i_fault_valid", "o_active_fault[7:0]",
                            "o_fault_severity[1:0]", "o_safe_state_req", "o_fault_latched"],
        "Power Control": ["o_sleep_en", "o_iso_en", "o_retention_en", "o_pwr_switch_n",
                          "o_safe_state_active"],
    }

    generate_gtkw(module, signals, output)
    print(f"[✓] Generated GTKWave preload: {output}")
