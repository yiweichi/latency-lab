#pragma once

#define TASK_COMM_LEN 16

#ifdef __VMLINUX_H__
struct syscall_event {
    __u32 pid;
    __u32 tid;
    __s32 fd;
    __u64 count;
    char comm[TASK_COMM_LEN];
};
#else
#include <stdint.h>

struct syscall_event {
    uint32_t pid;
    uint32_t tid;
    int32_t fd;
    uint64_t count;
    char comm[TASK_COMM_LEN];
};
#endif
