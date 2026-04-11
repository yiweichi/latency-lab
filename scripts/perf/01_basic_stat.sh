#!/bin/bash
# ============================================================================
# Perf Experiment 1: Basic Performance Counters
# ============================================================================
# Goal: Understand IPC, cycles, instructions
#
# What to observe:
#   - busy_loop mode 0: IPC should be high (~2-4), near max throughput
#   - busy_loop mode 2: IPC drops due to branch misprediction
#   - cache_miss mode 2: IPC drops due to memory stalls
#
# Key insight: IPC < 1.0 almost always means the CPU is waiting for something
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
echo "Expect: lower IPC, high branch-miss rate"
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
echo " 1. What is the IPC difference between A and B?"
echo "    (A should be ~3-4x higher)"
echo " 2. What is the branch-miss rate in B?"
echo "    (should be ~50% for random branches)"
echo " 3. What is the cache-miss rate difference between C and D?"
echo "    (D should have orders of magnitude more misses)"
echo " 4. Which scenario has lowest IPC? Why?"
echo "====================================================="
