// Experiment A: Busy Loop + Memory Access
// Purpose: Baseline for IPC measurement, branch prediction, pipeline utilization
// Expected: High IPC (~2-4), minimal cache misses, high retiring %
//
// Key questions to answer:
//   1. What is the IPC? Why is it close to the theoretical max?
//   2. How many branch misses? (should be near zero — predictable loop)
//   3. What does VTune's top-down show? (mostly "Retiring")

#include <cstdio>
#include <cstdlib>
#include <chrono>

volatile int sink = 0;

void __attribute__((noinline)) hot_loop(long iterations) {
    for (long i = 0; i < iterations; i++) {
        sink += i;
    }
}

void __attribute__((noinline)) hot_loop_with_branch(long iterations) {
    for (long i = 0; i < iterations; i++) {
        if (i % 7 == 0)
            sink += i;
        else
            sink -= i;
    }
}

void __attribute__((noinline)) hot_loop_unpredictable(long iterations) {
    unsigned int state = 12345;
    for (long i = 0; i < iterations; i++) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        if (state & 1)
            sink += i;
        else
            sink -= i;
    }
}

int main(int argc, char* argv[]) {
    long iterations = 1'000'000'000L;
    int mode = 0;

    if (argc > 1) mode = atoi(argv[1]);
    if (argc > 2) iterations = atol(argv[2]);

    auto start = std::chrono::high_resolution_clock::now();

    switch (mode) {
        case 0:
            printf("[Mode 0] Predictable loop — high IPC baseline\n");
            hot_loop(iterations);
            break;
        case 1:
            printf("[Mode 1] Predictable branch — branch predictor handles it\n");
            hot_loop_with_branch(iterations);
            break;
        case 2:
            printf("[Mode 2] Unpredictable branch — branch miss storm\n");
            hot_loop_unpredictable(iterations);
            break;
        default:
            printf("Usage: %s [0|1|2] [iterations]\n", argv[0]);
            return 1;
    }

    auto end = std::chrono::high_resolution_clock::now();
    double ms = std::chrono::duration<double, std::milli>(end - start).count();

    printf("Iterations: %ld\n", iterations);
    printf("Time: %.2f ms\n", ms);
    printf("Sink: %d\n", sink);

    return 0;
}
