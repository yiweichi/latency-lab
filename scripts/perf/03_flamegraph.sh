#!/bin/bash
# ============================================================================
# Perf Experiment 3: Flame Graph Generation
# ============================================================================
# Goal: Visualize where CPU time is spent using flame graphs
#
# Prerequisites:
#   git clone https://github.com/brendangregg/FlameGraph.git /tmp/FlameGraph
#
# What to observe:
#   - The "width" of each function = % of CPU time
#   - The "stack depth" = call chain
#   - For orderbook: map version has wider std::map internals
#
# Key insight: Flame graphs show you WHERE the CPU is stalled,
#              perf stat tells you WHY (cache miss, branch miss, etc.)
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
FLAMEGRAPH_DIR="${FLAMEGRAPH_DIR:-/tmp/FlameGraph}"
OUTPUT_DIR="./results/flamegraphs"
mkdir -p "$OUTPUT_DIR"

# Check for FlameGraph tools
if [ ! -f "$FLAMEGRAPH_DIR/flamegraph.pl" ]; then
    echo "FlameGraph tools not found. Installing..."
    git clone https://github.com/brendangregg/FlameGraph.git "$FLAMEGRAPH_DIR"
fi

echo "====================================================="
echo " Experiment 3: Flame Graph Generation"
echo "====================================================="

generate_flamegraph() {
    local name="$1"
    local cmd="$2"
    local freq="${3:-99}"

    echo ""
    echo "--- Generating: $name ---"

    perf record -F "$freq" -g --call-graph dwarf -o "$OUTPUT_DIR/$name.perf.data" -- $cmd
    perf script -i "$OUTPUT_DIR/$name.perf.data" > "$OUTPUT_DIR/$name.perf.script"
    "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" "$OUTPUT_DIR/$name.perf.script" > "$OUTPUT_DIR/$name.folded"
    "$FLAMEGRAPH_DIR/flamegraph.pl" "$OUTPUT_DIR/$name.folded" > "$OUTPUT_DIR/$name.svg"

    echo "  -> $OUTPUT_DIR/$name.svg"
}

# Generate flame graphs for each experiment
generate_flamegraph "busy_loop_predictable" "$BIN_DIR/busy_loop 0 500000000"
generate_flamegraph "busy_loop_unpredictable" "$BIN_DIR/busy_loop 2 500000000"
generate_flamegraph "cache_miss_sequential" "$BIN_DIR/cache_miss 0 64"
generate_flamegraph "cache_miss_random" "$BIN_DIR/cache_miss 2 64"
generate_flamegraph "orderbook_map" "$BIN_DIR/orderbook_bench 0 2000000"
generate_flamegraph "orderbook_array" "$BIN_DIR/orderbook_bench 1 2000000"

echo ""
echo "====================================================="
echo " All flame graphs saved to: $OUTPUT_DIR/"
echo " Open the .svg files in a browser to interact"
echo "====================================================="
echo ""
echo " Questions to answer:"
echo " 1. In orderbook_map.svg, how much time is in std::map?"
echo " 2. In orderbook_array.svg, what is the dominant function?"
echo " 3. Compare the two: which has a 'wider' hot path?"
echo " 4. In cache_miss_random.svg, do you see time in kernel?"
echo "    (page faults during initial allocation)"
echo "====================================================="
