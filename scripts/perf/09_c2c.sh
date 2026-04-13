#!/bin/bash
# ============================================================================
# Perf Experiment 9: perf c2c — Cache-to-Cache (False Sharing Detection)
# ============================================================================
# Goal: Find cache lines that bounce between CPUs (false sharing)
#
# perf c2c = "cache to cache" — detects HITM events (a load hits a cache
#            line that was modified by another CPU, requiring cross-core transfer)
#
# What to observe:
#   - "Shared Data Cache Line Table" shows contended cache lines
#   - High HITM count = cache line bouncing between cores
#   - The output shows the exact variable/struct causing it
#
# Key insight: False sharing is invisible in normal profiling.
#              perf c2c is the ONLY way to find it without guessing.
#              In HFT, false sharing can add 20-70ns per access.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/perf"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " Experiment 9: perf c2c (False Sharing Detection)"
echo "====================================================="

echo ""
echo "--- A. Record false_sharing with c2c ---"
echo "(This records HITM events — loads that hit modified cache lines)"
perf c2c record -g --call-graph dwarf \
    -o "$RESULT_DIR/c2c_falseshare.data" \
    -- "$BIN_DIR/false_sharing" 50000000

echo ""
echo "--- B. Report: Shared Data Cache Line Table ---"
echo "(Look for cache lines with high HITM count)"
perf c2c report -i "$RESULT_DIR/c2c_falseshare.data" \
    --stdio 2>&1 | head -80

echo ""
echo "--- C. Record orderbook_map for comparison ---"
perf c2c record -g --call-graph dwarf \
    -o "$RESULT_DIR/c2c_orderbook.data" \
    -- "$BIN_DIR/orderbook_bench" 0 1000000

echo ""
echo "--- D. Report orderbook c2c ---"
perf c2c report -i "$RESULT_DIR/c2c_orderbook.data" \
    --stdio 2>&1 | head -60

echo ""
echo "====================================================="
echo " How to read perf c2c output:"
echo "====================================================="
echo ""
echo " Key columns in Shared Data Cache Line Table:"
echo "   Rmt: Remote HITM — load hit a line modified on ANOTHER socket"
echo "        (most expensive: ~100-200 cycles, cross-NUMA)"
echo "   Lcl: Local HITM — load hit a line modified on SAME socket"
echo "        (expensive: ~30-70 cycles, cross-core)"
echo ""
echo " The table shows:"
echo "   1. Cache line address"
echo "   2. HITM count (higher = more contention)"
echo "   3. Source code location causing the contention"
echo ""
echo " For false_sharing experiment:"
echo "   SharedCounters.counter1 and counter2 are on SAME cache line"
echo "   → high Lcl HITM because both cores write to same 64-byte line"
echo ""
echo " Interactive mode (recommended for drilling down):"
echo "   perf c2c report -i $RESULT_DIR/c2c_falseshare.data"
echo "   then press 'd' to see per-data-address breakdown"
echo "====================================================="
