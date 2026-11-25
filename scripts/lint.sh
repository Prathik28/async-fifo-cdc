#!/usr/bin/env bash
# Verilator lint with all warnings enabled, across several parameter sets.
set -euo pipefail
cd "$(dirname "$0")/.."
for cfg in "8 4 2" "1 2 2" "32 6 3" "64 9 4"; do
    read -r dw aw st <<<"$cfg"
    echo "lint: DATA_WIDTH=$dw ADDR_WIDTH=$aw SYNC_STAGES=$st"
    verilator --lint-only --quiet -Wall --top-module async_fifo \
        -GDATA_WIDTH="$dw" -GADDR_WIDTH="$aw" -GSYNC_STAGES="$st" -f rtl/files.f
done
echo "lint: PASS"
