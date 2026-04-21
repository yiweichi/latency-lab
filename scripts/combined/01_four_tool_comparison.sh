#!/bin/bash
# ============================================================================
# Combined Experiment 1: Four-Tool Comparison on Same Program
# ============================================================================
# Goal: Run the SAME experiment through all 4 tools and compare results
#
# This is the "aha moment" exercise:
#   - perf tells you WHAT is slow (cache misses, branch misses)
#   - ftrace tells you WHAT the kernel is doing
#   - bpftrace tells you the DISTRIBUTION of latencies
#   - VTune tells you WHY at the microarchitecture level
#
# Run this after completing individual tool experiments.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/combined"
mkdir -p "$RESULT_DIR"

PROGRAM="$BIN_DIR/orderbook_bench"
ARGS=" "  # map-based orderbook, 2M operations

echo "============================================================"
echo " Four-Tool Comparison: OrderBook (map-based)"
echo " Program: $PROGRAM $ARGS"
echo "============================================================"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║ Tool 1: perf stat — Hardware performance counters       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
perf stat \
  -e 'L1-dcache-loads,L1-dcache-load-misses,l2_rqsts.references,l2_rqsts.miss,LLC-loads,LLC-load-misses' \
  -- $PROGRAM $ARGS 2>&1 | tee "$RESULT_DIR/perf_stat.txt"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║ Tool 2: perf record + report — Sampling profiler        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
perf record -F 999 -g --call-graph dwarf -o "$RESULT_DIR/perf.data" \
    -- $PROGRAM $ARGS 2>&1
perf report -i "$RESULT_DIR/perf.data" --stdio --no-children 2>&1 | \
    head -40 | tee "$RESULT_DIR/perf_report.txt"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║ Tool 3: VTune — Microarchitecture analysis              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
vtune -collect uarch-exploration \
    -result-dir "$RESULT_DIR/vtune_topdown" \
    -- $PROGRAM $ARGS 2>&1 || echo "(VTune not available — skip)"

if [ -d "$RESULT_DIR/vtune_topdown" ]; then
    vtune -report summary -r "$RESULT_DIR/vtune_topdown" 2>&1 | \
        tee "$RESULT_DIR/vtune_summary.txt"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║ Summary: What each tool reveals                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  perf stat:    Raw counters — IPC, cache miss rate, branch miss rate"
echo "  perf record:  WHERE time is spent (which functions)"
echo "  ftrace:       Kernel-side view (run ftrace scripts with sudo)"
echo "  bpftrace:     Dynamic latency distributions (run .bt scripts with sudo)"
echo "  VTune:        WHY it's slow (pipeline stall breakdown)"
echo ""
echo "  Now run the SAME experiment on orderbook_bench mode 1 (array-based)"
echo "  and compare the results!"
echo ""
echo "============================================================"
echo " Next: $0 but with args '1 2000000' for array-based orderbook"
echo "============================================================"
