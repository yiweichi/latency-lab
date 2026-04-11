#!/bin/bash
# ============================================================================
# Ftrace Experiment 4: IRQ and Softirq Tracing
# ============================================================================
# Goal: See hardware and software interrupts that steal CPU time
#
# What to observe:
#   - irq_handler_entry/exit: hardware interrupt handler execution
#   - softirq_entry/exit: deferred interrupt processing
#   - Which interrupts are most frequent?
#   - How long do they take?
#
# Key insight: In HFT, interrupts are "invisible" latency thieves.
#              Network interrupts (softirq) are especially dangerous because
#              they run on the same CPU as your trading process.
#              This is why HFT firms use interrupt affinity + isolcpus.
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
echo " Ftrace Experiment 4: IRQ Tracing"
echo "====================================================="

# Reset
echo 0 > "$TRACE_DIR/tracing_on"
echo > "$TRACE_DIR/trace"
echo nop > "$TRACE_DIR/current_tracer"

# Enable IRQ events
echo 0 > "$TRACE_DIR/events/enable"
echo 1 > "$TRACE_DIR/events/irq/irq_handler_entry/enable"
echo 1 > "$TRACE_DIR/events/irq/irq_handler_exit/enable"
echo 1 > "$TRACE_DIR/events/irq/softirq_entry/enable"
echo 1 > "$TRACE_DIR/events/irq/softirq_exit/enable"

# Trace for a few seconds
echo 1 > "$TRACE_DIR/tracing_on"

echo "Running busy loop while tracing IRQs (3 seconds)..."
timeout 3 "$BIN_DIR/busy_loop" 0 2000000000 || true

echo 0 > "$TRACE_DIR/tracing_on"

mkdir -p ./results/ftrace
cp "$TRACE_DIR/trace" ./results/ftrace/irq_trace.txt

echo ""
echo "--- Hardware IRQ summary ---"
grep "irq_handler_entry" ./results/ftrace/irq_trace.txt | \
    awk '{print $NF}' | sort | uniq -c | sort -rn | head -10

echo ""
echo "--- Software IRQ summary ---"
grep "softirq_entry" ./results/ftrace/irq_trace.txt | \
    awk -F'vec=' '{print $2}' | sort | uniq -c | sort -rn | head -10 || echo "(none visible)"

echo ""
echo "--- Sample IRQ events ---"
grep "irq_handler" ./results/ftrace/irq_trace.txt | head -20

# Cleanup
echo 0 > "$TRACE_DIR/events/irq/irq_handler_entry/enable"
echo 0 > "$TRACE_DIR/events/irq/irq_handler_exit/enable"
echo 0 > "$TRACE_DIR/events/irq/softirq_entry/enable"
echo 0 > "$TRACE_DIR/events/irq/softirq_exit/enable"

echo ""
echo "Full trace saved to: ./results/ftrace/irq_trace.txt"
echo ""
echo "====================================================="
echo " Softirq vectors (for reference):"
echo "   0=HI, 1=TIMER, 2=NET_TX, 3=NET_RX"
echo "   4=BLOCK, 5=IRQ_POLL, 6=TASKLET"
echo "   7=SCHED, 8=HRTIMER, 9=RCU"
echo ""
echo " Questions:"
echo " 1. Which IRQ fires most often? (usually timer)"
echo " 2. How often does NET_RX softirq fire?"
echo " 3. What is the longest IRQ handler duration?"
echo " 4. How would you isolate your trading CPU from IRQs?"
echo "    (hint: /proc/irq/*/smp_affinity + isolcpus)"
echo "====================================================="
