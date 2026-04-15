#!/bin/bash
# ============================================================================
# Valgrind Experiment 4: Helgrind — Thread Error Detection
# ============================================================================
# Goal: Detect data races and verify lock-based fix
#
# What to observe:
#   - "Possible data race" on shared_counter_nolock
#   - Stack traces showing both threads' access points
#   - No errors for the locked version
#
# Key insight: Data races are the hardest bugs in HFT. They may not crash
#              for weeks, then corrupt an order price at 3am. Helgrind finds
#              them deterministically by tracking every memory access and
#              lock operation (happens-before analysis).
#
# Also try: --tool=drd (Valgrind's other race detector, sometimes faster)
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
ITERS="${2:-10000}"
RESULTS_DIR="./results/valgrind"
mkdir -p "$RESULTS_DIR"

echo "====================================================="
echo " Experiment 4: Helgrind — Thread Error Detection"
echo "====================================================="
echo " Iterations per thread: $ITERS"

echo ""
echo "--- A. Run with data race (no lock) + correct (with lock) ---"
valgrind \
    --tool=helgrind \
    --history-level=full \
    --log-file="$RESULTS_DIR/helgrind.log" \
    "$BIN_DIR/valgrind_targets" 3 "$ITERS" 2>&1

echo ""
echo "Helgrind log saved to: $RESULTS_DIR/helgrind.log"

echo ""
echo "--- Race reports summary ---"
grep -c "Possible data race" "$RESULTS_DIR/helgrind.log" 2>/dev/null || echo "0"
echo " possible data race(s) detected"

echo ""
grep -E "Possible data race|ERROR SUMMARY" "$RESULTS_DIR/helgrind.log" | head -10 || true

echo ""
echo "--- B. Try DRD (alternative race detector) ---"
echo "(Run manually:)"
echo "  valgrind --tool=drd $BIN_DIR/valgrind_targets 3 $ITERS"

echo ""
echo "--- C. Run on false_sharing benchmark ---"
echo "(Interesting: volatile counters without atomics trigger Helgrind)"
echo "  valgrind --tool=helgrind $BIN_DIR/false_sharing 1000"

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. How many data races does Helgrind report?"
echo " 2. Which variable is the race on? Which two threads?"
echo " 3. Does the locked version produce any Helgrind errors?"
echo " 4. What is the performance cost of running under Helgrind?"
echo " 5. What's the difference between Helgrind and DRD?"
echo "====================================================="
echo ""
echo "Full log: $RESULTS_DIR/helgrind.log"
