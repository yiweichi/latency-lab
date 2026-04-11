// Experiment E: False Sharing
// Purpose: Demonstrate cache line contention between cores
// Expected: Mode 0 (shared cache line) = much slower than Mode 1 (padded)
//
// Key questions:
//   1. Why does writing to "different" variables cause slowdown?
//   2. What does perf show for L1-dcache-load-misses?
//   3. How does padding to 64 bytes fix it?
//   4. What does VTune show for "contested accesses"?

#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <pthread.h>
#include <thread>
#include <vector>

struct SharedCounters {
    volatile long counter1;
    volatile long counter2;
};

struct PaddedCounters {
    volatile long counter1;
    char pad1[56];  // pad to separate cache line (64 - 8 = 56)
    volatile long counter2;
    char pad2[56];
};

static_assert(sizeof(PaddedCounters) >= 128, "PaddedCounters should span 2 cache lines");

template<typename T>
struct WorkerArgs {
    T* counters;
    int thread_id;
    long iterations;
};

template<typename T>
void* worker(void* arg) {
    auto* args = static_cast<WorkerArgs<T>*>(arg);
    volatile long* counter = (args->thread_id == 0) ?
        &args->counters->counter1 : &args->counters->counter2;

    for (long i = 0; i < args->iterations; i++) {
        (*counter)++;
    }
    return nullptr;
}

template<typename T>
double run_test(long iterations) {
    T counters = {};

    WorkerArgs<T> args1 = {&counters, 0, iterations};
    WorkerArgs<T> args2 = {&counters, 1, iterations};

    pthread_t t1, t2;

    auto start = std::chrono::high_resolution_clock::now();

    pthread_create(&t1, nullptr, worker<T>, &args1);
    pthread_create(&t2, nullptr, worker<T>, &args2);

    pthread_join(t1, nullptr);
    pthread_join(t2, nullptr);

    auto end = std::chrono::high_resolution_clock::now();
    return std::chrono::duration<double, std::milli>(end - start).count();
}

int main(int argc, char* argv[]) {
    long iterations = 100'000'000L;
    if (argc > 1) iterations = atol(argv[1]);

    printf("=== False Sharing Experiment ===\n");
    printf("Iterations per thread: %ld\n\n", iterations);

    printf("SharedCounters size: %zu bytes (on same cache line)\n", sizeof(SharedCounters));
    printf("PaddedCounters size: %zu bytes (on separate cache lines)\n\n", sizeof(PaddedCounters));

    // Warmup
    run_test<SharedCounters>(1000);
    run_test<PaddedCounters>(1000);

    // Measure
    double shared_ms = run_test<SharedCounters>(iterations);
    double padded_ms = run_test<PaddedCounters>(iterations);

    printf("Shared cache line:    %.2f ms\n", shared_ms);
    printf("Separate cache lines: %.2f ms\n", padded_ms);
    printf("Slowdown factor:      %.2fx\n", shared_ms / padded_ms);

    printf("\n--- Single-threaded baseline ---\n");
    SharedCounters sc = {};
    auto start = std::chrono::high_resolution_clock::now();
    for (long i = 0; i < iterations * 2; i++) sc.counter1++;
    auto end = std::chrono::high_resolution_clock::now();
    double single_ms = std::chrono::duration<double, std::milli>(end - start).count();
    printf("Single thread:        %.2f ms\n", single_ms);

    return 0;
}
