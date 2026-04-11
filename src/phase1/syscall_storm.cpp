// Experiment C: Syscall Cost Measurement
// Purpose: Understand syscall overhead, kernel entry/exit cost
// Expected: Each syscall costs ~100-500ns depending on type
//
// Key questions:
//   1. What is the cost of a single getpid() syscall?
//   2. How does read() compare to getpid()?
//   3. What does ftrace show during syscall execution?
//   4. What does bpftrace show for syscall latency distribution?

#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>
#include <time.h>
#include <sys/stat.h>

volatile int sink = 0;

void __attribute__((noinline)) syscall_getpid(long iterations) {
    for (long i = 0; i < iterations; i++) {
        sink += getpid();
    }
}

void __attribute__((noinline)) syscall_clock_gettime(long iterations) {
    struct timespec ts;
    for (long i = 0; i < iterations; i++) {
        clock_gettime(CLOCK_MONOTONIC, &ts);
        sink += ts.tv_nsec;
    }
}

void __attribute__((noinline)) syscall_read_devnull(long iterations) {
    int fd = open("/dev/null", O_RDONLY);
    if (fd < 0) {
        perror("open /dev/null");
        return;
    }
    char buf[1];
    for (long i = 0; i < iterations; i++) {
        read(fd, buf, 1);
    }
    close(fd);
}

void __attribute__((noinline)) syscall_write_devnull(long iterations) {
    int fd = open("/dev/null", O_WRONLY);
    if (fd < 0) {
        perror("open /dev/null");
        return;
    }
    char buf[1] = {'x'};
    for (long i = 0; i < iterations; i++) {
        write(fd, buf, 1);
    }
    close(fd);
}

void __attribute__((noinline)) syscall_stat(long iterations) {
    struct stat st;
    for (long i = 0; i < iterations; i++) {
        stat("/dev/null", &st);
    }
}

void __attribute__((noinline)) mixed_compute_and_syscall(long iterations) {
    int fd = open("/dev/null", O_WRONLY);
    char buf[1] = {'x'};
    for (long i = 0; i < iterations; i++) {
        // Some compute
        for (int j = 0; j < 100; j++) sink += j;
        // Then a syscall
        write(fd, buf, 1);
    }
    close(fd);
}

int main(int argc, char* argv[]) {
    int mode = 0;
    long iterations = 1'000'000L;

    if (argc > 1) mode = atoi(argv[1]);
    if (argc > 2) iterations = atol(argv[2]);

    auto start = std::chrono::high_resolution_clock::now();

    switch (mode) {
        case 0:
            printf("[Mode 0] getpid() — lightest syscall\n");
            syscall_getpid(iterations);
            break;
        case 1:
            printf("[Mode 1] clock_gettime() — VDSO optimized on Linux\n");
            syscall_clock_gettime(iterations);
            break;
        case 2:
            printf("[Mode 2] read(/dev/null) — real kernel entry\n");
            syscall_read_devnull(iterations);
            break;
        case 3:
            printf("[Mode 3] write(/dev/null) — write path\n");
            syscall_write_devnull(iterations);
            break;
        case 4:
            printf("[Mode 4] stat(/dev/null) — filesystem syscall\n");
            syscall_stat(iterations);
            break;
        case 5:
            printf("[Mode 5] Mixed compute + syscall — realistic pattern\n");
            mixed_compute_and_syscall(iterations);
            break;
        default:
            printf("Usage: %s [0-5] [iterations]\n", argv[0]);
            return 1;
    }

    auto end = std::chrono::high_resolution_clock::now();
    double ns_total = std::chrono::duration<double, std::nano>(end - start).count();
    double ns_per_op = ns_total / iterations;

    printf("Iterations: %ld\n", iterations);
    printf("Total: %.2f ms\n", ns_total / 1e6);
    printf("Per-op: %.1f ns\n", ns_per_op);
    printf("Sink: %d\n", sink);

    return 0;
}
