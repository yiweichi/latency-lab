CXX := g++
CXXFLAGS := -std=c++17 -O2 -g -Wall -Wextra
LDFLAGS := -pthread

# -g is essential: without debug symbols, perf/VTune can't show source lines
# -O2 is realistic: we profile optimized code, not debug builds
# -fno-omit-frame-pointer: needed for perf call graph (CRITICAL for flame graphs)
CXXFLAGS += -fno-omit-frame-pointer

BUILD_DIR := build
SRC_PHASE1 := src/phase1
SRC_PHASE2 := src/phase2_hft

# Phase 1: Microbenchmarks
PHASE1_TARGETS := \
	$(BUILD_DIR)/busy_loop \
	$(BUILD_DIR)/cache_miss \
	$(BUILD_DIR)/syscall_storm \
	$(BUILD_DIR)/context_switch \
	$(BUILD_DIR)/false_sharing \
	$(BUILD_DIR)/valgrind_targets \
	$(BUILD_DIR)/asan_targets

# Phase 2: HFT experiments
PHASE2_TARGETS := \
	$(BUILD_DIR)/orderbook_bench \
	$(BUILD_DIR)/udp_market_data

ALL_TARGETS := $(PHASE1_TARGETS) $(PHASE2_TARGETS)

.PHONY: all clean phase1 phase2 help scripts-chmod

all: $(ALL_TARGETS) scripts-chmod

phase1: $(PHASE1_TARGETS)

phase2: $(PHASE2_TARGETS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Phase 1 builds
$(BUILD_DIR)/busy_loop: $(SRC_PHASE1)/busy_loop.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

$(BUILD_DIR)/cache_miss: $(SRC_PHASE1)/cache_miss.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

$(BUILD_DIR)/syscall_storm: $(SRC_PHASE1)/syscall_storm.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

$(BUILD_DIR)/context_switch: $(SRC_PHASE1)/context_switch.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

$(BUILD_DIR)/false_sharing: $(SRC_PHASE1)/false_sharing.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

# Valgrind lab: -O0 so memcheck/cachegrind see every access (not perf-tuned)
$(BUILD_DIR)/valgrind_targets: $(SRC_PHASE1)/valgrind_targets.cpp | $(BUILD_DIR)
	$(CXX) -std=c++17 -O0 -g -Wall -Wextra -fno-omit-frame-pointer $(LDFLAGS) -o $@ $<

# ASan lab: -fsanitize=address for runtime bug detection (stack/global/heap)
$(BUILD_DIR)/asan_targets: $(SRC_PHASE1)/asan_targets.cpp | $(BUILD_DIR)
	$(CXX) -std=c++17 -O0 -g -Wall -Wextra -fno-omit-frame-pointer \
		-fsanitize=address -fsanitize-address-use-after-scope \
		$(LDFLAGS) -o $@ $<

# Phase 2 builds
$(BUILD_DIR)/orderbook_bench: $(SRC_PHASE2)/orderbook_bench.cpp $(SRC_PHASE2)/orderbook.h | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

$(BUILD_DIR)/udp_market_data: $(SRC_PHASE2)/udp_market_data.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<

scripts-chmod:
	chmod +x scripts/perf/*.sh scripts/ftrace/*.sh scripts/vtune/*.sh scripts/combined/*.sh scripts/valgrind/*.sh scripts/asan/*.sh 2>/dev/null || true
	chmod +x scripts/bpftrace/*.bt 2>/dev/null || true
	chmod +x scripts/ebpf/*.sh 2>/dev/null || true

clean:
	rm -rf $(BUILD_DIR) results

help:
	@echo "Latency Lab - Performance Profiling Experiments"
	@echo ""
	@echo "Build targets:"
	@echo "  make all       - Build everything"
	@echo "  make phase1    - Build microbenchmarks only"
	@echo "  make phase2    - Build HFT experiments only"
	@echo "  make clean     - Remove build artifacts and results"
	@echo ""
	@echo "After building, run experiments:"
	@echo ""
	@echo "  Phase 1 - perf:"
	@echo "    scripts/perf/01_basic_stat.sh"
	@echo "    scripts/perf/02_cache_deep_dive.sh"
	@echo "    scripts/perf/03_flamegraph.sh"
	@echo "    scripts/perf/04_scheduler.sh"
	@echo "    scripts/perf/05_syscall_analysis.sh"
	@echo ""
	@echo "  Phase 2 - ftrace (requires root):"
	@echo "    sudo scripts/ftrace/01_syscall_trace.sh"
	@echo "    sudo scripts/ftrace/02_sched_trace.sh"
	@echo "    sudo scripts/ftrace/03_function_graph.sh"
	@echo "    sudo scripts/ftrace/04_irq_trace.sh"
	@echo ""
	@echo "  Phase 3 - bpftrace (requires root):"
	@echo "    sudo bpftrace scripts/bpftrace/01_syscall_latency.bt"
	@echo "    sudo bpftrace scripts/bpftrace/02_sched_snoop.bt"
	@echo "    sudo bpftrace -c './build/context_switch' scripts/bpftrace/02_sched_snoop_target.bt"
	@echo "    sudo bpftrace scripts/bpftrace/03_cache_line_bounce.bt"
	@echo "    sudo bpftrace scripts/bpftrace/04_network_latency.bt"
	@echo "    sudo bpftrace scripts/bpftrace/05_wakeup_latency.bt"
	@echo ""
	@echo "  Phase 3b - real eBPF / libbpf (Linux only, requires root):"
	@echo "    sudo scripts/ebpf/01_trace_syscalls.sh"
	@echo ""
	@echo "  Phase 4 - VTune:"
	@echo "    scripts/vtune/01_hotspot.sh"
	@echo "    scripts/vtune/02_memory_access.sh"
	@echo "    scripts/vtune/03_topdown.sh"
	@echo ""
	@echo "  Combined experiments:"
	@echo "    scripts/combined/01_four_tool_comparison.sh"
	@echo "    scripts/combined/02_latency_spike_hunt.sh"
	@echo "    scripts/combined/03_hft_optimization_lab.sh"
	@echo ""
	@echo "  Valgrind (Linux; build/valgrind_targets uses -O0):"
	@echo "    scripts/valgrind/01_memcheck.sh"
	@echo "    scripts/valgrind/02_cachegrind.sh"
	@echo "    scripts/valgrind/03_callgrind.sh"
	@echo "    scripts/valgrind/04_helgrind.sh"
	@echo "    scripts/valgrind/05_massif.sh"
	@echo ""
	@echo "  ASan (build/asan_targets uses -fsanitize=address):"
	@echo "    scripts/asan/01_asan_basic.sh      # stack/heap/global overflow"
	@echo "    scripts/asan/02_asan_advanced.sh    # leak, double-free, use-after-return"
