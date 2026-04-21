// HFT Experiment: Order Book Benchmark
// Purpose: Compare map-based vs array-based orderbook under profiling
//
// Key profiling targets:
//   - perf: cache misses in map vs array
//   - bpftrace: per-operation latency distribution
//   - VTune: top-down analysis showing memory-bound vs retiring
//   - ftrace: verify no unexpected syscalls in hot path

#include "orderbook.h"
#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <random>
#include <vector>
#include <algorithm>
#include <cmath>

template<typename BookT>
std::vector<double> benchmark_orderbook(long operations, bool measure_latency) {
    BookT book;
    std::mt19937 rng(42);
    std::uniform_int_distribution<uint32_t> price_dist(10100, 10900);
    std::uniform_int_distribution<uint32_t> qty_dist(1, 1000);
    std::uniform_int_distribution<int> action_dist(0, 99);

    std::vector<uint64_t> active_orders;
    active_orders.reserve(operations);

    std::vector<double> latencies;
    if (measure_latency) {
        latencies.reserve(operations);
    }

    uint64_t next_id = 1;

    for (long i = 0; i < operations; i++) {
        std::chrono::high_resolution_clock::time_point t0;
        if (measure_latency) {
            t0 = std::chrono::high_resolution_clock::now();
        }

        int action = action_dist(rng);

        if (action < 60 || active_orders.empty()) {
            Order o;
            o.order_id = next_id++;
            o.price = price_dist(rng);
            o.quantity = qty_dist(rng);
            o.is_buy = (action < 30);
            book.add_order(o);
            active_orders.push_back(o.order_id);
        } else {
            size_t idx = rng() % active_orders.size();
            book.cancel_order(active_orders[idx]);
            active_orders[idx] = active_orders.back();
            active_orders.pop_back();
        }

        if (measure_latency) {
            auto t1 = std::chrono::high_resolution_clock::now();
            latencies.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count());
        }
    }

    // Read BBO to prevent dead code elimination
    volatile uint32_t s = book.spread();
    (void)s;

    return latencies;
}

void print_stats(const char* name, std::vector<double>& latencies) {
    std::sort(latencies.begin(), latencies.end());

    double sum = 0;
    for (auto l : latencies) sum += l;
    double mean = sum / latencies.size();

    printf("\n=== %s ===\n", name);
    printf("Operations: %zu\n", latencies.size());
    printf("Mean:       %.0f ns\n", mean);
    printf("p50:        %.0f ns\n", latencies[latencies.size() * 50 / 100]);
    printf("p90:        %.0f ns\n", latencies[latencies.size() * 90 / 100]);
    printf("p99:        %.0f ns\n", latencies[latencies.size() * 99 / 100]);
    printf("p999:       %.0f ns\n", latencies[latencies.size() * 999 / 1000]);
    printf("Max:        %.0f ns\n", latencies.back());
}

int main(int argc, char* argv[]) {
    int mode = 0;
    long operations = 5'000'000L;
    bool measure_latency = false;

    if (argc > 1) mode = atoi(argv[1]);
    if (argc > 2) operations = atol(argv[2]);
    if (argc > 3) measure_latency = atoi(argv[3]) != 0;

    switch (mode) {
        case 0: {
            printf("[Mode 0] OrderBookMap (std::map — tree-based)\n");
            printf("Latency harness: %s\n", measure_latency ? "ON" : "OFF");
            auto lat = benchmark_orderbook<OrderBookMap>(operations, measure_latency);
            if (measure_latency) {
                print_stats("OrderBookMap", lat);
            }
            break;
        }
        case 1: {
            printf("[Mode 1] OrderBookArray (array-based — cache-friendly)\n");
            printf("Latency harness: %s\n", measure_latency ? "ON" : "OFF");
            auto lat = benchmark_orderbook<OrderBookArray>(operations, measure_latency);
            if (measure_latency) {
                print_stats("OrderBookArray", lat);
            }
            break;
        }
        case 2: {
            printf("[Mode 2] OrderBookAllArray (fully array-based)\n");
            printf("Latency harness: %s\n", measure_latency ? "ON" : "OFF");
            auto lat = benchmark_orderbook<OrderBookAllArray>(operations, measure_latency);
            if (measure_latency) {
                print_stats("OrderBookAllArray", lat);
            }
            break;
        }
        case 3: {
            printf("[Mode 3] Head-to-head comparison\n");
            printf("Latency harness: %s\n", measure_latency ? "ON" : "OFF");
            auto lat_map = benchmark_orderbook<OrderBookMap>(operations, measure_latency);
            auto lat_arr = benchmark_orderbook<OrderBookArray>(operations, measure_latency);
            auto lat_all_arr = benchmark_orderbook<OrderBookAllArray>(operations, measure_latency);
            if (measure_latency) {
                print_stats("OrderBookMap", lat_map);
                print_stats("OrderBookArray", lat_arr);
                print_stats("OrderBookAllArray", lat_all_arr);

                double map_p99 = lat_map[lat_map.size() * 99 / 100];
                double arr_p99 = lat_arr[lat_arr.size() * 99 / 100];
                double all_arr_p99 = lat_all_arr[lat_all_arr.size() * 99 / 100];
                printf("\n--- p99 improvement vs map ---\n");
                printf("OrderBookArray: %.1fx\n", map_p99 / arr_p99);
                printf("OrderBookAllArray: %.1fx\n", map_p99 / all_arr_p99);
            }
            break;
        }
        default:
            printf("Usage: %s [0|1|2|3] [operations] [measure_latency:0|1]\n", argv[0]);
            return 1;
    }

    return 0;
}
