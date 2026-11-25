#!/usr/bin/env bash
# Yosys synthesis check: generic and Xilinx 7-series flows, no inferred latches.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
for flow in generic xilinx; do
    log="build/synth_$flow.log"
    if [ "$flow" = generic ]; then cmd="synth -top async_fifo"; else cmd="synth_xilinx -family xc7 -top async_fifo"; fi
    yosys -q -l "$log" -p "read_verilog -sv -DSYNTHESIS $(tr '\n' ' ' < rtl/files.f); $cmd; check -assert; stat"
    if grep -Eq 'Latch inferred|^[[:space:]]+[0-9]+[[:space:]]+(\$_DLATCH|LD[CP]E)' "$log"; then
        echo "synth ($flow): FAIL, latch inferred"; exit 1
    fi
    echo "synth ($flow): PASS"
    awk '/Printing statistics/{s=""} /Printing statistics/,/End of script/{s=s $0 "\n"} END{printf "%s", s}' "$log"
done
