#!/bin/bash
# ============================================================================
# Perf Experiment 7: perf top — Live System-Wide Profiling
# ============================================================================
# Goal: See what the ENTIRE SYSTEM is doing right now, in real time
#
# perf top = like `top`, but shows functions sorted by CPU sample count
#
# What to observe:
#   - Which functions across ALL processes consume most CPU
#   - Kernel functions (prefixed with [k]) vs userspace [.]
#   - Press Enter on a function to see its annotated assembly
#
# Key insight: In HFT, you use perf top to check "is anything unexpected
#              eating my CPU?" — kernel threads, IRQ handlers, other processes.
#
# NOTE: perf top is interactive and runs until you press 'q'.
#       This script launches it with some useful presets.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"

echo "====================================================="
echo " Experiment 7: perf top"
echo "====================================================="
echo ""
echo " This experiment runs interactive tools."
echo " Follow the instructions below."
echo ""
echo "====================================================="

echo ""
echo "--- Step 1: Start a workload in background ---"
"$BIN_DIR/busy_loop" 2 2000000000 &
LOOP_PID=$!
"$BIN_DIR/cache_miss" 2 64 &
CACHE_PID=$!

echo "Started busy_loop (pid=$LOOP_PID) and cache_miss (pid=$CACHE_PID)"
echo ""

echo "--- Step 2: Run perf top ---"
echo ""
echo " About to launch perf top. Key controls:"
echo "   - Functions sorted by CPU sample % (updates live)"
echo "   - Press Enter on a function → annotated assembly"
echo "   - Press 'E' to expand/collapse call graph"
echo "   - Press 'P' to show parent caller"
echo "   - Press 'q' to quit"
echo ""
echo " Look for:"
echo "   1. hot_loop_unpredictable — busy_loop mode 2"
echo "   2. random_access — cache_miss mode 2"
echo "   3. Any kernel functions [k] stealing CPU"
echo ""
read -p "Press Enter to launch perf top..."

perf top -g --call-graph dwarf -F 99 || true

# Cleanup
kill $LOOP_PID $CACHE_PID 2>/dev/null || true
wait $LOOP_PID $CACHE_PID 2>/dev/null || true

echo ""
echo "====================================================="
echo " Other useful perf top variations:"
echo "====================================================="
echo ""
echo " # Only show your process:"
echo " perf top -p \$(pgrep busy_loop)"
echo ""
echo " # Track specific event (cache misses instead of cycles):"
echo " perf top -e cache-misses"
echo ""
echo " # Track specific CPU (useful for isolcpus debugging):"
echo " perf top -C 0"
echo ""
echo " # Kernel-only (see what the kernel is doing):"
echo " perf top --kernel"
echo "====================================================="
