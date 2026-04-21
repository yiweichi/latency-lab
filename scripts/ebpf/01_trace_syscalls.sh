#!/bin/bash
# ============================================================================
# Real eBPF Lab 1: tracepoint + ringbuf + libbpf
# ============================================================================
# Goal: Build and run a minimal real eBPF program on Linux.
#
# What this lab teaches:
#   1. Write a .bpf.c program with SEC() sections
#   2. Define a ring buffer map
#   3. Emit events from kernel-space eBPF to user-space
#   4. Use a libbpf skeleton loader to attach and read events
#
# This script is Linux-only. It will not work on macOS.
#
# Expected dependencies on Ubuntu/Debian:
#   sudo apt-get install -y clang llvm libbpf-dev libelf-dev zlib1g-dev bpftool
#
# Usage:
#   sudo scripts/ebpf/01_trace_syscalls.sh
# ============================================================================

set -e

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
SRC_DIR="$ROOT_DIR/src/phase3_real_ebpf"
OUT_BPF_O="$BUILD_DIR/syscall_trace.bpf.o"
OUT_SKEL_H="$SRC_DIR/syscall_trace.skel.h"
OUT_LOADER="$BUILD_DIR/syscall_trace"

mkdir -p "$BUILD_DIR"

if [ "$(uname -s)" != "Linux" ]; then
    echo "This lab only works on Linux."
    exit 1
fi

if ! command -v clang >/dev/null 2>&1; then
    echo "clang not found"
    exit 1
fi

if ! command -v bpftool >/dev/null 2>&1; then
    echo "bpftool not found"
    exit 1
fi

echo "[1/4] Generating vmlinux.h"
if [ ! -f "$SRC_DIR/vmlinux.h" ]; then
    bpftool btf dump file /sys/kernel/btf/vmlinux format c > "$SRC_DIR/vmlinux.h"
fi

echo "[2/4] Compiling eBPF program"
clang \
    -target bpf \
    -D__TARGET_ARCH_x86 \
    -O2 -g \
    -I"$SRC_DIR" \
    -c "$SRC_DIR/syscall_trace.bpf.c" \
    -o "$OUT_BPF_O"

echo "[3/4] Generating skeleton"
bpftool gen skeleton "$OUT_BPF_O" > "$OUT_SKEL_H"

echo "[4/4] Building user-space loader"
g++ -std=c++17 -O2 -g -Wall -Wextra \
    -I"$SRC_DIR" \
    "$SRC_DIR/syscall_trace.cpp" \
    -o "$OUT_LOADER" \
    $(pkg-config --cflags --libs libbpf)

echo
echo "Build complete: $OUT_LOADER"
echo "Starting loader..."
echo
sudo "$OUT_LOADER"
