#!/bin/bash
# ============================================================================
# ASan Experiment 1: Basic Memory Errors
# ============================================================================
# Goal: See how AddressSanitizer catches stack, heap, and global overflows
#
# ASan vs Valgrind:
#   - ASan instruments at COMPILE TIME (red zones around every object)
#   - ~2x slowdown (vs Valgrind's 20-50x)
#   - Catches stack & global overflows (Valgrind usually cannot!)
#   - Requires recompilation with -fsanitize=address
#
# What to observe:
#   - ASan prints a colored error report with exact line numbers
#   - Shadow memory dump shows the red zone layout
#   - Stack traces show the allocation/deallocation site
#
# Key insight: In HFT, ASan is used in CI/testing builds. You compile
#              with -fsanitize=address, run your test suite, and catch
#              bugs that would be invisible in production.
# ============================================================================

set -e

BIN="./build/asan_targets"

echo "====================================================="
echo " ASan Experiment 1: Basic Memory Errors"
echo "====================================================="
echo ""
echo "NOTE: Each mode will crash (ASan aborts on first error)."
echo "      This is by design — ASan shows the FIRST bug it finds."

run_mode() {
    local mode=$1
    local desc=$2
    echo ""
    echo "--- Mode $mode: $desc ---"
    # ASan returns non-zero on error; || true keeps the script going
    "$BIN" "$mode" 2>&1 || true
    echo ""
    echo "  ^^^ Read the ASan output above ^^^"
    echo "-----------------------------------------------------------"
}

echo ""
echo "============================================"
echo " A. Stack buffer overflow (Valgrind misses!)"
echo "============================================"
run_mode 0 "Stack buffer overflow"
echo ""
echo "  Key: ASan puts RED ZONES around stack arrays."
echo "  Valgrind does NOT instrument stack — it would miss this."

echo ""
echo "============================================"
echo " B. Heap buffer overflow"
echo "============================================"
run_mode 1 "Heap buffer overflow"
echo ""
echo "  Key: Similar to Valgrind, but ASan is ~10x faster."

echo ""
echo "============================================"
echo " C. Use-after-free"
echo "============================================"
run_mode 2 "Use-after-free"
echo ""
echo "  Key: ASan keeps freed memory in a quarantine zone."
echo "  Any access to quarantined memory is caught immediately."

echo ""
echo "============================================"
echo " D. Global buffer overflow (Valgrind misses!)"
echo "============================================"
run_mode 4 "Global buffer overflow"
echo ""
echo "  Key: ASan puts red zones around GLOBAL arrays too."
echo "  This is completely invisible to Valgrind."

echo ""
echo "============================================"
echo " E. Clean baseline (should be no errors)"
echo "============================================"
run_mode 8 "Clean baseline"

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. What does 'shadow byte' mean in ASan output?"
echo " 2. Why can ASan catch stack overflow but Valgrind cannot?"
echo " 3. What is the performance difference? (try: time ./build/asan_targets 8)"
echo " 4. How would you use ASan in a CI pipeline?"
echo "====================================================="
echo ""
echo " Compare with Valgrind:"
echo "   valgrind ./build/valgrind_targets 0    # try mode 0 (heap overflow)"
echo "   # Then try a STACK overflow with Valgrind — it won't catch it!"
echo "====================================================="
