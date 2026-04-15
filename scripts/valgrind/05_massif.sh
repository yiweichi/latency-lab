#!/bin/bash
# ============================================================================
# Valgrind Experiment 5: Massif — Heap Profiler
# ============================================================================
# Goal: Visualize heap memory usage over time
#
# What to observe:
#   - Allocation growth pattern (sawtooth from alloc + partial free + big alloc)
#   - Which call sites dominate heap usage
#   - Peak heap usage
#
# Key insight: In HFT, unexpected heap allocations in the hot path kill
#              latency (malloc can take microseconds + fragment memory).
#              Massif shows exactly where and when heap grows — use it to
#              verify your hot path is allocation-free.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
ROUNDS="${2:-20}"
RESULTS_DIR="./results/valgrind"
mkdir -p "$RESULTS_DIR"

echo "====================================================="
echo " Experiment 5: Massif — Heap Profiler"
echo "====================================================="
echo " Rounds: $ROUNDS"

echo ""
echo "--- A. Record heap usage ---"
valgrind \
    --tool=massif \
    --massif-out-file="$RESULTS_DIR/massif.out" \
    --stacks=yes \
    --detailed-freq=1 \
    "$BIN_DIR/valgrind_targets" 4 "$ROUNDS" 2>&1

echo ""
echo "--- B. Print heap profile ---"
if command -v ms_print &>/dev/null; then
    ms_print "$RESULTS_DIR/massif.out" 2>&1 | head -80
fi

echo ""
echo "--- C. Run on orderbook_bench (real HFT workload) ---"
echo "(Shows whether std::map allocates during insert/erase)"
echo "  valgrind --tool=massif --stacks=yes $BIN_DIR/orderbook_bench 100000"
echo "  ms_print massif.out.<pid>"

echo ""
echo "--- D. Compare with --pages-as-heap=yes ---"
echo "(Tracks mmap/brk instead of malloc — shows total process memory)"
echo "  valgrind --tool=massif --pages-as-heap=yes $BIN_DIR/valgrind_targets 4 $ROUNDS"

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. What is the peak heap usage (in KB)?"
echo " 2. Can you see the free-half step in the ms_print graph?"
echo " 3. Which allocation site uses the most memory?"
echo " 4. What does --stacks=yes add to the profile?"
echo " 5. How would you use Massif to find allocations in an HFT hot path?"
echo "====================================================="
echo ""
echo "Output file: $RESULTS_DIR/massif.out"
echo "View with:   ms_print $RESULTS_DIR/massif.out"
