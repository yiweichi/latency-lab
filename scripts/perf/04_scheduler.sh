#!/bin/bash
# ============================================================================
# Perf Experiment 4: Scheduler Analysis
# ============================================================================
# Goal: See how the Linux scheduler affects latency
#
# What to observe:
#   - context switch frequency and cost
#   - runqueue delay (time waiting to be scheduled)
#   - who is preempting your process
#
# Key insight: In HFT, context switches are the #1 source of tail latency.
#              Even 1 switch = 2-10us jitter. That's why we use isolcpus.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"

echo "====================================================="
echo " Experiment 4: Scheduler Analysis"
echo "====================================================="

echo ""
echo "--- A. Context switch statistics ---"
perf stat -e context-switches,cpu-migrations,page-faults \
    "$BIN_DIR/context_switch" 0 50000 2>&1

echo ""
echo "--- B. Scheduler recording ---"
echo "(Recording scheduler events for 10 seconds...)"
perf sched record -o ./results/sched.perf.data \
    "$BIN_DIR/context_switch" 3 10000 2>&1 || true

echo ""
echo "--- C. Scheduler latency report ---"
perf sched latency -i ./results/sched.perf.data 2>&1 | head -40 || true

echo ""
echo "--- D. Scheduler summary ---"
perf sched map -i ./results/sched.perf.data 2>&1 | head -60 || true

echo ""
echo "--- E. False sharing context switches ---"
perf stat -e context-switches,cpu-migrations,cache-misses \
    "$BIN_DIR/false_sharing" 100000000 2>&1

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. How many context switches per second in the ping-pong test?"
echo " 2. What is the max scheduling latency reported?"
echo " 3. Which processes preempted your benchmark?"
echo " 4. How do cpu-migrations affect latency?"
echo "====================================================="
