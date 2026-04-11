#!/bin/bash
# ============================================================================
# VTune Experiment 3: Top-Down Microarchitecture Analysis (TMA)
# ============================================================================
# Goal: THE most important analysis — understand CPU pipeline utilization
#
# The CPU pipeline has 4 categories:
#   ┌─────────────────────────────────────────┐
#   │           Pipeline Slots                │
#   ├──────────┬──────────┬──────┬────────────┤
#   │ Retiring │ Bad Spec │ FE   │ BE Bound   │
#   │ (useful  │ (wasted  │Bound │ (stalled   │
#   │  work)   │  work)   │      │  waiting)  │
#   └──────────┴──────────┴──────┴────────────┘
#
# What each means:
#   Retiring:       Good! CPU is doing useful work
#   Bad Speculation: Branch mispredictions causing pipeline flushes
#   Frontend Bound:  Instruction fetch/decode bottleneck (rare for HFT)
#   Backend Bound:   Memory/execution unit stalls (COMMON for HFT)
#     ├─ Memory Bound:  Waiting for data from cache/DRAM
#     └─ Core Bound:    Not enough execution units
#
# Key insight: This is what separates "script kiddies" from "performance engineers".
#              perf can tell you "it's slow". TMA tells you "it's slow because
#              42% of pipeline slots are stalled waiting for L3 cache."
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/vtune"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " VTune Experiment 3: Top-Down Analysis"
echo "====================================================="

echo ""
echo "--- A. Busy loop (should be high Retiring) ---"
vtune -collect uarch-exploration \
    -result-dir "$RESULT_DIR/topdown_busyloop" \
    -- "$BIN_DIR/busy_loop" 0 500000000

echo ""
echo "--- B. Branch misprediction (should be high Bad Speculation) ---"
vtune -collect uarch-exploration \
    -result-dir "$RESULT_DIR/topdown_branchmiss" \
    -- "$BIN_DIR/busy_loop" 2 500000000

echo ""
echo "--- C. Cache miss (should be high Backend/Memory Bound) ---"
vtune -collect uarch-exploration \
    -result-dir "$RESULT_DIR/topdown_cachemiss" \
    -- "$BIN_DIR/cache_miss" 2 64

echo ""
echo "--- D. Orderbook comparison ---"
vtune -collect uarch-exploration \
    -result-dir "$RESULT_DIR/topdown_orderbook_map" \
    -- "$BIN_DIR/orderbook_bench" 0 2000000

vtune -collect uarch-exploration \
    -result-dir "$RESULT_DIR/topdown_orderbook_arr" \
    -- "$BIN_DIR/orderbook_bench" 1 2000000

echo ""
echo "--- Summary Reports ---"
for dir in "$RESULT_DIR"/topdown_*; do
    name=$(basename "$dir")
    echo ""
    echo "=== $name ==="
    vtune -report summary -r "$dir" 2>&1 | grep -E "(Retiring|Bad Speculation|Frontend Bound|Backend Bound|Memory Bound|Core Bound)" | head -10
done

echo ""
echo "====================================================="
echo " Expected results:"
echo ""
echo " busy_loop:    Retiring ~70-80%, low everything else"
echo " branch_miss:  Bad Speculation ~30-50%"
echo " cache_miss:   Backend Bound ~60-80%, Memory Bound dominant"
echo " orderbook_map: Backend Bound high (pointer chasing in tree)"
echo " orderbook_arr: More Retiring (cache-friendly array)"
echo ""
echo " Questions:"
echo " 1. What is the Retiring % for each experiment?"
echo " 2. For cache_miss, what level of TMA shows 'DRAM Bound'?"
echo " 3. Can you drill into the orderbook to see which"
echo "    function is most Memory Bound?"
echo " 4. How does this correlate with what perf stat showed?"
echo "====================================================="
