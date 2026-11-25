#!/usr/bin/env bash
# SymbiYosys: unbounded proof (PDR) plus reachability covers.
set -euo pipefail
cd "$(dirname "$0")/.."
build="${BUILD_DIR:-build}"
mkdir -p "$build"
for task in prove cover; do
    if ! sby -f --prefix "$build/formal" formal/async_fifo.sby "$task" >"$build/formal_$task.log" 2>&1; then
        cat "$build/formal_$task.log"; echo "formal ($task): FAIL"; exit 1
    fi
    grep -E 'DONE \(|reached cover|Status returned|successful proof' "$build/formal_$task.log" | sed 's/^SBY [0-9: ]*//'
done
echo "formal: PASS"
