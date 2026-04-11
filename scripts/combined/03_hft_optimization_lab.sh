#!/bin/bash
# ============================================================================
# Combined Experiment 3: HFT Optimization Lab
# ============================================================================
# Goal: Apply all profiling knowledge to optimize a realistic HFT scenario
#
# Steps:
#   1. Profile the orderbook with all tools
#   2. Identify the bottleneck
#   3. Apply optimization (map -> array)
#   4. Verify improvement with profiling
#   5. Apply system tuning
#   6. Final comparison
#
# This is the "capstone" exercise.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/optimization_lab"
mkdir -p "$RESULT_DIR"

echo "============================================================"
echo " HFT Optimization Lab"
echo "============================================================"

echo ""
echo "========================================="
echo " Phase 1: Baseline Profiling"
echo "========================================="
echo ""

echo "--- OrderBook Map (unoptimized) ---"
perf stat -e cycles,instructions,cache-misses,branch-misses,L1-dcache-load-misses \
    "$BIN_DIR/orderbook_bench" 0 3000000 2>&1 | tee "$RESULT_DIR/map_perf.txt"

echo ""
echo "--- OrderBook Array (optimized) ---"
perf stat -e cycles,instructions,cache-misses,branch-misses,L1-dcache-load-misses \
    "$BIN_DIR/orderbook_bench" 1 3000000 2>&1 | tee "$RESULT_DIR/array_perf.txt"

echo ""
echo "========================================="
echo " Phase 2: Head-to-Head Comparison"
echo "========================================="
echo ""
$BIN_DIR/orderbook_bench 2 3000000 | tee "$RESULT_DIR/comparison.txt"

echo ""
echo "========================================="
echo " Phase 3: CPU Pinning Effect"
echo "========================================="
echo ""

# Without CPU pinning
echo "--- Without taskset ---"
perf stat -e context-switches,cpu-migrations,cache-misses \
    "$BIN_DIR/orderbook_bench" 0 3000000 2>&1 | tee "$RESULT_DIR/no_pin.txt"

echo ""
echo "--- With taskset (pinned to CPU 0) ---"
perf stat -e context-switches,cpu-migrations,cache-misses \
    taskset -c 0 "$BIN_DIR/orderbook_bench" 0 3000000 2>&1 | tee "$RESULT_DIR/pinned.txt"

echo ""
echo "========================================="
echo " Phase 4: System Tuning Checklist"
echo "========================================="
echo ""
echo "The following optimizations are used in production HFT:"
echo ""
echo "1. CPU Isolation (requires kernel boot param):"
echo "   GRUB_CMDLINE_LINUX=\"isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3\""
echo ""
echo "2. IRQ Affinity (move interrupts away from trading CPUs):"
echo "   for irq in /proc/irq/*/smp_affinity; do"
echo "     echo 1 > \$irq  # pin all IRQs to CPU 0"
echo "   done"
echo ""
echo "3. Disable frequency scaling:"
echo "   cpupower frequency-set -g performance"
echo ""
echo "4. Disable transparent huge pages:"
echo "   echo never > /sys/kernel/mm/transparent_hugepage/enabled"
echo ""
echo "5. Process priority:"
echo "   chrt -f 99 taskset -c 2 ./orderbook_bench 1"
echo ""
echo "6. Memory locking:"
echo "   Add mlockall(MCL_CURRENT|MCL_FUTURE) at program start"
echo ""

echo "========================================="
echo " Results saved to: $RESULT_DIR/"
echo "========================================="
echo ""
echo " Final exercise:"
echo " 1. Compare map_perf.txt vs array_perf.txt"
echo "    -> How much did cache misses decrease?"
echo " 2. Compare no_pin.txt vs pinned.txt"
echo "    -> How many cpu-migrations were eliminated?"
echo " 3. Run VTune top-down on both:"
echo "    -> What is the Memory Bound % difference?"
echo "============================================================"
