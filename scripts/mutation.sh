#!/usr/bin/env bash
# Fault injection: plant one bug at a time and require the testbench to catch it.
# A mutant that fails to compile counts as a script error, not as a detection.
set -euo pipefail
cd "$(dirname "$0")/.."
build="${BUILD_DIR:-build}/mutation"

# file | original text | faulty text | description
mutants=(
  'wptr_full|wbin_next ^ (wbin_next >> 1)|wbin_next|binary write pointer crosses domains'
  'rptr_empty|rbin_next ^ (rbin_next >> 1)|rbin_next|binary read pointer crosses domains'
  'wptr_full|winc & ~wfull|winc|writes accepted while full'
  'rptr_empty|rinc & ~rempty|rinc|reads accepted while empty'
  'wptr_full|{~rgray_sync[ADDR_WIDTH -: 2],|{rgray_sync[ADDR_WIDTH -: 2],|wrong full comparison'
  'rptr_empty|rgray_next == wgray_sync|rgray == wgray_sync|empty flag one cycle late'
  'wptr_full|woverflow    <= winc & wfull;|woverflow    <= 1'"'"'b0;|overflow never reported'
  'rptr_empty|runderflow    <= rinc & rempty;|runderflow    <= 1'"'"'b0;|underflow never reported'
  'wptr_full|level_next >= AFULL|level_next > AFULL|almost-full off by one'
)

caught=0
for i in "${!mutants[@]}"; do
    IFS='|' read -r file from to desc <<<"${mutants[$i]}"
    dir="$build/m$i"
    rm -rf "$dir"; mkdir -p "$dir/rtl"
    cp rtl/*.sv "$dir/rtl/"
    python3 - "$dir/rtl/$file.sv" "$from" "$to" <<'PY'
import sys
path, old, new = sys.argv[1:]
text = open(path).read()
if text.count(old) != 1:
    sys.exit(f"mutation anchor not found exactly once in {path}: {old}")
open(path, "w").write(text.replace(old, new))
PY
    sources=()
    while read -r f; do sources+=("$dir/$f"); done < rtl/files.f
    verilator --binary --quiet --timing --assert -Wno-fatal --timescale 1ns/1ps \
        --top-module tb_async_fifo --Mdir "$dir/obj" -o simv \
        "${sources[@]}" sva/*.sv tb/tb_async_fifo.sv >"$dir/build.log" 2>&1 ||
        { cat "$dir/build.log"; echo "mutation: mutant did not compile: $desc"; exit 1; }
    if "$dir/obj/simv" +WPER=10000 +RPER=23000 >"$dir/run.log" 2>&1; then
        echo "SURVIVED  $desc"
    else
        echo "caught    $desc"
        caught=$((caught + 1))
    fi
done
echo "mutation: $caught of ${#mutants[@]} injected bugs caught"
[ "$caught" -eq "${#mutants[@]}" ]
