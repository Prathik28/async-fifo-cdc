#!/usr/bin/env bash
# Regenerate docs/waveform.svg from an Icarus Verilog simulation.
set -euo pipefail
cd "$(dirname "$0")/.."
build="${BUILD_DIR:-build}/waveform"
mkdir -p "$build"
iverilog -g2012 -s tb_waveform -o "$build/simv" -f rtl/files.f tb/tb_waveform.sv
vvp -N "$build/simv" +VCD="$build/waveform.vcd" | tee "$build/run.log"
grep -q "waveform run PASSED" "$build/run.log"
python3 scripts/vcd2svg.py "$build/waveform.vcd" docs/waveform.svg
echo "wrote docs/waveform.svg"
