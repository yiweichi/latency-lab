#!/bin/bash
# ============================================================================
# Perf Experiment 5: Syscall Cost Analysis
# ============================================================================
# Goal: Measure and compare syscall overhead
#
# What to observe:
#   - getpid() is the lightest syscall (~100-200ns)
#   - clock_gettime with VDSO may not enter kernel at all
#   - read/write to /dev/null still goes through full kernel path
#
# Key insight: Every syscall in the HFT hot path is a latency tax.
#              In production, we use VDSO, io_uring, or kernel bypass.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"

echo "====================================================="
echo " Experiment 5: Syscall Cost Comparison"
echo "====================================================="

ITERS=500000

for MODE in 0 1 2 3 4; do
    echo ""
    echo "--- Mode $MODE ---"
    perf stat -e syscalls:sys_enter_read,syscalls:sys_enter_write,\
syscalls:sys_enter_*,\
cycles,instructions \
        "$BIN_DIR/syscall_storm" "$MODE" "$ITERS" 2>&1
done

echo ""
echo "--- Perf trace (first 100 syscalls of read mode) ---"
timeout 5 perf trace -e read,write "$BIN_DIR/syscall_storm" 2 10000 2>&1 | head -30 || true

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. Which syscall is cheapest? Why?"
echo " 2. Does clock_gettime show up as a real syscall?"
echo "    (on modern Linux, VDSO bypasses kernel)"
echo " 3. What is the IPC during syscall-heavy code?"
echo "    (should be very low — kernel transitions are expensive)"
echo " 4. How does 'mixed compute + syscall' compare to pure compute?"
echo "====================================================="
