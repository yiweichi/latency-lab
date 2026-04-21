#pragma once

#include <stdint.h>

#define TASK_COMM_LEN 16

struct syscall_event {
    uint32_t pid;
    uint32_t tid;
    int32_t fd;
    uint32_t count;
    char comm[TASK_COMM_LEN];
};
