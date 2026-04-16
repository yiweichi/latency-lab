// Experiment G: AddressSanitizer (ASan) Targets
// Purpose: Bugs that ASan catches — especially stack/global overflows
//          that Valgrind often misses.
//
// ASan vs Valgrind:
//   - ASan:     compile-time instrumentation, ~2x slowdown, catches stack/global
//   - Valgrind: binary translation, ~20-50x slowdown, catches heap only (mostly)
//
// Build with: g++ -fsanitize=address -fno-omit-frame-pointer -O0 -g ...
// Run:        ASAN_OPTIONS=detect_leaks=1 ./build/asan_targets <mode>
//
// Modes:
//   0 — Stack buffer overflow  (Valgrind often MISSES this)
//   1 — Heap buffer overflow
//   2 — Use-after-free
//   3 — Use-after-return      (needs ASAN_OPTIONS=detect_stack_use_after_return=1)
//   4 — Global buffer overflow (Valgrind MISSES this)
//   5 — Double free
//   6 — Memory leak           (needs detect_leaks=1)
//   7 — Stack use after scope
//   8 — Clean baseline

#include <cstdio>
#include <cstdlib>
#include <cstring>

volatile int sink = 0;

// ============================================================================
// Mode 0: Stack buffer overflow — Valgrind usually CANNOT catch this
// ============================================================================

static void __attribute__((noinline)) stack_overflow() {
    int arr[10];
    for (int i = 0; i < 10; i++) arr[i] = i;
    printf("  Writing arr[10] on the stack (out of bounds)...\n");
    arr[10] = 42;  // ASan: stack-buffer-overflow
    sink = arr[0];
}

// ============================================================================
// Mode 1: Heap buffer overflow
// ============================================================================

static void __attribute__((noinline)) heap_overflow() {
    int* arr = new int[10];
    for (int i = 0; i < 10; i++) arr[i] = i;
    printf("  Writing arr[10] on the heap (out of bounds)...\n");
    arr[10] = 42;  // ASan: heap-buffer-overflow
    sink = arr[0];
    delete[] arr;
}

// ============================================================================
// Mode 2: Use-after-free
// ============================================================================

static void __attribute__((noinline)) use_after_free() {
    int* p = new int(42);
    printf("  Deleting p, then reading *p...\n");
    delete p;
    sink = *p;  // ASan: heap-use-after-free
}

// ============================================================================
// Mode 3: Use-after-return
// Needs: ASAN_OPTIONS=detect_stack_use_after_return=1
// ============================================================================

static int* __attribute__((noinline)) return_local_ptr() {
    int local = 123;
    return &local;  // returning address of stack variable
}

static void __attribute__((noinline)) use_after_return() {
    printf("  Returning pointer to local, then reading it...\n");
    int* p = return_local_ptr();
    sink = *p;  // ASan: stack-use-after-return (with flag)
}

// ============================================================================
// Mode 4: Global buffer overflow — Valgrind CANNOT catch this
// ============================================================================

static int global_arr[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

static void __attribute__((noinline)) global_overflow() {
    printf("  Reading global_arr[10] (out of bounds)...\n");
    sink = global_arr[10];  // ASan: global-buffer-overflow
}

// ============================================================================
// Mode 5: Double free
// ============================================================================

static void __attribute__((noinline)) double_free() {
    int* p = new int(42);
    printf("  Freeing p twice...\n");
    delete p;
    delete p;  // ASan: attempting double-free
}

// ============================================================================
// Mode 6: Memory leak (needs ASAN_OPTIONS=detect_leaks=1)
// ============================================================================

static void __attribute__((noinline)) leak_memory() {
    printf("  Allocating 4KB and never freeing...\n");
    int* leaked = new int[1024];
    leaked[0] = 1;
    sink = leaked[0];
    // never freed — ASan LeakSanitizer reports this
}

// ============================================================================
// Mode 7: Stack use after scope
// ============================================================================

static void __attribute__((noinline)) use_after_scope() {
    int* p;
    {
        int local = 42;
        p = &local;
    }
    printf("  Reading local after its scope ended...\n");
    sink = *p;  // ASan: stack-use-after-scope (with -fsanitize-address-use-after-scope)
}

// ============================================================================
// Mode 8: Clean baseline
// ============================================================================

static void __attribute__((noinline)) clean_baseline() {
    printf("  No bugs. ASan should report nothing.\n");
    int arr[10];
    for (int i = 0; i < 10; i++) arr[i] = i;
    int sum = 0;
    for (int i = 0; i < 10; i++) sum += arr[i];
    printf("  Sum = %d\n", sum);
}

// ============================================================================
// Main
// ============================================================================

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <mode>\n", argv[0]);
        printf("\nModes:\n");
        printf("  0   Stack buffer overflow  (Valgrind often misses!)\n");
        printf("  1   Heap buffer overflow\n");
        printf("  2   Use-after-free\n");
        printf("  3   Use-after-return       (set ASAN_OPTIONS=detect_stack_use_after_return=1)\n");
        printf("  4   Global buffer overflow (Valgrind misses!)\n");
        printf("  5   Double free\n");
        printf("  6   Memory leak            (set ASAN_OPTIONS=detect_leaks=1)\n");
        printf("  7   Stack use after scope\n");
        printf("  8   Clean baseline\n");
        printf("\nASan vs Valgrind:\n");
        printf("  ASan catches stack & global overflows that Valgrind cannot.\n");
        printf("  ASan is ~2x slower; Valgrind is ~20-50x slower.\n");
        return 1;
    }

    int mode = atoi(argv[1]);
    printf("=== ASan Experiment — Mode %d ===\n\n", mode);

    switch (mode) {
        case 0: stack_overflow(); break;
        case 1: heap_overflow(); break;
        case 2: use_after_free(); break;
        case 3: use_after_return(); break;
        case 4: global_overflow(); break;
        case 5: double_free(); break;
        case 6: leak_memory(); break;
        case 7: use_after_scope(); break;
        case 8: clean_baseline(); break;
        default:
            fprintf(stderr, "Unknown mode: %d\n", mode);
            return 1;
    }

    return 0;
}
