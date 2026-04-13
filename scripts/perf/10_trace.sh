#!/bin/bash
# ============================================================================
# Perf Experiment 10: perf trace — Syscall Tracer (strace on steroids)
# ============================================================================
# Goal: Trace all syscalls with nanosecond timestamps and low overhead
#
# perf trace ≈ strace, but:
#   - Much lower overhead (uses perf infrastructure, not ptrace)
#   - Shows duration of each syscall
#   - Can filter by syscall type
#   - Can combine with perf record events
#
# What to observe:
#   - Which syscalls your program makes
#   - How long each syscall takes
#   - Unexpected syscalls in the hot path
#
# Key insight: In HFT, perf trace is how you verify "zero syscalls in hot path".
#              Even one syscall in the critical path = microseconds of latency.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/perf"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " Experiment 10: perf trace"
echo "====================================================="

echo ""
echo "--- A. Full syscall trace of syscall_storm (read mode, 1000 calls) ---"
echo "Each line shows: timestamp, duration, syscall name, args, return value"
perf trace -- "$BIN_DIR/syscall_storm" 2 1000 2>&1 | head -30

echo ""
echo "--- B. Summary mode: syscall count and average duration ---"
perf trace -s -- "$BIN_DIR/syscall_storm" 2 10000 2>&1

echo ""
echo "--- C. Filter specific syscalls only ---"
echo "Only show read and write:"
perf trace -e read,write -- "$BIN_DIR/syscall_storm" 2 1000 2>&1 | head -20

echo ""
echo "--- D. Trace the orderbook (should have NO syscalls in hot path) ---"
echo "If you see syscalls during the benchmark, something is wrong."
perf trace -s -- "$BIN_DIR/orderbook_bench" 0 1000000 2>&1

echo ""
echo "--- E. Compare syscall overhead: getpid vs read vs write ---"
for MODE in 0 2 3; do
    echo ""
    echo "Mode $MODE:"
    perf trace -s -- "$BIN_DIR/syscall_storm" "$MODE" 10000 2>&1 | \
        grep -E "syscall|msec" | head -5
done

echo ""
echo "--- F. Trace with timestamps (for finding latency spikes) ---"
perf trace -T -- "$BIN_DIR/syscall_storm" 3 100 2>&1 | head -20

echo ""
echo "====================================================="
echo " perf trace vs strace:"
echo "====================================================="
echo ""
echo "   strace:     uses ptrace, ~100x overhead, stops the process"
echo "   perf trace: uses perf events, ~2-5x overhead, no ptrace"
echo ""
echo " In HFT, NEVER use strace on a production process."
echo " Always use perf trace (or bpftrace) instead."
echo ""
echo " Useful variations:"
echo "   perf trace -p PID              # attach to running process"
echo "   perf trace -e open,close       # filter syscall types"
echo "   perf trace -s                  # summary statistics"
echo "   perf trace --duration 10       # only show syscalls > 10ms"
echo "   perf trace -T                  # show absolute timestamps"
echo "====================================================="
