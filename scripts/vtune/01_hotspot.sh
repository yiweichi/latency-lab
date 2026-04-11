#!/bin/bash
# ============================================================================
# VTune Experiment 1: Hotspot Analysis
# ============================================================================
# Goal: Find where CPU time is spent — VTune's most basic analysis
#
# What to observe:
#   - Top functions by CPU time (like perf report, but richer)
#   - Source-level annotation showing hot lines
#   - Call tree with time attribution
#
# Prerequisites:
#   source /opt/intel/oneapi/setvars.sh
#   (or wherever VTune is installed)
#
# Key insight: VTune gives you the same data as `perf record` but with
#              a much better GUI and source-level annotation.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/vtune"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " VTune Experiment 1: Hotspot Analysis"
echo "====================================================="

echo ""
echo "--- A. Busy loop hotspot ---"
vtune -collect hotspots \
    -knob sampling-mode=hw \
    -result-dir "$RESULT_DIR/hotspot_busyloop" \
    -- "$BIN_DIR/busy_loop" 2 500000000

echo ""
echo "--- B. Cache miss hotspot ---"
vtune -collect hotspots \
    -knob sampling-mode=hw \
    -result-dir "$RESULT_DIR/hotspot_cachemiss" \
    -- "$BIN_DIR/cache_miss" 2 64

echo ""
echo "--- C. Orderbook hotspot ---"
vtune -collect hotspots \
    -knob sampling-mode=hw \
    -result-dir "$RESULT_DIR/hotspot_orderbook" \
    -- "$BIN_DIR/orderbook_bench" 2 2000000

echo ""
echo "--- Generating reports ---"
for dir in "$RESULT_DIR"/hotspot_*; do
    name=$(basename "$dir")
    echo ""
    echo "=== $name ==="
    vtune -report hotspots -r "$dir" 2>&1 | head -30
done

echo ""
echo "====================================================="
echo " To open the GUI:"
echo "   vtune-gui $RESULT_DIR/hotspot_orderbook"
echo ""
echo " Questions:"
echo " 1. Which function consumes the most CPU time?"
echo " 2. In orderbook: map vs array, where is the hotspot?"
echo " 3. Can you see the hot source lines?"
echo "====================================================="
