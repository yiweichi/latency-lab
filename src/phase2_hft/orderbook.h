#pragma once

#include <cstdint>
#include <cstring>
#include <map>
#include <unordered_map>
#include <array>

// Simple limit order book for profiling experiments
// NOT production code — intentionally has both fast and slow paths
// so you can observe the difference with profiling tools

struct Order {
    uint64_t order_id;
    uint32_t price;
    uint32_t quantity;
    bool is_buy;
};

// Version 1: std::map based (tree, cache-unfriendly)
class OrderBookMap {
public:
    void add_order(const Order& order) {
        if (order.is_buy) {
            bids_[order.price] += order.quantity;
        } else {
            asks_[order.price] += order.quantity;
        }
        orders_[order.order_id] = order;
    }

    void cancel_order(uint64_t order_id) {
        auto it = orders_.find(order_id);
        if (it == orders_.end()) return;
        const auto& order = it->second;
        if (order.is_buy) {
            auto pit = bids_.find(order.price);
            if (pit != bids_.end()) {
                pit->second -= order.quantity;
                if (pit->second <= 0) bids_.erase(pit);
            }
        } else {
            auto pit = asks_.find(order.price);
            if (pit != asks_.end()) {
                pit->second -= order.quantity;
                if (pit->second <= 0) asks_.erase(pit);
            }
        }
        orders_.erase(it);
    }

    uint32_t best_bid() const {
        if (bids_.empty()) return 0;
        return bids_.rbegin()->first;
    }

    uint32_t best_ask() const {
        if (asks_.empty()) return UINT32_MAX;
        return asks_.begin()->first;
    }

    uint32_t spread() const {
        return best_ask() - best_bid();
    }

    size_t depth() const {
        return orders_.size();
    }

private:
    std::map<uint32_t, int64_t> bids_;              // price -> total qty (descending)
    std::map<uint32_t, int64_t> asks_;               // price -> total qty (ascending)
    std::unordered_map<uint64_t, Order> orders_;     // order_id -> order
};

// Version 2: Array based (cache-friendly, fixed price range)
class OrderBookArray {
    static constexpr uint32_t PRICE_LEVELS = 65536;
    static constexpr uint32_t PRICE_OFFSET = 10000;

public:
    OrderBookArray() {
        memset(bid_qty_, 0, sizeof(bid_qty_));
        memset(ask_qty_, 0, sizeof(ask_qty_));
    }

    void add_order(const Order& order) {
        uint32_t idx = order.price - PRICE_OFFSET;
        if (idx >= PRICE_LEVELS) return;

        if (order.is_buy) {
            bid_qty_[idx] += order.quantity;
            if (order.price > best_bid_) best_bid_ = order.price;
        } else {
            ask_qty_[idx] += order.quantity;
            if (order.price < best_ask_) best_ask_ = order.price;
        }
        orders_[order.order_id] = order;
    }

    void cancel_order(uint64_t order_id) {
        auto it = orders_.find(order_id);
        if (it == orders_.end()) return;
        const auto& order = it->second;
        uint32_t idx = order.price - PRICE_OFFSET;
        if (idx >= PRICE_LEVELS) return;

        if (order.is_buy) {
            bid_qty_[idx] -= order.quantity;
            // Recompute best bid if needed
            if (order.price == best_bid_ && bid_qty_[idx] <= 0) {
                while (best_bid_ > PRICE_OFFSET && bid_qty_[best_bid_ - PRICE_OFFSET] <= 0)
                    best_bid_--;
            }
        } else {
            ask_qty_[idx] -= order.quantity;
            if (order.price == best_ask_ && ask_qty_[idx] <= 0) {
                while (best_ask_ < PRICE_OFFSET + PRICE_LEVELS && ask_qty_[best_ask_ - PRICE_OFFSET] <= 0)
                    best_ask_++;
            }
        }
        orders_.erase(it);
    }

    uint32_t best_bid() const { return best_bid_; }
    uint32_t best_ask() const { return best_ask_; }
    uint32_t spread() const { return best_ask_ - best_bid_; }
    size_t depth() const { return orders_.size(); }

private:
    int64_t bid_qty_[PRICE_LEVELS];
    int64_t ask_qty_[PRICE_LEVELS];
    std::unordered_map<uint64_t, Order> orders_;
    uint32_t best_bid_ = 0;
    uint32_t best_ask_ = PRICE_OFFSET + PRICE_LEVELS;
};
