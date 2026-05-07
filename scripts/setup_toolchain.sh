#!/bin/bash
#===============================================================================
# AEGIS-RV Toolchain Setup Script
# Installs: Yosys, SymbiYosys, Verilator, GTKWave, OpenROAD
# PDK: SkyWater 130
#===============================================================================
set -euo pipefail

echo "==============================================================================="
echo "AEGIS-RV Toolchain Setup"
echo "==============================================================================="

#--- Prerequisites ---
echo "[→] Installing prerequisites..."
sudo apt-get update -qq
sudo apt-get install -y -qq build-essential clang bison flex libreadline-dev \
    gawk tcl-dev libffi-dev git mercurial graphviz xdot pkg-config \
    python3 python3-pip python3-venv libboost-all-dev cmake \
    qt5-default libqt5svg5-dev 2>/dev/null || true

#--- Yosys ---
echo "[→] Installing Yosys..."
if ! command -v yosys &>/dev/null; then
    if [ ! -d "$HOME/yosys" ]; then
        git clone --depth=1 https://github.com/YosysHQ/yosys.git "$HOME/yosys"
    fi
    cd "$HOME/yosys"
    git pull --ff-only 2>/dev/null || true
    make -j$(nproc) PREFIX=/usr/local
    sudo make install PREFIX=/usr/local
fi
echo "[✓] Yosys: $(yosys -V 2>/dev/null | head -1 || echo 'installed')"

#--- SymbiYosys ---
echo "[→] Installing SymbiYosys..."
if ! command -v sby &>/dev/null; then
    if [ ! -d "$HOME/sby" ]; then
        git clone --depth=1 https://github.com/YosysHQ/SymbiYosys.git "$HOME/sby"
    fi
    cd "$HOME/sby"
    git pull --ff-only 2>/dev/null || true
    sudo make install PREFIX=/usr/local
fi
echo "[✓] SymbiYosys: installed"

#--- Verilator ---
echo "[→] Installing Verilator..."
if ! command -v verilator &>/dev/null; then
    if [ ! -d "$HOME/verilator" ]; then
        git clone --depth=1 https://github.com/verilator/verilator.git "$HOME/verilator"
    fi
    cd "$HOME/verilator"
    git pull --ff-only 2>/dev/null || true
    autoconf
    ./configure
    make -j$(nproc)
    sudo make install
fi
echo "[✓] Verilator: $(verilator --version 2>/dev/null | head -1 || echo 'installed')"

#--- GTKWave ---
echo "[→] Installing GTKWave..."
if ! command -v gtkwave &>/dev/null; then
    sudo apt-get install -y -qq gtkwave 2>/dev/null || true
fi
echo "[✓] GTKWave: $(gtkwave --version 2>/dev/null | head -1 || echo 'installed')"

#--- OpenROAD ---
echo "[→] Installing OpenROAD..."
if ! command -v openroad &>/dev/null; then
    if [ ! -d "$HOME/OpenROAD" ]; then
        git clone --depth=1 --recursive https://github.com/The-OpenROAD-Project/OpenROAD.git "$HOME/OpenROAD"
    fi
    cd "$HOME/OpenROAD"
    git submodule update --init --recursive 2>/dev/null || true
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
    make -j$(nproc)
    sudo make install
fi
echo "[✓] OpenROAD: $(openroad -version 2>/dev/null || echo 'installed')"

#--- Python Dependencies ---
echo "[→] Installing Python dependencies..."
pip3 install --quiet pyyaml 2>/dev/null || true

echo ""
echo "==============================================================================="
echo "Toolchain installation complete."
echo "Run 'make env_check' to verify."
echo "==============================================================================="
