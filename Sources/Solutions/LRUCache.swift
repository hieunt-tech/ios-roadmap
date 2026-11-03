/// Cache giới hạn theo tổng "chi phí" (số byte), loại phần tử ít dùng gần đây nhất.
///
/// Bản này dùng mảng `recency` nên `markUsed` là O(n). Với vài trăm ảnh thì đủ nhanh và dễ đọc.
/// Bản production nên dùng danh sách liên kết đôi + dictionary để mọi thao tác O(1),
/// hoặc dùng `NSCache` nếu chấp nhận để hệ thống tự quyết định loại phần tử nào.
struct LRUCache<Key: Hashable, Value> {
    private struct Entry {
        var value: Value
        var cost: Int
    }

    let capacity: Int
    private(set) var totalCost = 0
    private var entries: [Key: Entry] = [:]
    /// Thứ tự sử dụng: phần tử cũ nhất ở đầu mảng.
    private var recency: [Key] = []

    init(capacity: Int) {
        self.capacity = max(0, capacity)
    }

    /// Đọc mà không đổi thứ tự LRU.
    func peek(_ key: Key) -> Value? {
        entries[key]?.value
    }

    /// Đọc và đánh dấu vừa được dùng.
    mutating func value(for key: Key) -> Value? {
        guard let entry = entries[key] else { return nil }
        markUsed(key)
        return entry.value
    }

    mutating func insert(_ value: Value, for key: Key, cost: Int) {
        remove(key)
        // Một phần tử lớn hơn toàn bộ cache: không lưu, nếu không nó sẽ đẩy hết phần tử khác ra
        // rồi chính nó cũng không vừa.
        guard cost <= capacity else { return }
        entries[key] = Entry(value: value, cost: cost)
        recency.append(key)
        totalCost += cost
        while totalCost > capacity, let oldest = recency.first {
            remove(oldest)
        }
    }

    mutating func remove(_ key: Key) {
        guard let entry = entries.removeValue(forKey: key) else { return }
        totalCost -= entry.cost
        recency.removeAll { $0 == key }
    }

    mutating func removeAll() {
        entries.removeAll()
        recency.removeAll()
        totalCost = 0
    }

    private mutating func markUsed(_ key: Key) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }
}
