// Experiment F: Valgrind Targets
// Purpose: Intentional bugs and patterns for learning Valgrind tools
//
// Modes:
//   0 — memcheck: heap buffer overflow, use-after-free, memory leak, uninit read
//   1 — cachegrind: sequential vs random access (compare cache behavior)
//   2 — callgrind: recursive vs iterative fibonacci (compare call overhead)
//   3 — helgrind: data race between threads (no lock)
//   4 — massif: growing heap allocation pattern
//   5 — clean: correct code baseline (Valgrind should report nothing)
//
// Build with: g++ -std=c++17 -O0 -g ... (use -O0 so Valgrind sees every access)

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <thread>
#include <mutex>
#include <chrono>

// ============================================================================
// Mode 0: Memcheck targets — classic memory bugs
// ============================================================================

static void memcheck_heap_overflow() {
    printf("  [a] Heap buffer overflow...\n");
    int* arr = new int[10];
    for (int i = 0; i <= 10; i++)  // off-by-one: writes arr[10]
        arr[i] = i;
    delete[] arr;
}

static void memcheck_use_after_free() {
    printf("  [b] Use-after-free...\n");
    int* p = new int(42);
    delete p;
    volatile int x = *p;  // read freed memory
    (void)x;
}

static void memcheck_leak() {
    printf("  [c] Memory leak (definitely lost)...\n");
    int* leaked = new int[1024];
    leaked[0] = 1;
    // never freed — Valgrind will report "definitely lost: 4,096 bytes"
}

static void memcheck_uninit_read() {
    printf("  [d] Uninitialized value use...\n");
    int* arr = new int[5];  // not zeroed
    int sum = 0;
    for (int i = 0; i < 5; i++)
        sum += arr[i];  // Conditional jump depends on uninitialised value
    if (sum > 100)
        printf("    sum = %d\n", sum);
    delete[] arr;
}

static void run_memcheck_targets() {
    printf("\n=== Mode 0: Memcheck Targets ===\n");
    printf("Run with: valgrind --leak-check=full ./build/valgrind_targets 0\n\n");
    memcheck_heap_overflow();
    memcheck_use_after_free();
    memcheck_leak();
    memcheck_uninit_read();
    printf("\nExpected: 4 distinct error types reported by Valgrind\n");
}

// ============================================================================
// Mode 1: Cachegrind targets — sequential vs random access
// ============================================================================

static void cachegrind_sequential(long n) {
    std::vector<int> arr(n);
    long sum = 0;
    for (long i = 0; i < n; i++)
        sum += arr[i];
    printf("  Sequential sum: %ld\n", sum);
}

static void cachegrind_random(long n) {
    std::vector<int> arr(n);
    // build a random permutation for access order
    std::vector<long> indices(n);
    for (long i = 0; i < n; i++) indices[i] = i;
    for (long i = n - 1; i > 0; i--) {
        long j = rand() % (i + 1);
        long tmp = indices[i]; indices[i] = indices[j]; indices[j] = tmp;
    }
    long sum = 0;
    for (long i = 0; i < n; i++)
        sum += arr[indices[i]];
    printf("  Random sum: %ld\n", sum);
}

static void run_cachegrind_targets(long n) {
    printf("\n=== Mode 1: Cachegrind Targets ===\n");
    printf("Run with: valgrind --tool=cachegrind ./build/valgrind_targets 1 %ld\n\n", n);
    printf("--- Sequential access ---\n");
    cachegrind_sequential(n);
    printf("--- Random access ---\n");
    cachegrind_random(n);
    printf("\nExpected: random has much higher D1 miss rate in cg_annotate output\n");
}

// ============================================================================
// Mode 2: Callgrind targets — recursive vs iterative
// ============================================================================

static long fib_recursive(int n) {
    if (n <= 1) return n;
    return fib_recursive(n - 1) + fib_recursive(n - 2);
}

static long fib_iterative(int n) {
    if (n <= 1) return n;
    long a = 0, b = 1;
    for (int i = 2; i <= n; i++) {
        long c = a + b;
        a = b;
        b = c;
    }
    return b;
}

static void run_callgrind_targets(int n) {
    printf("\n=== Mode 2: Callgrind Targets ===\n");
    printf("Run with: valgrind --tool=callgrind ./build/valgrind_targets 2 %d\n\n", n);
    printf("--- Recursive fib(%d) ---\n", n);
    auto t0 = std::chrono::high_resolution_clock::now();
    long r1 = fib_recursive(n);
    auto t1 = std::chrono::high_resolution_clock::now();
    printf("  Result: %ld (%.2f ms)\n", r1,
           std::chrono::duration<double, std::milli>(t1 - t0).count());

    printf("--- Iterative fib(%d) ---\n", n);
    auto t2 = std::chrono::high_resolution_clock::now();
    long r2 = fib_iterative(n);
    auto t3 = std::chrono::high_resolution_clock::now();
    printf("  Result: %ld (%.2f ms)\n", r2,
           std::chrono::duration<double, std::milli>(t3 - t2).count());

    printf("\nExpected: callgrind_annotate shows fib_recursive dominates Ir count\n");
    printf("Visualize: kcachegrind callgrind.out.<pid>\n");
}

// ============================================================================
// Mode 3: Helgrind targets — data race
// ============================================================================

static int shared_counter_nolock = 0;
static std::mutex mtx;
static int shared_counter_locked = 0;

static void increment_nolock(int iterations) {
    for (int i = 0; i < iterations; i++)
        shared_counter_nolock++;
}

static void increment_locked(int iterations) {
    for (int i = 0; i < iterations; i++) {
        std::lock_guard<std::mutex> lock(mtx);
        shared_counter_locked++;
    }
}

static void run_helgrind_targets(int iterations) {
    printf("\n=== Mode 3: Helgrind Targets ===\n");
    printf("Run with: valgrind --tool=helgrind ./build/valgrind_targets 3 %d\n\n", iterations);

    printf("--- [a] Race condition (no lock) ---\n");
    shared_counter_nolock = 0;
    std::thread t1(increment_nolock, iterations);
    std::thread t2(increment_nolock, iterations);
    t1.join();
    t2.join();
    printf("  Expected: %d, Got: %d (likely wrong)\n",
           iterations * 2, shared_counter_nolock);

    printf("--- [b] Correct (with lock) ---\n");
    shared_counter_locked = 0;
    std::thread t3(increment_locked, iterations);
    std::thread t4(increment_locked, iterations);
    t3.join();
    t4.join();
    printf("  Expected: %d, Got: %d\n",
           iterations * 2, shared_counter_locked);

    printf("\nExpected: Helgrind reports race on shared_counter_nolock,\n");
    printf("          no errors on shared_counter_locked\n");
}

// ============================================================================
// Mode 4: Massif targets — heap growth
// ============================================================================

static void run_massif_targets(int rounds) {
    printf("\n=== Mode 4: Massif Targets ===\n");
    printf("Run with: valgrind --tool=massif ./build/valgrind_targets 4 %d\n\n", rounds);

    std::vector<std::vector<int>*> allocations;

    for (int r = 0; r < rounds; r++) {
        size_t size = (r + 1) * 1024;
        auto* v = new std::vector<int>(size, r);
        allocations.push_back(v);
        printf("  Round %d: allocated %zu ints (%zu KB cumulative)\n",
               r, size, (size_t)(r + 1) * (size_t)(r + 2) / 2 * 4);
    }

    // free half to show a step-down
    printf("  Freeing first half...\n");
    for (int i = 0; i < rounds / 2; i++) {
        delete allocations[i];
        allocations[i] = nullptr;
    }

    // allocate one big block
    size_t big = rounds * 4096;
    auto* big_alloc = new std::vector<int>(big);
    printf("  Final big allocation: %zu ints (%zu KB)\n", big, big * 4 / 1024);

    // cleanup
    delete big_alloc;
    for (auto* p : allocations)
        delete p;

    printf("\nExpected: ms_print shows sawtooth allocation pattern\n");
    printf("Visualize: ms_print massif.out.<pid>\n");
}

// ============================================================================
// Mode 5: Clean baseline — no bugs
// ============================================================================

static void run_clean_baseline(long n) {
    printf("\n=== Mode 5: Clean Baseline ===\n");
    printf("No bugs. Valgrind should report 0 errors, 0 leaks.\n\n");

    std::vector<int> arr(n);
    for (long i = 0; i < n; i++)
        arr[i] = static_cast<int>(i);
    long sum = 0;
    for (long i = 0; i < n; i++)
        sum += arr[i];
    printf("  Sum of 0..%ld = %ld\n", n - 1, sum);
}

// ============================================================================
// Main
// ============================================================================

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <mode> [param]\n", argv[0]);
        printf("\nModes:\n");
        printf("  0         Memcheck: heap overflow, use-after-free, leak, uninit\n");
        printf("  1 [N]     Cachegrind: sequential vs random (N elements, default 1000000)\n");
        printf("  2 [N]     Callgrind: recursive vs iterative fib (N, default 35)\n");
        printf("  3 [N]     Helgrind: data race (N increments/thread, default 100000)\n");
        printf("  4 [N]     Massif: heap growth (N rounds, default 20)\n");
        printf("  5 [N]     Clean: correct baseline (N elements, default 1000000)\n");
        return 1;
    }

    int mode = atoi(argv[1]);
    long param = (argc > 2) ? atol(argv[2]) : 0;

    switch (mode) {
        case 0:
            run_memcheck_targets();
            break;
        case 1:
            run_cachegrind_targets(param > 0 ? param : 1000000);
            break;
        case 2:
            run_callgrind_targets(param > 0 ? (int)param : 35);
            break;
        case 3:
            run_helgrind_targets(param > 0 ? (int)param : 100000);
            break;
        case 4:
            run_massif_targets(param > 0 ? (int)param : 20);
            break;
        case 5:
            run_clean_baseline(param > 0 ? param : 1000000);
            break;
        default:
            fprintf(stderr, "Unknown mode: %d\n", mode);
            return 1;
    }
    return 0;
}
