#!/bin/bash
# ============================================================================
# Ftrace Experiment 2: Scheduler Tracing
# ============================================================================
# Goal: See exactly when and why your process is scheduled/preempted
#
# What to observe:
#   - sched_switch: who replaced your process on the CPU
#   - sched_wakeup: when your process was woken up
#   - sched_migrate_task: when your process was moved to a different CPU
#
# Key insight: Every sched_switch = potential latency spike in HFT.
#              You need to see WHO preempted you and WHY.
#
# REQUIRES: root privileges
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
TRACE_DIR="/sys/kernel/tracing"

if [ ! -d "$TRACE_DIR" ]; then
    TRACE_DIR="/sys/kernel/debug/tracing"
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script requires root privileges"
    echo "Usage: sudo $0 [build_dir]"
    exit 1
fi

echo "====================================================="
echo " Ftrace Experiment 2: Scheduler Tracing"
echo "====================================================="

# Reset
echo 0 > "$TRACE_DIR/tracing_on"
echo > "$TRACE_DIR/trace"
echo nop > "$TRACE_DIR/current_tracer"

# Enable scheduler events
echo 0 > "$TRACE_DIR/events/enable"
echo 1 > "$TRACE_DIR/events/sched/sched_switch/enable"
echo 1 > "$TRACE_DIR/events/sched/sched_wakeup/enable"
echo 1 > "$TRACE_DIR/events/sched/sched_migrate_task/enable"

# Start tracing
echo 1 > "$TRACE_DIR/tracing_on"

echo "Running context switch benchmark..."
"$BIN_DIR/context_switch" 0 5000

echo 0 > "$TRACE_DIR/tracing_on"

mkdir -p ./results/ftrace
cp "$TRACE_DIR/trace" ./results/ftrace/sched_trace.txt

echo ""
echo "--- Sample sched_switch events ---"
grep "sched_switch" ./results/ftrace/sched_trace.txt | head -20

echo ""
echo "--- Process migration events ---"
grep "sched_migrate" ./results/ftrace/sched_trace.txt | head -10 || echo "(none)"

echo ""
echo "--- Context switch count ---"
grep -c "sched_switch" ./results/ftrace/sched_trace.txt || echo "0"

# Cleanup
echo 0 > "$TRACE_DIR/events/sched/sched_switch/enable"
echo 0 > "$TRACE_DIR/events/sched/sched_wakeup/enable"
echo 0 > "$TRACE_DIR/events/sched/sched_migrate_task/enable"

echo ""
echo "Full trace saved to: ./results/ftrace/sched_trace.txt"
echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. Look at sched_switch: what is 'prev_state'?"
echo "    S=sleeping, R=running, D=uninterruptible"
echo " 2. Who is 'next_comm'? (who took your CPU)"
echo " 3. How many migrations happened?"
echo "    (In HFT, migrations = cold cache = latency spike)"
echo " 4. What is the time gap between wakeup and sched_switch?"
echo "    (This is the 'runqueue delay' — scheduling latency)"
echo "====================================================="
