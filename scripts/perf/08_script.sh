#!/bin/bash
# ============================================================================
# Perf Experiment 8: perf script — Raw Event Dump & Custom Analysis
# ============================================================================
# Goal: Extract raw perf samples for custom post-processing
#
# perf record → perf.data (binary)
# perf report → aggregated view (interactive)
# perf script → raw text dump (one line per sample, pipeable)
#
# What to observe:
#   - Each sample: timestamp, pid, cpu, event, call stack
#   - You can pipe to awk/grep/python for custom analysis
#   - This is the input format for FlameGraph tools
#
# Key insight: perf script is the "escape hatch" — when perf report
#              doesn't show what you need, dump raw data and write
#              your own analysis. HFT teams build dashboards on this.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/perf"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " Experiment 8: perf script"
echo "====================================================="

echo ""
echo "--- A. Record with context switches ---"
perf record -e cycles,context-switches -g --call-graph dwarf \
    -o "$RESULT_DIR/script_demo.data" \
    -- "$BIN_DIR/context_switch" 3 10000

echo ""
echo "--- B. Raw dump (first 30 lines) ---"
echo "Each line = one sample: comm, pid, cpu, timestamp, event, ip, symbol"
perf script -i "$RESULT_DIR/script_demo.data" 2>&1 | head -30

echo ""
echo "--- C. Custom fields ---"
echo "Only show: timestamp, event, symbol"
perf script -i "$RESULT_DIR/script_demo.data" \
    -F comm,tid,time,event,sym 2>&1 | head -20

echo ""
echo "--- D. Filter context switches only ---"
perf script -i "$RESULT_DIR/script_demo.data" 2>&1 | \
    grep "context-switches" | head -20

echo ""
echo "--- E. Count samples per function ---"
echo "Top 10 hottest functions:"
perf script -i "$RESULT_DIR/script_demo.data" 2>&1 | \
    awk '/^\s+[0-9a-f]+ / {print $2}' | sort | uniq -c | sort -rn | head -10

echo ""
echo "--- F. Record orderbook with timestamps ---"
perf record -e cycles -g --call-graph dwarf --timestamp \
    -o "$RESULT_DIR/script_orderbook.data" \
    -- "$BIN_DIR/orderbook_bench" 0 1000000

echo ""
echo "--- G. Extract per-sample timestamps (for latency timeline) ---"
perf script -i "$RESULT_DIR/script_orderbook.data" \
    -F time,sym 2>&1 | head -20

echo ""
echo "====================================================="
echo " Useful perf script patterns:"
echo "====================================================="
echo ""
echo " # Flame graph pipeline (most common use):"
echo " perf script | stackcollapse-perf.pl | flamegraph.pl > out.svg"
echo ""
echo " # Find all context switches with call stacks:"
echo " perf script | grep -B10 'context-switches'"
echo ""
echo " # Extract timestamps for jitter analysis:"
echo " perf script -F time | awk '{print \$1}' > timestamps.txt"
echo ""
echo " # Python post-processing:"
echo " perf script -F time,event,sym | python3 analyze.py"
echo "====================================================="
