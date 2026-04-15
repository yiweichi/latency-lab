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
#
# Section G: /proc/<pid>/maps, pmap, smaps — inspect virtual address space
#            (correlate brk/mmap from perf trace with [heap], libc, vdso).
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
echo "--- G. Process virtual memory layout (maps / pmap / smaps) ---"
echo "Use these while the target process is RUNNING (replace <pid>)."
echo ""
echo "  cat /proc/<pid>/maps          # all VMAs: start-end perms offset path"
echo "  pmap -x <pid>                 # human-readable sizes + RSS"
echo "  head -200 /proc/<pid>/smaps   # per-mapping RSS/PSS (physical memory)"
echo "  readelf -l ./binary           # ELF LOAD segments (pre-run; ASLR shifts runtime base)"
echo ""
echo "Demo: snapshot of a sleeping process (always works):"
SLEEP_SEC=60
sleep "$SLEEP_SEC" &
DEMO_PID=$!
sleep 0.05
echo "  PID=$DEMO_PID (sleep $SLEEP_SEC s) — first lines of /proc/PID/maps:"
head -40 "/proc/$DEMO_PID/maps" 2>/dev/null || true
echo ""
echo "  pmap -x $DEMO_PID (first rows):"
pmap -x "$DEMO_PID" 2>/dev/null | head -30 || true
kill "$DEMO_PID" 2>/dev/null || true
wait "$DEMO_PID" 2>/dev/null || true

echo ""
echo "Optional: syscall_storm still running? (large read loop in background)"
"$BIN_DIR/syscall_storm" 2 500000000 &
STORM_PID=$!
sleep 0.15
if kill -0 "$STORM_PID" 2>/dev/null; then
    echo "  PID=$STORM_PID — maps excerpt (heap, stack, libc, vdso):"
    grep -E '\[heap\]|\[stack\]|libc|vdso|vvar|syscall_storm' "/proc/$STORM_PID/maps" 2>/dev/null || head -25 "/proc/$STORM_PID/maps"
else
    echo "  (process already exited; use larger iterations or sleep demo above)"
fi
wait "$STORM_PID" 2>/dev/null || true

echo ""
echo "====================================================="
echo " Questions (memory layout):"
echo "====================================================="
echo " 1. Where is [heap] relative to the binary and libc mappings?"
echo " 2. What does brk() return value correspond to in /proc/<pid>/maps?"
echo " 3. Why does pmap RSS not equal sum of all virtual sizes?"
echo "====================================================="

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
