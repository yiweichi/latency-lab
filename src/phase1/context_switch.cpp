// Experiment D: Context Switch Cost Measurement
// Purpose: Measure thread-to-thread context switch latency via pipe ping-pong
// Expected: ~1-5us per context switch on modern hardware
//
// Key questions:
//   1. What is the raw context switch cost?
//   2. How does CPU pinning affect it? (sched_setaffinity)
//   3. What does perf sched show?
//   4. What does ftrace sched_switch show?
//   5. How does bpftrace see the wakeup->run delay?

#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <unistd.h>
#include <pthread.h>
#include <sched.h>
#include <cstring>
#include <algorithm>
#include <vector>
#include <cmath>

struct ThreadArgs {
    int read_fd;
    int write_fd;
    long iterations;
    int cpu_id;  // -1 = no pinning
};

static void pin_to_cpu(int cpu) {
#ifdef __linux__
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu, &cpuset);
    if (pthread_setaffinity_np(pthread_self(), sizeof(cpuset), &cpuset) != 0) {
        perror("pthread_setaffinity_np");
    }
#else
    (void)cpu;
#endif
}

void* ping_thread(void* arg) {
    auto* args = static_cast<ThreadArgs*>(arg);
    if (args->cpu_id >= 0) pin_to_cpu(args->cpu_id);

    char buf = 'p';
    for (long i = 0; i < args->iterations; i++) {
        write(args->write_fd, &buf, 1);
        read(args->read_fd, &buf, 1);
    }
    return nullptr;
}

void* pong_thread(void* arg) {
    auto* args = static_cast<ThreadArgs*>(arg);
    if (args->cpu_id >= 0) pin_to_cpu(args->cpu_id);

    char buf;
    for (long i = 0; i < args->iterations; i++) {
        read(args->read_fd, &buf, 1);
        write(args->write_fd, &buf, 1);
    }
    return nullptr;
}

void measure_pipe_context_switch(long iterations, int ping_cpu, int pong_cpu) {
    int pipe1[2], pipe2[2];
    pipe(pipe1);  // ping writes, pong reads
    pipe(pipe2);  // pong writes, ping reads

    ThreadArgs ping_args = {pipe2[0], pipe1[1], iterations, ping_cpu};
    ThreadArgs pong_args = {pipe1[0], pipe2[1], iterations, pong_cpu};

    pthread_t t_ping, t_pong;

    auto start = std::chrono::high_resolution_clock::now();

    pthread_create(&t_pong, nullptr, pong_thread, &pong_args);
    pthread_create(&t_ping, nullptr, ping_thread, &ping_args);

    pthread_join(t_ping, nullptr);
    pthread_join(t_pong, nullptr);

    auto end = std::chrono::high_resolution_clock::now();
    double ns_total = std::chrono::duration<double, std::nano>(end - start).count();

    // Each iteration = 2 context switches (ping->pong, pong->ping)
    double ns_per_switch = ns_total / (iterations * 2);

    printf("Iterations: %ld (x2 switches each)\n", iterations);
    printf("Total: %.2f ms\n", ns_total / 1e6);
    printf("Per context switch: %.0f ns (%.2f us)\n", ns_per_switch, ns_per_switch / 1000.0);

    close(pipe1[0]); close(pipe1[1]);
    close(pipe2[0]); close(pipe2[1]);
}

void measure_with_histogram(long iterations, int ping_cpu, int pong_cpu) {
    int pipe1[2], pipe2[2];
    pipe(pipe1);
    pipe(pipe2);

    std::vector<double> latencies;
    latencies.reserve(iterations);

    if (ping_cpu >= 0) pin_to_cpu(ping_cpu);

    // Fork a child for the pong side
    pid_t pid = fork();
    if (pid == 0) {
        // Child = pong
        close(pipe1[1]); close(pipe2[0]);
        if (pong_cpu >= 0) pin_to_cpu(pong_cpu);
        char buf;
        for (long i = 0; i < iterations; i++) {
            read(pipe1[0], &buf, 1);
            write(pipe2[1], &buf, 1);
        }
        close(pipe1[0]); close(pipe2[1]);
        _exit(0);
    }

    // Parent = ping
    close(pipe1[0]); close(pipe2[1]);
    char buf = 'p';

    for (long i = 0; i < iterations; i++) {
        auto t0 = std::chrono::high_resolution_clock::now();
        write(pipe1[1], &buf, 1);
        read(pipe2[0], &buf, 1);
        auto t1 = std::chrono::high_resolution_clock::now();
        latencies.push_back(std::chrono::duration<double, std::nano>(t1 - t0).count());
    }

    close(pipe1[1]); close(pipe2[0]);

    int status;
    waitpid(pid, &status, 0);

    // Compute statistics
    std::sort(latencies.begin(), latencies.end());

    double sum = 0;
    for (auto l : latencies) sum += l;
    double mean = sum / latencies.size();

    double variance = 0;
    for (auto l : latencies) variance += (l - mean) * (l - mean);
    variance /= latencies.size();

    printf("\n--- Latency Histogram ---\n");
    printf("Samples:  %zu\n", latencies.size());
    printf("Mean:     %.0f ns (%.2f us)\n", mean, mean / 1000.0);
    printf("Stddev:   %.0f ns\n", sqrt(variance));
    printf("Min:      %.0f ns\n", latencies.front());
    printf("p50:      %.0f ns\n", latencies[latencies.size() * 50 / 100]);
    printf("p90:      %.0f ns\n", latencies[latencies.size() * 90 / 100]);
    printf("p99:      %.0f ns\n", latencies[latencies.size() * 99 / 100]);
    printf("p999:     %.0f ns\n", latencies[latencies.size() * 999 / 1000]);
    printf("Max:      %.0f ns\n", latencies.back());

    // ASCII histogram
    const int BUCKETS = 20;
    double lo = latencies[latencies.size() * 1 / 100];  // trim 1% outliers
    double hi = latencies[latencies.size() * 99 / 100];
    double bucket_width = (hi - lo) / BUCKETS;
    std::vector<int> hist(BUCKETS, 0);

    for (auto l : latencies) {
        int b = (int)((l - lo) / bucket_width);
        if (b < 0) b = 0;
        if (b >= BUCKETS) b = BUCKETS - 1;
        hist[b]++;
    }

    int max_count = *std::max_element(hist.begin(), hist.end());
    printf("\nDistribution (p1-p99):\n");
    for (int i = 0; i < BUCKETS; i++) {
        double bucket_lo = lo + i * bucket_width;
        int bar_len = (hist[i] * 60) / std::max(max_count, 1);
        printf("%8.0f ns |", bucket_lo);
        for (int j = 0; j < bar_len; j++) printf("#");
        printf(" (%d)\n", hist[i]);
    }
}

int main(int argc, char* argv[]) {
    int mode = 0;
    long iterations = 100'000L;

    if (argc > 1) mode = atoi(argv[1]);
    if (argc > 2) iterations = atol(argv[2]);

    switch (mode) {
        case 0:
            printf("[Mode 0] Thread ping-pong — no CPU pinning\n");
            measure_pipe_context_switch(iterations, -1, -1);
            break;
        case 1:
            printf("[Mode 1] Thread ping-pong — same CPU (worst case)\n");
            measure_pipe_context_switch(iterations, 0, 0);
            break;
        case 2:
            printf("[Mode 2] Thread ping-pong — different CPUs\n");
            measure_pipe_context_switch(iterations, 0, 1);
            break;
        case 3:
            printf("[Mode 3] Process ping-pong with latency histogram\n");
            measure_with_histogram(iterations, -1, -1);
            break;
        default:
            printf("Usage: %s [0-3] [iterations]\n", argv[0]);
            return 1;
    }

    return 0;
}
