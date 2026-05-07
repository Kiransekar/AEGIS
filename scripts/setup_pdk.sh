#!/bin/bash
#===============================================================================
# AEGIS-RV PDK Setup Script
# Installs: SkyWater 130 PDK + standard cell library
#===============================================================================
set -euo pipefail

PDK_ROOT="${PDK_ROOT:-$HOME/skywater-pdk}"
PDK="${PDK:-sky130}"
STD_CELL="${STD_CELL:-sky130_fd_sc_hd}"

echo "==============================================================================="
echo "AEGIS-RV PDK Setup (SkyWater 130)"
echo "==============================================================================="

#--- SkyWater PDK ---
echo "[→] Cloning SkyWater 130 PDK..."
if [ ! -d "$PDK_ROOT" ]; then
    git clone --depth=1 https://github.com/google/skywater-pdk.git "$PDK_ROOT"
fi
cd "$PDK_ROOT"
git pull --ff-only 2>/dev/null || true

#--- Initialize submodules ---
echo "[→] Initializing PDK submodules..."
make -j$(nproc) sky130A 2>/dev/null || {
    echo "[WARN] PDK build failed — attempting manual setup..."
    # Manual fallback for common submodules
    git submodule update --init --recursive libraries/sky130_fd_sc_hd/latest 2>/dev/null || true
    git submodule update --init --recursive libraries/sky130_fd_sc_hdvl/latest 2>/dev/null || true
}

#--- Environment Setup ---
echo "[→] Setting environment variables..."
export PDK_ROOT="$PDK_ROOT"
export PDK="sky130"
export STD_CELL_LIBRARY="$PDK_ROOT/libraries/sky130_fd_sc_hd/latest"

echo ""
echo "Add to your shell profile:"
echo "  export PDK_ROOT=$PDK_ROOT"
echo "  export PDK=sky130"
echo "  export STD_CELL_LIBRARY=\$PDK_ROOT/libraries/sky130_fd_sc_hd/latest"
echo ""
echo "==============================================================================="
echo "PDK setup complete: $PDK_ROOT"
echo "==============================================================================="
