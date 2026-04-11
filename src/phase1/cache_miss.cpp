// Experiment B: Cache Miss Patterns
// Purpose: Understand L1/L2/L3/DRAM access latency differences
// Expected: Mode 0 = fast (sequential, prefetch-friendly)
//           Mode 1 = slower (stride defeats prefetcher)
//           Mode 2 = slowest (random access, every access = cache miss)
//
// Key questions:
//   1. Why does stride=64 kill performance? (one access per cache line)
//   2. Why is random access 10-50x slower than sequential?
//   3. What does perf show for cache-misses vs cache-references?
//   4. What does VTune show for memory-bound %?

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <random>
#include <algorithm>
#include <vector>

volatile int sink = 0;

void __attribute__((noinline)) sequential_access(int* arr, int n, int rounds) {
    for (int r = 0; r < rounds; r++) {
        for (int i = 0; i < n; i++) {
            sink += arr[i];
        }
    }
}

void __attribute__((noinline)) stride_access(int* arr, int n, int stride, int rounds) {
    for (int r = 0; r < rounds; r++) {
        for (int i = 0; i < n; i += stride) {
            arr[i] += 1;
        }
    }
}

void __attribute__((noinline)) random_access(int* arr, int* indices, int count, int rounds) {
    for (int r = 0; r < rounds; r++) {
        for (int i = 0; i < count; i++) {
            sink += arr[indices[i]];
        }
    }
}

void __attribute__((noinline)) pointer_chase(int* arr, int n, int rounds) {
    for (int r = 0; r < rounds; r++) {
        int idx = 0;
        for (int i = 0; i < n; i++) {
            idx = arr[idx];
            sink += idx;
        }
    }
}

int main(int argc, char* argv[]) {
    int mode = 0;
    int size_mb = 64;

    if (argc > 1) mode = atoi(argv[1]);
    if (argc > 2) size_mb = atoi(argv[2]);

    const int N = (size_mb * 1024 * 1024) / sizeof(int);
    int* arr = new int[N];

    // Initialize
    for (int i = 0; i < N; i++) arr[i] = i;

    auto start = std::chrono::high_resolution_clock::now();

    switch (mode) {
        case 0: {
            printf("[Mode 0] Sequential access — prefetch-friendly, L1 hit\n");
            printf("Array size: %d MB\n", size_mb);
            sequential_access(arr, N, 4);
            break;
        }
        case 1: {
            printf("[Mode 1] Stride-64 access — one access per cache line\n");
            printf("Array size: %d MB\n", size_mb);
            stride_access(arr, N, 16, 4);  // stride=16 ints = 64 bytes = 1 cache line
            break;
        }
        case 2: {
            printf("[Mode 2] Random access — cache miss storm\n");
            printf("Array size: %d MB\n", size_mb);

            int count = N / 16;
            int* indices = new int[count];
            std::mt19937 rng(42);
            for (int i = 0; i < count; i++) {
                indices[i] = rng() % N;
            }
            random_access(arr, indices, count, 4);
            delete[] indices;
            break;
        }
        case 3: {
            printf("[Mode 3] Pointer chase — worst case, no prefetch possible\n");
            printf("Array size: %d MB\n", size_mb);

            // Build a random permutation for pointer chasing
            std::vector<int> perm(N);
            for (int i = 0; i < N; i++) perm[i] = i;
            std::mt19937 rng(42);
            // Fisher-Yates shuffle to create single cycle
            for (int i = N - 1; i > 0; i--) {
                int j = rng() % (i + 1);
                std::swap(perm[i], perm[j]);
            }
            for (int i = 0; i < N; i++) arr[i] = perm[i];

            pointer_chase(arr, N / 4, 1);
            break;
        }
        default:
            printf("Usage: %s [0|1|2|3] [size_mb]\n", argv[0]);
            delete[] arr;
            return 1;
    }

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration<double, std::milli>(end - start).count();

    printf("Time: %.2f ms\n", ms);
    printf("Sink: %d\n", sink);

    delete[] arr;
    return 0;
}
