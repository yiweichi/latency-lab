#pragma once

#define TASK_COMM_LEN 16
#define SYSCALL_CAPTURE_BYTES 64

#ifdef __VMLINUX_H__
struct syscall_event {
    __u32 pid;
    __u32 tid;
    __s32 fd;
    __u64 count;
    __u32 captured_len;
    char comm[TASK_COMM_LEN];
    char data[SYSCALL_CAPTURE_BYTES];
};
#else
#include <stdint.h>

struct syscall_event {
    uint32_t pid;
    uint32_t tid;
    int32_t fd;
    uint64_t count;
    uint32_t captured_len;
    char comm[TASK_COMM_LEN];
    char data[SYSCALL_CAPTURE_BYTES];
};
#endif
