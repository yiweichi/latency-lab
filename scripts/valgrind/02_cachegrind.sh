#!/bin/bash
# ============================================================================
# Valgrind Experiment 2: Cachegrind — Cache Simulation
# ============================================================================
# Goal: Compare cache behavior of sequential vs random array access
#
# What to observe:
#   - D1 miss rate: sequential ≈ 0%, random ≈ high
#   - LL (last-level) miss rate: sequential ≈ 0%, random ≈ high for large N
#   - Ir (instruction reads) should be similar for both
#
# Key insight: Cachegrind simulates a cache hierarchy, so results are
#              deterministic (unlike perf hardware counters). Great for
#              before/after comparisons during optimization.
#
# Limitation: Cachegrind simulates a simple 2-level cache, not your exact
#             CPU. Numbers won't match perf stat exactly, but relative
#             comparisons are very useful.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
N="${2:-500000}"
RESULTS_DIR="./results/valgrind"
mkdir -p "$RESULTS_DIR"

echo "====================================================="
echo " Experiment 2: Cachegrind — Cache Simulation"
echo "====================================================="
echo " Array size: $N elements"

echo ""
echo "--- A. Run cachegrind on sequential + random access ---"
valgrind \
    --tool=cachegrind \
    --cache-sim=yes \
    --cachegrind-out-file="$RESULTS_DIR/cachegrind.out" \
    "$BIN_DIR/valgrind_targets" 1 "$N" 2>&1

echo ""
echo "--- B. Annotate source ---"
echo "(Run manually for detailed per-line view:)"
echo "  cg_annotate --show=Ir,Dr,D1mr,DLmr,Dw,D1mw,DLmw $RESULTS_DIR/cachegrind.out"
echo ""

if command -v cg_annotate &>/dev/null; then
    echo "--- cg_annotate summary (with cache events) ---"
    cg_annotate --show=Ir,Dr,D1mr,DLmr,Dw,D1mw,DLmw \
        --threshold=1 \
        "$RESULTS_DIR/cachegrind.out" 2>&1 | head -80
fi

echo ""
echo "--- C. Compare with existing cache_miss benchmark ---"
echo "(Optional: run cachegrind on cache_miss for comparison)"
echo "  valgrind --tool=cachegrind $BIN_DIR/cache_miss 0 1000000"
echo "  valgrind --tool=cachegrind $BIN_DIR/cache_miss 1 1000000"

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. What is the D1 miss rate for sequential vs random?"
echo " 2. Why are Ir (instruction) counts similar for both?"
echo " 3. How does the simulated miss rate compare to perf stat L1-dcache-load-misses?"
echo " 4. What happens when you increase N beyond L2 cache size?"
echo "====================================================="
echo ""
echo "Output file: $RESULTS_DIR/cachegrind.out"
