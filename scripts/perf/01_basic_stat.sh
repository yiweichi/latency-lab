#!/bin/bash
# ============================================================================
# Perf Experiment 1: Basic Performance Counters
# ============================================================================
# Goal: Understand IPC, cycles, instructions
#
# What to observe:
#   - busy_loop mode 0: high IPC, near max throughput
#   - busy_loop mode 2: ~25% branch-miss rate, ~2.7x slower wall time
#     NOTE: IPC may stay similar because mode 2 has more instructions per
#     iteration (xorshift). The penalty shows in cycles-per-iteration, not IPC.
#   - cache_miss mode 2: IPC drops due to memory stalls
#
# Key insight: IPC alone can be misleading — compare cycles/iteration instead.
#              IPC < 1.0 almost always means the CPU is waiting for something.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"

echo "====================================================="
echo " Experiment 1: Basic perf stat"
echo "====================================================="

echo ""
echo "--- A. Busy loop (predictable) ---"
echo "Expect: high IPC, near-zero branch misses"
perf stat -e cycles,instructions,branches,branch-misses \
    "$BIN_DIR/busy_loop" 0 500000000 2>&1

echo ""
echo "--- B. Busy loop (unpredictable branches) ---"
echo "Expect: ~25% branch-miss rate, ~2.7x more cycles, but similar IPC (more instructions too)"
perf stat -e cycles,instructions,branches,branch-misses \
    "$BIN_DIR/busy_loop" 2 500000000 2>&1

echo ""
echo "--- C. Cache miss (sequential) ---"
echo "Expect: high IPC, low cache misses"
perf stat -e cycles,instructions,cache-references,cache-misses,L1-dcache-load-misses \
    "$BIN_DIR/cache_miss" 0 64 2>&1

echo ""
echo "--- D. Cache miss (random) ---"
echo "Expect: low IPC, high cache misses"
perf stat -e cycles,instructions,cache-references,cache-misses,L1-dcache-load-misses \
    "$BIN_DIR/cache_miss" 2 64 2>&1

echo ""
echo "====================================================="
echo " Questions to answer after running:"
echo "====================================================="
echo " 1. IPC is similar between A and B — why?"
echo "    (B has more instructions per iteration, so instructions/cycles stays flat)"
echo "    Compare cycles-per-iteration instead: A ~5.5, B ~15.6"
echo " 2. What is the branch-miss rate in B?"
echo "    (should be ~25% of all branches, ~50% of the if/else branches)"
echo " 3. What is the cache-miss rate difference between C and D?"
echo "    (D should have orders of magnitude more misses)"
echo " 4. Which scenario has lowest IPC? Why?"
echo "====================================================="
