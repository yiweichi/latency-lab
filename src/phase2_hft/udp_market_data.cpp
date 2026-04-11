// HFT Experiment: UDP Market Data Receiver
// Purpose: Simulate receiving market data over UDP and processing it
//          This is the core hot path in any HFT system
//
// Architecture:
//   [sender thread] --UDP--> [receiver thread] --> [orderbook update] --> [latency measurement]
//
// Key profiling targets:
//   - perf: syscall overhead of recvfrom()
//   - bpftrace: network stack latency
//   - ftrace: kernel network path (softirq, etc)
//   - VTune: overall pipeline analysis

#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <thread>
#include <atomic>
#include <vector>
#include <algorithm>
#include <cstring>
#include <cmath>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#pragma pack(push, 1)
struct MarketDataMsg {
    uint64_t sequence;
    uint64_t send_timestamp_ns;
    uint32_t symbol_id;
    uint32_t price;
    uint32_t quantity;
    uint8_t  side;       // 0 = bid, 1 = ask
    uint8_t  msg_type;   // 0 = add, 1 = cancel, 2 = trade
    uint8_t  padding[2];
};
#pragma pack(pop)

static_assert(sizeof(MarketDataMsg) == 32, "MarketDataMsg should be 32 bytes");

static uint64_t now_ns() {
    auto tp = std::chrono::high_resolution_clock::now();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(tp.time_since_epoch()).count();
}

std::atomic<bool> running{true};

void sender_thread(int port, long messages, int rate_us) {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { perror("socket"); return; }

    struct sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);

    MarketDataMsg msg{};
    msg.symbol_id = 1;

    for (long i = 0; i < messages && running; i++) {
        msg.sequence = i;
        msg.send_timestamp_ns = now_ns();
        msg.price = 10000 + (i % 1000);
        msg.quantity = 100;
        msg.side = i % 2;
        msg.msg_type = 0;

        sendto(sock, &msg, sizeof(msg), 0,
               (struct sockaddr*)&addr, sizeof(addr));

        if (rate_us > 0) {
            // Busy-wait for precise timing (usleep is too imprecise for HFT)
            uint64_t target = now_ns() + rate_us * 1000ULL;
            while (now_ns() < target) {
#if defined(__x86_64__)
                __asm__ volatile("pause" ::: "memory");
#elif defined(__aarch64__)
                __asm__ volatile("yield" ::: "memory");
#endif
            }
        }
    }

    close(sock);
}

void receiver_thread(int port, long messages, std::vector<double>& latencies) {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { perror("socket"); return; }

    int reuse = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    struct sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sock);
        return;
    }

    // Set receive timeout
    struct timeval tv;
    tv.tv_sec = 5;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    MarketDataMsg msg;
    latencies.reserve(messages);

    for (long i = 0; i < messages; i++) {
        ssize_t n = recvfrom(sock, &msg, sizeof(msg), 0, nullptr, nullptr);
        if (n <= 0) break;

        uint64_t recv_time = now_ns();
        double latency = static_cast<double>(recv_time - msg.send_timestamp_ns);
        latencies.push_back(latency);
    }

    running = false;
    close(sock);
}

int main(int argc, char* argv[]) {
    long messages = 1'000'000;
    int rate_us = 1;  // 1us between messages = 1M msg/sec
    int port = 12345;

    if (argc > 1) messages = atol(argv[1]);
    if (argc > 2) rate_us = atoi(argv[2]);
    if (argc > 3) port = atoi(argv[3]);

    printf("=== UDP Market Data Latency Test ===\n");
    printf("Messages: %ld\n", messages);
    printf("Rate: 1 msg per %d us (%d msg/sec)\n", rate_us, rate_us > 0 ? 1'000'000 / rate_us : 0);
    printf("Port: %d\n\n", port);

    std::vector<double> latencies;

    std::thread recv_t(receiver_thread, port, messages, std::ref(latencies));

    // Small delay to let receiver bind
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    std::thread send_t(sender_thread, port, messages, rate_us);

    send_t.join();
    recv_t.join();

    if (latencies.empty()) {
        printf("ERROR: No messages received\n");
        return 1;
    }

    std::sort(latencies.begin(), latencies.end());

    double sum = 0;
    for (auto l : latencies) sum += l;

    printf("Received: %zu messages\n", latencies.size());
    printf("Mean:     %.0f ns (%.2f us)\n", sum / latencies.size(), sum / latencies.size() / 1000);
    printf("p50:      %.0f ns\n", latencies[latencies.size() * 50 / 100]);
    printf("p90:      %.0f ns\n", latencies[latencies.size() * 90 / 100]);
    printf("p99:      %.0f ns\n", latencies[latencies.size() * 99 / 100]);
    printf("p999:     %.0f ns\n", latencies[latencies.size() * 999 / 1000]);
    printf("Max:      %.0f ns\n", latencies.back());

    return 0;
}
