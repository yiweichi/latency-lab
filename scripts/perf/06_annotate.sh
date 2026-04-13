#!/bin/bash
# ============================================================================
# Perf Experiment 6: perf annotate — Source/Assembly Level Profiling
# ============================================================================
# Goal: See WHICH INSTRUCTION is the bottleneck, not just which function
#
# perf annotate = perf record + disassembly + per-instruction sample count
#
# What to observe:
#   - Each assembly instruction shows what % of CPU samples hit it
#   - Hot instructions are highlighted (the ones where CPU spends time)
#   - For cache_miss: the load instruction will dominate
#   - For busy_loop: the branch or add will dominate
#
# Key insight: perf report tells you the function, perf annotate tells you
#              the exact instruction. This is how you find the "one line"
#              that makes your HFT code slow.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/perf"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " Experiment 6: perf annotate"
echo "====================================================="

echo ""
echo "--- A. Record busy_loop (unpredictable branch) ---"
perf record -F 999 -g --call-graph dwarf -o "$RESULT_DIR/annotate_branch.data" \
    -- "$BIN_DIR/busy_loop" 2 500000000

echo ""
echo "--- A. Annotate: which instruction gets the most samples? ---"
perf annotate -i "$RESULT_DIR/annotate_branch.data" \
    --symbol=_Z22hot_loop_unpredictablel --stdio 2>&1 | head -60

echo ""
echo "--- B. Record cache_miss (random access) ---"
perf record -F 999 -g --call-graph dwarf -o "$RESULT_DIR/annotate_cache.data" \
    -- "$BIN_DIR/cache_miss" 2 64

echo ""
echo "--- B. Annotate: the load instruction should dominate ---"
perf annotate -i "$RESULT_DIR/annotate_cache.data" \
    --symbol=_Z13random_accessPiS_ii --stdio 2>&1 | head -60

echo ""
echo "--- C. Record false_sharing ---"
perf record -F 999 -e cache-misses -g --call-graph dwarf \
    -o "$RESULT_DIR/annotate_falseshare.data" \
    -- "$BIN_DIR/false_sharing" 100000000

echo ""
echo "--- C. Annotate: the store instruction on shared cache line ---"
perf annotate -i "$RESULT_DIR/annotate_falseshare.data" --stdio 2>&1 | head -60

echo ""
echo "====================================================="
echo " How to read the output:"
echo "====================================================="
echo "  Each line looks like:"
echo "    15.38%  │  add    eax, ecx"
echo "    42.31%  │  mov    DWORD PTR [rdi], eax    <-- HOT!"
echo ""
echo "  The percentage = fraction of CPU samples on that instruction."
echo "  High % on a load/store = memory bottleneck."
echo "  High % on a conditional jump = branch miss stall."
echo ""
echo " Interactive mode (recommended):"
echo "   perf report -i $RESULT_DIR/annotate_branch.data"
echo "   then press Enter on a function, then 'a' to annotate"
echo "====================================================="
