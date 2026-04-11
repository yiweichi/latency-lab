#!/bin/bash
# ============================================================================
# Perf Experiment 2: Cache Hierarchy Deep Dive
# ============================================================================
# Goal: Map the entire cache hierarchy through access patterns
#
# What to observe:
#   - As array size grows past L1 (32KB) -> L2 (256KB) -> L3 (several MB),
#     you'll see step-function increases in access latency
#   - perf can count misses at each level
#
# Key insight: In HFT, your hot data MUST fit in L1/L2.
#              If it spills to L3 or DRAM, you lose 10-100x performance.
# ============================================================================

set -e

BIN_DIR="${1:-./build}"

echo "====================================================="
echo " Experiment 2: Cache Hierarchy Exploration"
echo "====================================================="

# Test with increasing array sizes to see cache effects
for SIZE_MB in 1 4 16 64 256; do
    echo ""
    echo "--- Array size: ${SIZE_MB} MB (random access) ---"
    perf stat -e \
        cycles,instructions,\
L1-dcache-loads,L1-dcache-load-misses,\
LLC-loads,LLC-load-misses \
        "$BIN_DIR/cache_miss" 2 "$SIZE_MB" 2>&1
done

echo ""
echo "====================================================="
echo " Experiment 2b: Pointer Chasing (worst case)"
echo "====================================================="

for SIZE_MB in 1 4 16 64; do
    echo ""
    echo "--- Pointer chase: ${SIZE_MB} MB ---"
    perf stat -e cycles,instructions,L1-dcache-load-misses,LLC-load-misses \
        "$BIN_DIR/cache_miss" 3 "$SIZE_MB" 2>&1
done

echo ""
echo "====================================================="
echo " Questions to answer:"
echo "====================================================="
echo " 1. At what array size does L1-dcache-load-misses explode?"
echo "    (hint: L1 is typically 32-48KB)"
echo " 2. At what size does LLC-load-misses appear?"
echo "    (hint: L3 is typically 6-30MB)"
echo " 3. What is the IPC for pointer chasing at 64MB?"
echo "    (should be < 0.5 — pure memory bound)"
echo " 4. Why is pointer chasing slower than random access?"
echo "    (no instruction-level parallelism — each load depends on previous)"
echo "====================================================="
