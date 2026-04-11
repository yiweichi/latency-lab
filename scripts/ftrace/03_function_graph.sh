#!/bin/bash
# ============================================================================
# Ftrace Experiment 3: Function Graph Tracer
# ============================================================================
# Goal: See the kernel call graph with timing for each function
#
# What to observe:
#   - Kernel function call tree with entry/exit times
#   - Which kernel functions are called during a syscall
#   - How deep the kernel call stack goes
#
# Key insight: This is like a "kernel debugger" without stopping the system.
#              You can see exactly what the kernel does for each syscall.
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
echo " Ftrace Experiment 3: Function Graph Tracer"
echo "====================================================="

# Reset
echo 0 > "$TRACE_DIR/tracing_on"
echo > "$TRACE_DIR/trace"

# Use function_graph tracer
echo function_graph > "$TRACE_DIR/current_tracer"

# Set max depth to avoid overwhelming output
echo 5 > "$TRACE_DIR/max_graph_depth"

# Filter to specific functions (syscall paths)
echo "Setting up function filters..."
echo > "$TRACE_DIR/set_ftrace_filter"
echo 'ksys_read' >> "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || true
echo 'ksys_write' >> "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || true
echo 'do_sys_open*' >> "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || true
echo '__x64_sys_read' >> "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || true
echo '__x64_sys_write' >> "$TRACE_DIR/set_ftrace_filter" 2>/dev/null || true

# Trace our program
echo 1 > "$TRACE_DIR/tracing_on"

"$BIN_DIR/syscall_storm" 3 100  # write to /dev/null, 100 iterations

echo 0 > "$TRACE_DIR/tracing_on"

mkdir -p ./results/ftrace
cp "$TRACE_DIR/trace" ./results/ftrace/function_graph.txt

echo ""
echo "--- Function graph output (first 80 lines) ---"
head -80 ./results/ftrace/function_graph.txt

# Cleanup
echo nop > "$TRACE_DIR/current_tracer"
echo > "$TRACE_DIR/set_ftrace_filter"
echo 10 > "$TRACE_DIR/max_graph_depth" 2>/dev/null || true

echo ""
echo "Full trace saved to: ./results/ftrace/function_graph.txt"
echo ""
echo "====================================================="
echo " What you're seeing:"
echo "====================================================="
echo " The indented tree shows kernel function calls."
echo " The time on the left is the duration of each function."
echo " For example:"
echo "   | ksys_write() {"
echo "   |   vfs_write() {"
echo "   |     __vfs_write() {"
echo "   |       devnull_write();"
echo "   |     } /* __vfs_write */  0.123 us"
echo "   |   } /* vfs_write */  0.456 us"
echo "   | } /* ksys_write */  0.789 us"
echo ""
echo " Questions:"
echo " 1. How deep is the kernel call stack for write()?"
echo " 2. Which function takes the most time?"
echo " 3. How does this compare to read() time?"
echo "====================================================="
