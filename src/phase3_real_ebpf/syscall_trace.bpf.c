// Minimal real eBPF program: trace sys_enter_write and push events via ringbuf.
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_core_read.h>
#include <bpf/bpf_tracing.h>
#include "syscall_trace.h"

char LICENSE[] SEC("license") = "Dual BSD/GPL";

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 1 << 24);
} events SEC(".maps");

SEC("tracepoint/syscalls/sys_enter_write")
int handle_sys_enter_write(struct trace_event_raw_sys_enter *ctx)
{
    struct syscall_event *event;
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    const char target[] = "syscall_storm";
    char comm[TASK_COMM_LEN];
    int i;

    bpf_get_current_comm(&comm, sizeof(comm));
#pragma unroll
    for (i = 0; i < (int)sizeof(target) - 1; i++) {
        if (comm[i] != target[i])
            return 0;
    }

    event = bpf_ringbuf_reserve(&events, sizeof(*event), 0);
    if (!event)
        return 0;

    event->pid = pid_tgid >> 32;
    event->tid = (__u32)pid_tgid;
    event->fd = (__s64)ctx->args[0];
    event->count = (__u64)ctx->args[2];
    __builtin_memcpy(event->comm, comm, sizeof(event->comm));

    bpf_ringbuf_submit(event, 0);
    return 0;
}
