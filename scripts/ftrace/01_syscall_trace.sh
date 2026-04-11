#!/bin/bash
# ============================================================================
# Ftrace Experiment 1: Syscall Tracing
# ============================================================================
# Goal: See the kernel's view of every syscall your program makes
#
# What to observe:
#   - Each syscall entry/exit with precise timestamps
#   - The kernel functions called during each syscall
#   - Time spent inside the kernel
#
# Key insight: ftrace is the kernel's built-in tracer.
#              Unlike perf (sampling), ftrace gives you EVERY event.
#              This makes it perfect for understanding kernel behavior.
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
echo " Ftrace Experiment 1: Syscall Tracing"
echo "====================================================="

# Reset ftrace state
echo 0 > "$TRACE_DIR/tracing_on"
echo > "$TRACE_DIR/trace"
echo nop > "$TRACE_DIR/current_tracer"

# Enable syscall events
echo "Setting up syscall tracepoints..."
echo 0 > "$TRACE_DIR/events/enable"
echo 1 > "$TRACE_DIR/events/syscalls/sys_enter_read/enable"
echo 1 > "$TRACE_DIR/events/syscalls/sys_exit_read/enable"
echo 1 > "$TRACE_DIR/events/syscalls/sys_enter_write/enable"
echo 1 > "$TRACE_DIR/events/syscalls/sys_exit_write/enable"
echo 1 > "$TRACE_DIR/events/syscalls/sys_enter_openat/enable"
echo 1 > "$TRACE_DIR/events/syscalls/sys_exit_openat/enable"

# Filter to only our process
echo "Starting trace..."
echo 1 > "$TRACE_DIR/tracing_on"

# Run the program (short burst)
"$BIN_DIR/syscall_storm" 2 1000 &
PROG_PID=$!

# Write PID filter (if supported)
echo "$PROG_PID" > "$TRACE_DIR/set_ftrace_pid" 2>/dev/null || true

wait $PROG_PID

echo 0 > "$TRACE_DIR/tracing_on"

# Save output
mkdir -p ./results/ftrace
cp "$TRACE_DIR/trace" ./results/ftrace/syscall_trace.txt

echo ""
echo "--- First 50 lines of trace ---"
head -50 ./results/ftrace/syscall_trace.txt

echo ""
echo "--- Syscall count ---"
grep -c "sys_enter" ./results/ftrace/syscall_trace.txt || echo "0"

# Cleanup
echo 0 > "$TRACE_DIR/events/syscalls/sys_enter_read/enable"
echo 0 > "$TRACE_DIR/events/syscalls/sys_exit_read/enable"
echo 0 > "$TRACE_DIR/events/syscalls/sys_enter_write/enable"
echo 0 > "$TRACE_DIR/events/syscalls/sys_exit_write/enable"
echo 0 > "$TRACE_DIR/events/syscalls/sys_enter_openat/enable"
echo 0 > "$TRACE_DIR/events/syscalls/sys_exit_openat/enable"

echo ""
echo "Full trace saved to: ./results/ftrace/syscall_trace.txt"
echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. What is the timestamp difference between"
echo "    sys_enter_read and sys_exit_read? (= kernel time)"
echo " 2. Are there any unexpected syscalls?"
echo " 3. What is the pattern of syscalls?"
echo "====================================================="
