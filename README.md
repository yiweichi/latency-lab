# Latency Lab — Linux 性能观测实战

从 HFT / low-latency 视角，通过**同一组实验 + 多工具对照**深入掌握 perf / ftrace / bpftrace / VTune。

## 核心思想

不是学命令，而是建立一套从用户态到硬件的完整性能观测体系：

```
用户态代码 (C++)
   ↓
CPU执行 / cache / branch prediction
   ↓
内核调度 / syscall / IRQ
   ↓
tracepoints / ftrace (内核内置追踪器)
   ↓
eBPF / bpftrace (动态内核编程)
   ↓
perf (统一入口：计数器 + 采样 + 调度)
   ↓
VTune (硬件级微架构分析)
```

每个实验都用**全部四个工具**分析同一个程序，让你理解每个工具看到的是"真相的哪一层"。

## 快速开始

```bash
# 需要 Linux 环境 (perf/ftrace/bpftrace 都是 Linux 工具)
# macOS 上需要 Linux VM 或 Docker

# 编译所有实验程序
make all

# 查看所有可用实验
make help

# 开始第一个实验
scripts/perf/01_basic_stat.sh
```

## 项目结构

```
latency-lab/
├── Makefile
├── README.md
├── src/
│   ├── phase1/                    # 基础微基准测试
│   │   ├── busy_loop.cpp          # 实验A：IPC / branch prediction
│   │   ├── cache_miss.cpp         # 实验B：缓存层次结构
│   │   ├── syscall_storm.cpp      # 实验C：系统调用开销
│   │   ├── context_switch.cpp     # 实验D：上下文切换延迟
│   │   └── false_sharing.cpp      # 实验E：缓存行伪共享
│   └── phase2_hft/                # HFT 场景实验
│       ├── orderbook.h            # 订单簿：map版 vs array版
│       ├── orderbook_bench.cpp    # 订单簿基准测试
│       └── udp_market_data.cpp    # UDP 行情接收延迟
├── scripts/
│   ├── perf/                      # Phase 1：perf 实验脚本
│   │   ├── 01_basic_stat.sh       # 基础计数器：IPC / branch / cache
│   │   ├── 02_cache_deep_dive.sh  # 缓存层次深度分析
│   │   ├── 03_flamegraph.sh       # 火焰图生成
│   │   ├── 04_scheduler.sh        # 调度器分析
│   │   └── 05_syscall_analysis.sh # 系统调用开销对比
│   ├── ftrace/                    # Phase 2：ftrace 实验脚本
│   │   ├── 01_syscall_trace.sh    # 系统调用追踪
│   │   ├── 02_sched_trace.sh      # 调度器追踪
│   │   ├── 03_function_graph.sh   # 内核函数调用图
│   │   └── 04_irq_trace.sh       # 中断追踪
│   ├── bpftrace/                  # Phase 3：bpftrace 实验脚本
│   │   ├── 01_syscall_latency.bt  # 系统调用延迟分布
│   │   ├── 02_sched_snoop.bt      # 调度监听
│   │   ├── 03_cache_line_bounce.bt # CPU迁移/缓存抖动检测
│   │   ├── 04_network_latency.bt  # 网络栈延迟
│   │   └── 05_wakeup_latency.bt   # 线程唤醒延迟
│   ├── vtune/                     # Phase 4：VTune 实验脚本
│   │   ├── 01_hotspot.sh          # 热点分析
│   │   ├── 02_memory_access.sh    # 内存访问分析
│   │   └── 03_topdown.sh          # Top-Down 微架构分析
│   └── combined/                  # 综合实验
│       ├── 01_four_tool_comparison.sh  # 四工具对照
│       ├── 02_latency_spike_hunt.sh    # 延迟尖峰猎捕
│       └── 03_hft_optimization_lab.sh  # HFT 优化实验室
└── results/                       # 实验结果输出 (git ignored)
```

## 学习路线

### 第 1 周：perf（打好基础）

| 实验 | 脚本 | 你要回答的问题 |
|------|------|----------------|
| IPC 基础 | `01_basic_stat.sh` | 什么是 IPC？为什么 busy loop 的 IPC 高？ |
| Branch Miss | `01_basic_stat.sh` | 随机分支为什么导致 IPC 下降？ |
| Cache 层次 | `02_cache_deep_dive.sh` | L1→L2→L3→DRAM 各级延迟差多少？ |
| 火焰图 | `03_flamegraph.sh` | 火焰图的"宽度"代表什么？ |
| 调度延迟 | `04_scheduler.sh` | context switch 一次花多少 us？ |
| Syscall 开销 | `05_syscall_analysis.sh` | 最轻的 syscall 是哪个？VDSO 是什么？ |

**关键理解：**
- IPC < 1.0 = CPU 在等待（内存？分支？）
- cache-miss rate > 5% = 数据结构需要优化
- 火焰图的宽度 = CPU 时间占比

### 第 2 周：ftrace（看内核在干什么）

| 实验 | 脚本 | 你要回答的问题 |
|------|------|----------------|
| Syscall 追踪 | `01_syscall_trace.sh` | 一个 read() 在内核里经过哪些函数？ |
| 调度追踪 | `02_sched_trace.sh` | 谁抢了我的 CPU？ |
| 函数图 | `03_function_graph.sh` | write() 的内核调用链有多深？ |
| IRQ 追踪 | `04_irq_trace.sh` | 哪些中断在偷 CPU 时间？ |

**关键理解：**
- ftrace 是内核内置的，零额外开销
- `sched_switch` 的 `prev_state` 告诉你为什么被切换
- IRQ 是"隐形"延迟杀手

### 第 3 周：bpftrace（动态内核编程）

| 实验 | 脚本 | 你要回答的问题 |
|------|------|----------------|
| Syscall 延迟分布 | `01_syscall_latency.bt` | read() 的延迟分布是什么形状？双峰？ |
| 调度监听 | `02_sched_snoop.bt` | runqueue delay 的 p99 是多少？ |
| 缓存抖动 | `03_cache_line_bounce.bt` | 我的进程被迁移了几次？ |
| 网络延迟 | `04_network_latency.bt` | recvfrom() 延迟分布？NET_RX softirq 花多久？ |
| 唤醒延迟 | `05_wakeup_latency.bt` | 线程唤醒到实际执行的延迟？ |

**关键理解：**
- bpftrace 是"可编程的 ftrace"
- 看分布比看平均值重要 100 倍
- bimodal distribution = 有两条路径

### 第 4 周：VTune（硬件真相）

| 实验 | 脚本 | 你要回答的问题 |
|------|------|----------------|
| Hotspot | `01_hotspot.sh` | 热点函数是哪个？热点源码行？ |
| Memory Access | `02_memory_access.sh` | L1/L2/L3 命中率各是多少？ |
| Top-Down | `03_topdown.sh` | Retiring / Bad Spec / FE / BE 各占多少？ |

**关键理解 — Top-Down Microarchitecture Analysis (TMA)：**
```
Pipeline Slots
├── Retiring         (有效工作 — 越高越好)
├── Bad Speculation  (分支预测失败 — 浪费的流水线)
├── Frontend Bound   (取指/解码瓶颈 — 少见)
└── Backend Bound    (执行/内存瓶颈 — HFT 最常见)
    ├── Memory Bound   (等数据 — cache miss)
    └── Core Bound     (执行单元不够)
```

### 第 5 周：综合实战

| 实验 | 脚本 | 目标 |
|------|------|------|
| 四工具对照 | `01_four_tool_comparison.sh` | 同一程序，4 种视角 |
| 延迟尖峰猎捕 | `02_latency_spike_hunt.sh` | 制造干扰，找到原因 |
| HFT 优化实验室 | `03_hft_optimization_lab.sh` | 端到端优化流程 |

## 实验程序说明

### Phase 1 微基准测试

每个程序都有多个 mode，通过命令行参数选择：

```bash
# busy_loop: 测试 IPC 和 branch prediction
./build/busy_loop 0          # mode 0: 可预测循环（高 IPC）
./build/busy_loop 1          # mode 1: 可预测分支
./build/busy_loop 2          # mode 2: 不可预测分支（branch miss 风暴）

# cache_miss: 测试缓存层次
./build/cache_miss 0 64      # mode 0: 顺序访问 64MB（prefetch 友好）
./build/cache_miss 1 64      # mode 1: stride-64 跨步访问
./build/cache_miss 2 64      # mode 2: 随机访问（cache miss 风暴）
./build/cache_miss 3 64      # mode 3: 指针追踪（最差情况）

# syscall_storm: 测试系统调用开销
./build/syscall_storm 0      # getpid() — 最轻
./build/syscall_storm 1      # clock_gettime() — VDSO
./build/syscall_storm 2      # read(/dev/null)
./build/syscall_storm 3      # write(/dev/null)

# context_switch: 测试上下文切换
./build/context_switch 0     # 线程 ping-pong，无 CPU 绑定
./build/context_switch 1     # 同一 CPU（最差情况）
./build/context_switch 2     # 不同 CPU
./build/context_switch 3     # 进程 ping-pong + 延迟直方图

# false_sharing: 测试伪共享
./build/false_sharing        # 自动对比共享/填充两种版本
```

### Phase 2 HFT 实验

```bash
# orderbook_bench: 订单簿基准测试
./build/orderbook_bench 0    # std::map 版（树 = 指针追踪 = cache 不友好）
./build/orderbook_bench 1    # array 版（连续内存 = cache 友好）
./build/orderbook_bench 2    # 两版对比

# udp_market_data: UDP 行情延迟测试
./build/udp_market_data 1000000 1 12345
#                       消息数  间隔us  端口
```

## 环境要求

### 必需
- Linux (kernel 4.18+, 建议 5.x+)
- g++ 或 clang++ (C++17)
- perf (`linux-tools-$(uname -r)`)

### 建议
- bpftrace (`apt install bpftrace` 或 `dnf install bpftrace`)
- stress-ng (用于延迟尖峰实验)
- FlameGraph tools (`git clone https://github.com/brendangregg/FlameGraph`)

### 可选
- Intel VTune (免费下载: https://www.intel.com/content/www/us/en/developer/tools/oneapi/vtune-profiler.html)
- trace-cmd (`apt install trace-cmd`)

### 在 macOS 上使用

本项目的工具都是 Linux 专属的。建议：

```bash
# 方案 1: Docker (最简单)
docker run -it --privileged --pid=host \
  -v $(pwd):/work -w /work \
  ubuntu:22.04 bash

# 容器内安装
apt update && apt install -y g++ make linux-tools-generic bpftrace stress-ng

# 方案 2: 云服务器
# AWS c5.2xlarge / GCP n2-standard-8 都适合
# 确保是裸金属或启用了 PMU 访问
```

## 编译选项解释

```makefile
CXXFLAGS := -std=c++17 -O2 -g -Wall
# -O2: 优化后的代码才有意义做 profiling（-O0 结果没有参考价值）
# -g:  保留调试符号（perf/VTune 需要它来显示源码行）

CXXFLAGS += -fno-omit-frame-pointer
# 关键! 没有这个，perf 的 --call-graph fp 模式无法获取调用链
# 很多性能问题需要看调用链才能定位
```

## 学完之后

如果你完成了所有实验，你应该能够：

1. **看到数字就知道问题** — IPC < 1? 一定是 memory bound 或 branch miss
2. **用正确的工具** — 想看分布用 bpftrace，想看调用链用 perf，想看内核路径用 ftrace
3. **解释 tail latency** — p99 spike 是 context switch？IRQ？cache miss？migration？
4. **做 HFT 级优化** — isolcpus, IRQ affinity, busy-polling, 数据结构 cache-friendly 改造
