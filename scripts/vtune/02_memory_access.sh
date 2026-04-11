#!/bin/bash
# ============================================================================
# VTune Experiment 2: Memory Access Analysis
# ============================================================================
# Goal: Deep-dive into cache behavior — L1/L2/L3/DRAM breakdown
#
# What to observe:
#   - Memory bound vs compute bound ratio
#   - L1/L2/L3 hit rates
#   - DRAM latency
#   - Which data structures cause cache misses
#
# Key insight: VTune's memory access analysis goes far beyond
#              `perf stat -e cache-misses`. It can tell you:
#              - WHICH cache level is the bottleneck
#              - WHICH memory addresses cause misses
#              - Whether the issue is bandwidth or latency
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/vtune"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " VTune Experiment 2: Memory Access Analysis"
echo "====================================================="

echo ""
echo "--- A. Sequential access (should be memory efficient) ---"
vtune -collect memory-access \
    -result-dir "$RESULT_DIR/memory_sequential" \
    -- "$BIN_DIR/cache_miss" 0 64

echo ""
echo "--- B. Random access (should be memory bound) ---"
vtune -collect memory-access \
    -result-dir "$RESULT_DIR/memory_random" \
    -- "$BIN_DIR/cache_miss" 2 64

echo ""
echo "--- C. Pointer chase (worst case memory latency) ---"
vtune -collect memory-access \
    -result-dir "$RESULT_DIR/memory_pointerchase" \
    -- "$BIN_DIR/cache_miss" 3 64

echo ""
echo "--- D. Orderbook map (tree = pointer chasing) ---"
vtune -collect memory-access \
    -result-dir "$RESULT_DIR/memory_orderbook_map" \
    -- "$BIN_DIR/orderbook_bench" 0 2000000

echo ""
echo "--- Reports ---"
for dir in "$RESULT_DIR"/memory_*; do
    name=$(basename "$dir")
    echo ""
    echo "=== $name ==="
    vtune -report summary -r "$dir" 2>&1 | head -40
done

echo ""
echo "====================================================="
echo " Questions:"
echo " 1. What % of time is 'Memory Bound' in random vs sequential?"
echo " 2. Which cache level has the highest miss rate?"
echo " 3. In the orderbook, how does std::map's memory access compare"
echo "    to the array-based orderbook?"
echo " 4. Can you identify the specific data structure causing misses?"
echo "====================================================="
