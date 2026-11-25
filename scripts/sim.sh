#!/usr/bin/env bash
# Simulation regression over parameter sets and clock ratios.
#   scripts/sim.sh [verilator|icarus]
set -euo pipefail
cd "$(dirname "$0")/.."
sim="${1:-verilator}"
# Verilator's generated Makefile cannot build in a path containing spaces;
# set BUILD_DIR to another location if your checkout path has any.
build="${BUILD_DIR:-build}"

# DATA_WIDTH ADDR_WIDTH SYNC_STAGES
configs=("8 4 2" "1 2 2" "32 6 3")
# write_period_ps read_period_ps
ratios=(
    "10000 10000"   # same frequency, phase shifted
    "10000 23000"   # fast write
    "23000 10000"   # fast read
    "10000 80000"   # 8:1
    "80000 10000"   # 1:8
    "10000 10100"   # nearly equal, phase drifts through every offset
)

extra=()
if [ "$sim" = verilator ] && compgen -G "sva/*.sv" >/dev/null; then extra=(sva/*.sv); fi

runs=0
for cfg in "${configs[@]}"; do
    read -r dw aw st <<<"$cfg"
    out="$build/${sim}_${dw}_${aw}_${st}"
    mkdir -p "$out"
    if [ "$sim" = verilator ]; then
        verilator --binary --quiet --timing --assert --timescale 1ns/1ps --no-sched-zero-delay --top-module tb_async_fifo \
            -GDATA_WIDTH="$dw" -GADDR_WIDTH="$aw" -GSYNC_STAGES="$st" \
            --Mdir "$out" -o simv -f rtl/files.f ${extra[@]+"${extra[@]}"} tb/tb_async_fifo.sv
        run=("$out/simv")
    else
        iverilog -g2012 -s tb_async_fifo \
            -Ptb_async_fifo.DATA_WIDTH="$dw" -Ptb_async_fifo.ADDR_WIDTH="$aw" \
            -Ptb_async_fifo.SYNC_STAGES="$st" -o "$out/simv" -f rtl/files.f tb/tb_async_fifo.sv
        run=(vvp -N "$out/simv")
    fi
    for ratio in "${ratios[@]}"; do
        read -r wp rp <<<"$ratio"
        for seed in 1 2; do
            log="$out/run_${wp}_${rp}_$seed.log"
            if ! "${run[@]}" +WPER="$wp" +RPER="$rp" +SEED="$seed" >"$log" 2>&1 ||
               ! grep -q "TEST PASSED" "$log"; then
                cat "$log"; echo "sim ($sim): FAIL"; exit 1
            fi
            grep "^DW=" "$log"
            runs=$((runs + 1))
        done
    done
done
echo "sim ($sim): PASS, $runs runs"
