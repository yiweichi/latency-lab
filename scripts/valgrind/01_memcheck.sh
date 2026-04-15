#!/bin/bash
# ============================================================================
# Valgrind Experiment 1: Memcheck — Memory Error Detection
# ============================================================================
# Goal: Find heap overflow, use-after-free, leaks, and uninitialized reads
#
# What to observe:
#   - "Invalid write" = out-of-bounds heap write
#   - "Invalid read"  = use-after-free
#   - "definitely lost" = memory leak
#   - "Conditional jump ... depends on uninitialised value"
#
# Key insight: In HFT code, even a single use-after-free can cause
#              non-deterministic crashes under load. Memcheck finds them
#              deterministically (at 20-50x slowdown).
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULTS_DIR="./results/valgrind"
mkdir -p "$RESULTS_DIR"

echo "====================================================="
echo " Experiment 1: Memcheck — Memory Error Detection"
echo "====================================================="

echo ""
echo "--- A. Run buggy code with full leak checking ---"
valgrind \
    --tool=memcheck \
    --leak-check=full \
    --show-leak-kinds=all \
    --track-origins=yes \
    --verbose \
    --log-file="$RESULTS_DIR/memcheck_buggy.log" \
    "$BIN_DIR/valgrind_targets" 0

echo ""
echo "Memcheck log saved to: $RESULTS_DIR/memcheck_buggy.log"
echo ""
echo "--- Key errors (from log) ---"
grep -E "Invalid (read|write)|uninitialised|definitely lost|indirectly lost" \
    "$RESULTS_DIR/memcheck_buggy.log" | head -20 || true

echo ""
echo "--- B. Run clean baseline (should report 0 errors) ---"
valgrind \
    --tool=memcheck \
    --leak-check=full \
    --log-file="$RESULTS_DIR/memcheck_clean.log" \
    "$BIN_DIR/valgrind_targets" 5 10000

echo ""
grep -E "ERROR SUMMARY|definitely lost" "$RESULTS_DIR/memcheck_clean.log" || true

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. How many distinct error types does Memcheck find?"
echo " 2. What is the stack trace for the heap overflow?"
echo " 3. How many bytes are 'definitely lost'?"
echo " 4. Which line triggers the uninitialised read?"
echo " 5. Why does --track-origins=yes help with uninit errors?"
echo "====================================================="
echo ""
echo "Full logs: $RESULTS_DIR/memcheck_buggy.log"
echo "           $RESULTS_DIR/memcheck_clean.log"
