#!/bin/bash
# ============================================================================
# ASan Experiment 2: Advanced — Leaks, Double-Free, Use-After-Return
# ============================================================================
# Goal: Explore ASan features beyond basic overflow detection
#
# What to observe:
#   - LeakSanitizer (LSan) is bundled with ASan on Linux
#   - Use-after-return needs a special runtime flag
#   - Double free detection
#   - Use-after-scope (variable goes out of { })
#
# Key insight: ASan + LSan together cover most of what Valgrind Memcheck
#              does, at a fraction of the runtime cost. The main trade-off
#              is you need to recompile.
# ============================================================================

set -e

BIN="./build/asan_targets"

echo "====================================================="
echo " ASan Experiment 2: Advanced Features"
echo "====================================================="

run_mode() {
    local mode=$1
    local desc=$2
    local env_opts="${3:-}"
    echo ""
    echo "--- Mode $mode: $desc ---"
    if [ -n "$env_opts" ]; then
        echo "    ASAN_OPTIONS=$env_opts"
        ASAN_OPTIONS="$env_opts" "$BIN" "$mode" 2>&1 || true
    else
        "$BIN" "$mode" 2>&1 || true
    fi
    echo ""
    echo "-----------------------------------------------------------"
}

echo ""
echo "============================================"
echo " A. Double free"
echo "============================================"
run_mode 5 "Double free"
echo ""
echo "  Key: ASan tracks every allocation. Freeing twice = immediate abort."
echo "  In HFT, double-free can corrupt the allocator and cause"
echo "  non-deterministic crashes minutes or hours later."

echo ""
echo "============================================"
echo " B. Memory leak (LeakSanitizer)"
echo "============================================"
run_mode 6 "Memory leak" "detect_leaks=1"
echo ""
echo "  Key: LSan runs at exit and reports unreachable allocations."
echo "  Equivalent to Valgrind --leak-check=full but much faster."

echo ""
echo "============================================"
echo " C. Use-after-return"
echo "============================================"
echo "  (Requires detect_stack_use_after_return=1)"
run_mode 3 "Use-after-return" "detect_stack_use_after_return=1"
echo ""
echo "  Key: Normally, returning a pointer to a local variable is"
echo "  only caught if ASan replaces stack frames with heap allocs."
echo "  This is expensive, so it's opt-in via ASAN_OPTIONS."

echo ""
echo "============================================"
echo " D. Stack use after scope"
echo "============================================"
run_mode 7 "Stack use after scope"
echo ""
echo "  Key: A variable goes out of { }, but you kept a pointer to it."
echo "  ASan poisons the stack slot when scope ends."
echo "  (Needs -fsanitize-address-use-after-scope at compile time.)"

echo ""
echo "============================================"
echo " E. ASan on existing benchmarks"
echo "============================================"
echo "  You can also run ASan on the other benchmarks to verify"
echo "  they are bug-free. If ASan finds something, it's a real bug!"
echo ""
echo "  Rebuild with ASan and test:"
echo "    g++ -std=c++17 -O0 -g -fsanitize=address -fno-omit-frame-pointer \\"
echo "        -pthread -o build/cache_miss_asan src/phase1/cache_miss.cpp"
echo "    ./build/cache_miss_asan 0 4"
echo ""
echo "    g++ -std=c++17 -O0 -g -fsanitize=address -fno-omit-frame-pointer \\"
echo "        -pthread -o build/false_sharing_asan src/phase1/false_sharing.cpp"
echo "    ./build/false_sharing_asan 1000"

echo ""
echo "====================================================="
echo " ASan Options Reference:"
echo "====================================================="
echo "  ASAN_OPTIONS=detect_leaks=1                  # enable LeakSanitizer"
echo "  ASAN_OPTIONS=detect_stack_use_after_return=1  # detect use-after-return"
echo "  ASAN_OPTIONS=halt_on_error=0                  # don't abort on first error"
echo "  ASAN_OPTIONS=print_stats=1                    # print shadow memory stats"
echo "  ASAN_OPTIONS=check_initialization_order=1     # catch init-order fiasco"
echo ""
echo " Compile flags:"
echo "  -fsanitize=address                     # core ASan"
echo "  -fsanitize-address-use-after-scope     # detect use-after-scope"
echo "  -fsanitize=address,undefined           # ASan + UBSan combo"
echo "  -fno-omit-frame-pointer                # better stack traces"
echo "====================================================="
echo ""
echo " ASan vs Valgrind summary:"
echo "   ASan:     compile-time, ~2x slow,  catches stack+global+heap"
echo "   Valgrind: binary-level, ~20x slow, catches heap only (mostly)"
echo "   Use BOTH in CI: ASan for fast feedback, Valgrind for Helgrind/Massif."
echo "====================================================="
