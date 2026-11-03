import os

/// Bộ đếm an toàn luồng mà test có thể `await` cho tới khi đạt một ngưỡng.
///
/// Vì sao không dùng `Task.sleep` rồi kiểm tra? Vì sleep làm test chậm và vẫn có thể sai
/// trên máy CI yếu. `wait(atLeast:)` resume ĐÚNG lúc điều kiện thành sự thật, và
/// tôn trọng cancellation để `withTimeout` luôn dừng được.
public final class Metric: Sendable {
    private struct Waiter: Sendable {
        let target: Int
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State: Sendable {
        var value = 0
        var nextID = 0
        var waiters: [Int: Waiter] = [:]
        /// Id của những lần chờ bị huỷ TRƯỚC khi kịp đăng ký continuation.
        var cancelledEarly: Set<Int> = []
    }

    private enum Registration: Sendable {
        case ready, cancelled, waiting
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {}

    public var value: Int {
        state.withLock { (s: inout State) in s.value }
    }

    public func add(_ delta: Int = 1) {
        let ready = state.withLock { (s: inout State) -> [CheckedContinuation<Void, any Error>] in
            s.value += delta
            let current = s.value
            let hits = s.waiters.filter { $0.value.target <= current }
            for key in hits.keys { s.waiters.removeValue(forKey: key) }
            return hits.values.map(\.continuation)
        }
        // Resume NGOÀI lock: code chạy tiếp sau continuation không được giữ lock của ta.
        for continuation in ready { continuation.resume() }
    }

    /// Chờ tới khi `value >= target`. Ném `CancellationError` nếu task chờ bị huỷ.
    public func wait(atLeast target: Int) async throws {
        let id = state.withLock { (s: inout State) -> Int in
            s.nextID += 1
            return s.nextID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let registration = self.state.withLock { (s: inout State) -> Registration in
                    if s.cancelledEarly.remove(id) != nil { return .cancelled }
                    if s.value >= target { return .ready }
                    s.waiters[id] = Waiter(target: target, continuation: continuation)
                    return .waiting
                }
                switch registration {
                case .ready: continuation.resume()
                case .cancelled: continuation.resume(throwing: CancellationError())
                case .waiting: break
                }
            }
        } onCancel: {
            // onCancel có thể chạy TRƯỚC khi continuation được đăng ký (race kinh điển).
            // Khi đó ghi lại id để lúc đăng ký sẽ resume ngay bằng CancellationError.
            let waiter = self.state.withLock { (s: inout State) -> Waiter? in
                if let waiter = s.waiters.removeValue(forKey: id) { return waiter }
                s.cancelledEarly.insert(id)
                return nil
            }
            waiter?.continuation.resume(throwing: CancellationError())
        }
    }
}
