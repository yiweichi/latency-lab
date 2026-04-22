#!/bin/bash
# ============================================================================
# Combined Experiment 2: Latency Spike Hunting
# ============================================================================
# Goal: Introduce interference, then use all tools to find the cause
#
# Scenario:
#   Your orderbook benchmark runs fine in isolation.
#   But when "noisy neighbors" appear, p99 latency spikes.
#   Your job: find and explain the spike using the tools.
#
# This simulates a real HFT debugging session.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/spike_hunt"
mkdir -p "$RESULT_DIR"

echo "============================================================"
echo " Latency Spike Hunting Exercise"
echo "============================================================"

echo ""
echo "Step 1: Baseline (clean run)"
echo "---"
$BIN_DIR/orderbook_bench 0 2000000 1 | tee "$RESULT_DIR/baseline.txt"

echo ""
echo "Step 2: Run with interference"
echo "---"
echo "Starting background load..."

# Create interference: CPU contention + memory pressure + I/O
stress-ng --cpu 4 --vm 2 --vm-bytes 256M --io 2 --timeout 30s &
STRESS_PID=$!

sleep 2  # Let stress stabilize

echo "Running benchmark under load..."
$BIN_DIR/orderbook_bench 0 2000000 1 | tee "$RESULT_DIR/under_load.txt"

# Collect perf data under load
perf stat -e cycles,instructions,cache-misses,context-switches,cpu-migrations \
    $BIN_DIR/orderbook_bench 0 2000000 1 2>&1 | tee "$RESULT_DIR/perf_under_load.txt"

echo ""
echo "Step 3: Perf sched under load"
echo "---"
perf sched record -o "$RESULT_DIR/sched.data" \
    -- $BIN_DIR/orderbook_bench 0 1000000 2>&1 || true

perf sched latency -i "$RESULT_DIR/sched.data" 2>&1 | \
    head -30 | tee "$RESULT_DIR/sched_latency.txt" || true

# Kill stress
kill $STRESS_PID 2>/dev/null || true
wait $STRESS_PID 2>/dev/null || true

echo ""
echo "============================================================"
echo " Analysis Guide:"
echo "============================================================"
echo ""
echo " Compare baseline.txt vs under_load.txt:"
echo " 1. How much did p99 increase?"
echo " 2. How much did mean increase?"
echo ""
echo " Look at perf_under_load.txt:"
echo " 3. How many context switches? (should be much higher)"
echo " 4. How many cpu-migrations?"
echo " 5. How does IPC compare to baseline?"
echo ""
echo " For deeper analysis, run these manually:"
echo ""
echo " # bpftrace (in another terminal, as root):"
echo " sudo bpftrace scripts/bpftrace/02_sched_snoop.bt"
echo ""
echo " # Then re-run with load:"
echo " stress-ng --cpu 4 --timeout 30s &"
echo " ./build/orderbook_bench 0 2000000"
echo ""
echo " # ftrace (as root):"
echo " sudo scripts/ftrace/02_sched_trace.sh"
echo ""
echo " # Look for:"
echo "   - Who preempted your process (sched_switch next_comm)"
echo "   - Migration events (cpu migration = cache cold)"
echo "   - Runqueue delay distribution"
echo "============================================================"
