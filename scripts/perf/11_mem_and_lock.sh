#!/bin/bash
# ============================================================================
# Perf Experiment 11: perf mem & perf lock
# ============================================================================
# Goal: Trace individual memory accesses and lock contention
#
# perf mem:  Records memory load/store events with address and latency
#            Shows which memory accesses are slow (L3/DRAM vs L1)
#
# perf lock: Records lock contention (mutex, spinlock, rwlock)
#            Shows which locks are contended and for how long
#
# Key insight:
#   perf mem answers "which specific memory access is slow?"
#   perf lock answers "which lock is my thread waiting on?"
#   Together they cover the two biggest HFT bottlenecks:
#   cache misses and lock contention.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"
RESULT_DIR="./results/perf"
mkdir -p "$RESULT_DIR"

echo "====================================================="
echo " Experiment 11: perf mem"
echo "====================================================="

echo ""
echo "--- A. Record memory loads for cache_miss (sequential) ---"
perf mem record -t load \
    -o "$RESULT_DIR/mem_sequential.data" \
    -- "$BIN_DIR/cache_miss" 0 16 2>&1 || echo "(perf mem not supported on this CPU — skip)"

if [ -f "$RESULT_DIR/mem_sequential.data" ]; then
    echo ""
    echo "--- B. Report: memory access latency breakdown ---"
    perf mem report -i "$RESULT_DIR/mem_sequential.data" \
        --stdio --sort=mem 2>&1 | head -30
fi

echo ""
echo "--- C. Record memory loads for cache_miss (random) ---"
perf mem record -t load \
    -o "$RESULT_DIR/mem_random.data" \
    -- "$BIN_DIR/cache_miss" 2 16 2>&1 || echo "(perf mem not supported — skip)"

if [ -f "$RESULT_DIR/mem_random.data" ]; then
    echo ""
    echo "--- D. Report: you should see more DRAM hits in random ---"
    perf mem report -i "$RESULT_DIR/mem_random.data" \
        --stdio --sort=mem 2>&1 | head -30
fi

echo ""
echo "====================================================="
echo " Experiment 11b: perf lock"
echo "====================================================="

echo ""
echo "--- E. Record lock contention during context_switch ---"
perf lock record \
    -o "$RESULT_DIR/lock_ctxswitch.data" \
    -- "$BIN_DIR/context_switch" 0 10000 2>&1 || echo "(perf lock not supported — skip)"

if [ -f "$RESULT_DIR/lock_ctxswitch.data" ]; then
    echo ""
    echo "--- F. Lock contention report ---"
    perf lock report -i "$RESULT_DIR/lock_ctxswitch.data" 2>&1 | head -30

    echo ""
    echo "--- G. Lock contention summary ---"
    perf lock contention -i "$RESULT_DIR/lock_ctxswitch.data" 2>&1 | head -30 || true
fi

echo ""
echo "====================================================="
echo " How to read perf mem output:"
echo "====================================================="
echo ""
echo " Memory access breakdown columns:"
echo "   L1 hit:       ~4 cycles    (fastest)"
echo "   L2 hit:       ~12 cycles"
echo "   L3 hit:       ~30-40 cycles"
echo "   Local DRAM:   ~100-200 cycles"
echo "   Remote DRAM:  ~200-400 cycles (NUMA, worst case)"
echo ""
echo " Sequential access: mostly L1/L2 hits (prefetcher works)"
echo " Random access:     lots of L3/DRAM hits (prefetcher useless)"
echo ""
echo " How to read perf lock output:"
echo "   Name:          lock name (kernel or user)"
echo "   Acquired:      how many times the lock was taken"
echo "   Contended:     how many times a thread had to wait"
echo "   Avg Wait:      average wait time when contended"
echo "   Total Wait:    cumulative wait time"
echo ""
echo " High contention + high avg wait = scalability bottleneck"
echo "====================================================="
