# Latency Lab

Linux profiling lab: perf / ftrace / bpftrace / VTune experiments for low-latency systems.

Learn by running the **same experiments through all four tools** and comparing what each one reveals.

## Core Idea

Build a mental model from userspace down to hardware:

```
Userspace code (C++)
   ↓
CPU execution / cache / branch prediction
   ↓
Kernel scheduling / syscall / IRQ
   ↓
tracepoints / ftrace (kernel built-in tracer)
   ↓
eBPF / bpftrace (dynamic kernel instrumentation)
   ↓
perf (unified entry point: counters + sampling + scheduling)
   ↓
VTune (hardware-level microarchitecture analysis)
```

Each experiment analyzes the same program with all four tools, so you understand which layer of truth each tool exposes.

## Quick Start

```bash
# Requires Linux (perf/ftrace/bpftrace are Linux-only)
# On macOS, use a Linux VM or Docker

make all                          # build all experiment programs
make help                         # list all available experiments
scripts/perf/01_basic_stat.sh     # start the first experiment
```

## Project Structure

```
latency-lab/
├── Makefile
├── README.md
├── src/
│   ├── phase1/                    # Microbenchmarks
│   │   ├── busy_loop.cpp          # Exp A: IPC / branch prediction
│   │   ├── cache_miss.cpp         # Exp B: cache hierarchy
│   │   ├── syscall_storm.cpp      # Exp C: syscall overhead
│   │   ├── context_switch.cpp     # Exp D: context switch latency
│   │   └── false_sharing.cpp      # Exp E: cache line false sharing
│   └── phase2_hft/                # HFT scenarios
│       ├── orderbook.h            # Order book: map-based vs array-based
│       ├── orderbook_bench.cpp    # Order book benchmark
│       └── udp_market_data.cpp    # UDP market data receive latency
├── scripts/
│   ├── perf/                      # Phase 1: perf experiments
│   │   ├── 01_basic_stat.sh       # Counters: IPC / branch / cache
│   │   ├── 02_cache_deep_dive.sh  # Cache hierarchy deep dive
│   │   ├── 03_flamegraph.sh       # Flame graph generation
│   │   ├── 04_scheduler.sh        # Scheduler analysis
│   │   └── 05_syscall_analysis.sh # Syscall cost comparison
│   ├── ftrace/                    # Phase 2: ftrace experiments
│   │   ├── 01_syscall_trace.sh    # Syscall tracing
│   │   ├── 02_sched_trace.sh      # Scheduler tracing
│   │   ├── 03_function_graph.sh   # Kernel function call graph
│   │   └── 04_irq_trace.sh        # Interrupt tracing
│   ├── bpftrace/                  # Phase 3: bpftrace experiments
│   │   ├── 01_syscall_latency.bt  # Syscall latency distribution
│   │   ├── 02_sched_snoop.bt      # Scheduler snooping
│   │   ├── 03_cache_line_bounce.bt # CPU migration / cache bounce detection
│   │   ├── 04_network_latency.bt  # Network stack latency
│   │   └── 05_wakeup_latency.bt   # Thread wakeup latency
│   ├── vtune/                     # Phase 4: VTune experiments
│   │   ├── 01_hotspot.sh          # Hotspot analysis
│   │   ├── 02_memory_access.sh    # Memory access analysis
│   │   └── 03_topdown.sh          # Top-Down microarchitecture analysis
│   └── combined/                  # Combined experiments
│       ├── 01_four_tool_comparison.sh  # Same program, four tools
│       ├── 02_latency_spike_hunt.sh    # Latency spike hunting
│       └── 03_hft_optimization_lab.sh  # HFT optimization lab
└── results/                       # Experiment output (git ignored)
```

## Learning Path

### Week 1: perf (foundation)

| Experiment | Script | Question to Answer |
|------------|--------|--------------------|
| IPC basics | `01_basic_stat.sh` | What is IPC? Why is the busy loop's IPC high? |
| Branch miss | `01_basic_stat.sh` | Why do random branches cause IPC to drop? |
| Cache hierarchy | `02_cache_deep_dive.sh` | What is the latency difference across L1→L2→L3→DRAM? |
| Flame graphs | `03_flamegraph.sh` | What does the "width" of a flame graph represent? |
| Scheduling latency | `04_scheduler.sh` | How many microseconds does one context switch cost? |
| Syscall overhead | `05_syscall_analysis.sh` | Which syscall is cheapest? What is VDSO? |

**Key takeaways:**
- IPC < 1.0 = CPU is stalling (memory? branch?)
- cache-miss rate > 5% = data structure needs optimization
- flame graph width = fraction of CPU time

### Week 2: ftrace (what the kernel is doing)

| Experiment | Script | Question to Answer |
|------------|--------|--------------------|
| Syscall trace | `01_syscall_trace.sh` | What kernel functions does a single read() pass through? |
| Scheduler trace | `02_sched_trace.sh` | Who preempted my process? |
| Function graph | `03_function_graph.sh` | How deep is the kernel call chain for write()? |
| IRQ trace | `04_irq_trace.sh` | Which interrupts are stealing CPU time? |

**Key takeaways:**
- ftrace is built into the kernel with near-zero overhead
- `sched_switch` `prev_state` tells you why you were descheduled
- IRQs are invisible latency killers

### Week 3: bpftrace (dynamic kernel instrumentation)

| Experiment | Script | Question to Answer |
|------------|--------|--------------------|
| Syscall latency dist | `01_syscall_latency.bt` | What shape is the read() latency distribution? Bimodal? |
| Scheduler snooping | `02_sched_snoop.bt` | What is the p99 runqueue delay? |
| Cache line bounce | `03_cache_line_bounce.bt` | How many times was my process migrated? |
| Network latency | `04_network_latency.bt` | recvfrom() latency distribution? NET_RX softirq duration? |
| Wakeup latency | `05_wakeup_latency.bt` | Delay from thread wakeup to actual execution? |

**Key takeaways:**
- bpftrace is "programmable ftrace"
- Distributions matter 100x more than averages
- Bimodal distribution = two code paths

### Week 4: VTune (hardware truth)

| Experiment | Script | Question to Answer |
|------------|--------|--------------------|
| Hotspot | `01_hotspot.sh` | Which function is the hotspot? Which source line? |
| Memory access | `02_memory_access.sh` | What are the L1/L2/L3 hit rates? |
| Top-Down | `03_topdown.sh` | What % is Retiring / Bad Spec / FE / BE Bound? |

**Key concept — Top-Down Microarchitecture Analysis (TMA):**
```
Pipeline Slots
├── Retiring         (useful work — higher is better)
├── Bad Speculation  (branch misprediction — wasted pipeline slots)
├── Frontend Bound   (instruction fetch/decode bottleneck — rare)
└── Backend Bound    (execution/memory stalls — most common in HFT)
    ├── Memory Bound   (waiting for data — cache miss)
    └── Core Bound     (not enough execution units)
```

### Week 5: Combined Exercises

| Experiment | Script | Goal |
|------------|--------|------|
| Four-tool comparison | `01_four_tool_comparison.sh` | Same program, four perspectives |
| Latency spike hunt | `02_latency_spike_hunt.sh` | Inject noise, find the cause |
| HFT optimization lab | `03_hft_optimization_lab.sh` | End-to-end optimization workflow |

## Experiment Programs

### Phase 1: Microbenchmarks

Each program supports multiple modes via command-line arguments:

```bash
# busy_loop: IPC and branch prediction
./build/busy_loop 0          # mode 0: predictable loop (high IPC)
./build/busy_loop 1          # mode 1: predictable branch
./build/busy_loop 2          # mode 2: unpredictable branch (branch miss storm)

# cache_miss: cache hierarchy
./build/cache_miss 0 64      # mode 0: sequential 64MB (prefetch-friendly)
./build/cache_miss 1 64      # mode 1: stride-64 access
./build/cache_miss 2 64      # mode 2: random access (cache miss storm)
./build/cache_miss 3 64      # mode 3: pointer chasing (worst case)

# syscall_storm: syscall overhead
./build/syscall_storm 0      # getpid() — lightest
./build/syscall_storm 1      # clock_gettime() — VDSO
./build/syscall_storm 2      # read(/dev/null)
./build/syscall_storm 3      # write(/dev/null)

# context_switch: context switch latency
./build/context_switch 0     # thread ping-pong, no CPU pinning
./build/context_switch 1     # same CPU (worst case)
./build/context_switch 2     # different CPUs
./build/context_switch 3     # process ping-pong + latency histogram

# false_sharing: cache line contention
./build/false_sharing        # auto-compares shared vs padded
```

### Phase 2: HFT Experiments

```bash
# orderbook_bench: order book benchmark
./build/orderbook_bench 0    # std::map (tree = pointer chasing = cache-unfriendly)
./build/orderbook_bench 1    # array-based (contiguous memory = cache-friendly)
./build/orderbook_bench 2    # head-to-head comparison

# udp_market_data: UDP market data latency test
./build/udp_market_data 1000000 1 12345
#                       msgs    interval_us  port
```

## Requirements

### Required
- Linux (kernel 4.18+, 5.x+ recommended)
- g++ or clang++ (C++17)
- perf (`linux-tools-$(uname -r)`)

### Recommended
- bpftrace (`apt install bpftrace` or `dnf install bpftrace`)
- stress-ng (for latency spike experiments)
- FlameGraph tools (`git clone https://github.com/brendangregg/FlameGraph`)

### Optional
- Intel VTune (free download: https://www.intel.com/content/www/us/en/developer/tools/oneapi/vtune-profiler.html)
- trace-cmd (`apt install trace-cmd`)

### Running on macOS

All tools in this project are Linux-only. Options:

```bash
# Option 1: Docker (simplest)
docker run -it --privileged --pid=host \
  -v $(pwd):/work -w /work \
  ubuntu:22.04 bash

# Inside the container
apt update && apt install -y g++ make linux-tools-generic bpftrace stress-ng

# Option 2: Cloud server
# AWS c5.2xlarge / GCP n2-standard-8 work well
# Ensure bare-metal or PMU access is enabled
```

## Compiler Flags

```makefile
CXXFLAGS := -std=c++17 -O2 -g -Wall
# -O2: only optimized code gives meaningful profiling results (-O0 is useless)
# -g:  debug symbols are required for perf/VTune to show source lines

CXXFLAGS += -fno-omit-frame-pointer
# Critical! Without this, perf --call-graph fp cannot capture call stacks.
# Many performance issues require call chains to diagnose.
```

## After Completing All Experiments

You should be able to:

1. **Read the numbers, know the problem** — IPC < 1? Must be memory bound or branch miss.
2. **Pick the right tool** — distributions → bpftrace, call stacks → perf, kernel paths → ftrace.
3. **Explain tail latency** — is the p99 spike from a context switch? IRQ? cache miss? migration?
4. **Apply HFT-grade tuning** — isolcpus, IRQ affinity, busy-polling, cache-friendly data structures.
