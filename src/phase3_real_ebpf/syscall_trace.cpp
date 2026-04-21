#include <bpf/libbpf.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "syscall_trace.h"
#include "syscall_trace.skel.h"

static volatile sig_atomic_t exiting = 0;

static void on_signal(int signo)
{
    (void)signo;
    exiting = 1;
}

static int handle_event(void *ctx, void *data, size_t data_sz)
{
    const struct syscall_event *event = (const struct syscall_event *)data;
    (void)ctx;
    if (data_sz < sizeof(*event))
        return 0;

    printf("WRITE pid=%u tid=%u fd=%d count=%u comm=%s\n",
           event->pid, event->tid, event->fd, event->count, event->comm);
    return 0;
}

static int handle_lost_events(void *ctx, int cpu, __u64 lost_cnt)
{
    (void)ctx;
    fprintf(stderr, "Lost %llu events on CPU %d\n",
            (unsigned long long)lost_cnt, cpu);
    return 0;
}

int main(void)
{
    struct ring_buffer *rb = NULL;
    struct syscall_trace_bpf *skel = NULL;
    int err;

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);

    libbpf_set_strict_mode(LIBBPF_STRICT_ALL);

    skel = syscall_trace_bpf__open_and_load();
    if (!skel) {
        fprintf(stderr, "Failed to open/load BPF skeleton\n");
        return 1;
    }

    err = syscall_trace_bpf__attach(skel);
    if (err) {
        fprintf(stderr, "Failed to attach BPF skeleton: %d\n", err);
        syscall_trace_bpf__destroy(skel);
        return 1;
    }

    rb = ring_buffer__new(bpf_map__fd(skel->maps.events), handle_event, NULL, NULL);
    if (!rb) {
        fprintf(stderr, "Failed to create ring buffer\n");
        syscall_trace_bpf__destroy(skel);
        return 1;
    }

    printf("real eBPF lab running. Trace target: comm=syscall_storm\n");
    printf("Now run: ./build/syscall_storm 3 1000\n");
    printf("Press Ctrl-C to stop.\n");

    while (!exiting) {
        err = ring_buffer__poll(rb, 250);
        if (err == -EINTR) {
            break;
        }
        if (err < 0) {
            fprintf(stderr, "ring_buffer__poll failed: %d\n", err);
            break;
        }
    }

    ring_buffer__free(rb);
    syscall_trace_bpf__destroy(skel);
    return err < 0 ? 1 : 0;
}
