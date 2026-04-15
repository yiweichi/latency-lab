#!/bin/bash
# ============================================================================
# Valgrind Experiment 3: Callgrind — Call Graph Profiling
# ============================================================================
# Goal: Compare instruction cost of recursive vs iterative algorithms
#
# What to observe:
#   - fib_recursive dominates instruction count (exponential calls)
#   - fib_iterative is negligible
#   - call graph shows the explosion of recursive calls
#
# Key insight: Callgrind counts every instruction executed. Unlike sampling
#              profilers (perf record), it gives exact counts — no sampling
#              noise. Perfect for "is my hot function really the bottleneck?"
#
# Visualization: Use KCachegrind (Linux) or QCachegrind (macOS) to explore
#                the call graph interactively.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
FIB_N="${2:-35}"
RESULTS_DIR="./results/valgrind"
mkdir -p "$RESULTS_DIR"

echo "====================================================="
echo " Experiment 3: Callgrind — Call Graph Profiling"
echo "====================================================="
echo " Fibonacci N: $FIB_N"

echo ""
echo "--- A. Record with callgrind ---"
valgrind \
    --tool=callgrind \
    --callgrind-out-file="$RESULTS_DIR/callgrind.out" \
    --collect-jumps=yes \
    --cache-sim=yes \
    "$BIN_DIR/valgrind_targets" 2 "$FIB_N" 2>&1

echo ""
echo "--- B. Annotate hottest functions ---"
if command -v callgrind_annotate &>/dev/null; then
    echo "--- callgrind_annotate top functions ---"
    callgrind_annotate "$RESULTS_DIR/callgrind.out" 2>&1 | head -60
fi

echo ""
echo "--- C. Visualize (run manually) ---"
echo "  kcachegrind $RESULTS_DIR/callgrind.out   # Linux"
echo "  qcachegrind $RESULTS_DIR/callgrind.out   # macOS (brew install qcachegrind)"

echo ""
echo "--- D. Compare: try with a smaller N ---"
echo "  valgrind --tool=callgrind $BIN_DIR/valgrind_targets 2 25"
echo "  # fib(35) has ~18M calls; fib(25) has ~150K calls"

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. How many times is fib_recursive called for fib($FIB_N)?"
echo " 2. What % of total instructions does fib_recursive consume?"
echo " 3. What does the call graph look like in KCachegrind?"
echo " 4. How does --cache-sim=yes change the output?"
echo "====================================================="
echo ""
echo "Output file: $RESULTS_DIR/callgrind.out"
