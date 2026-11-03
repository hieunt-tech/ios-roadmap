import Foundation
import LabCore
import Observation
import os

// ĐÁP ÁN BÀI 5 · Giải thích chi tiết: GIAI_THICH.md, mục Bài 5.
//
// PriceFeed:
//   1. Máy trạng thái kết nối: idle → connecting(task) → live(pump). Subscriber đến trong lúc
//      connecting thì chờ chung task đó → chỉ một kết nối.
//   2. Mỗi subscriber có `onTermination`: khi consumer ngừng lặp (task bị huỷ, stream bị giải phóng)
//      thì tự huỷ đăng ký. Subscriber cuối rời đi → đóng socket.
//   3. Mọi subscriber rời đi TRONG LÚC đang kết nối → kết nối xong thì đóng ngay.
//   4. Mỗi kết nối có id; vòng pump của kết nối cũ kết thúc muộn không phá kết nối mới.
//
// PriceViewModel:
//   5. Task bắt `[weak self]`, chỉ giữ self mạnh trong thân vòng lặp → không giữ ViewModel sống.
//   6. Task được giữ trong `SubscriptionHandle`; handle bị giải phóng cùng ViewModel và huỷ Task
//      trong deinit của nó → quên gọi stop() cũng không rò rỉ.
//   7. `generation` chặn task cũ (đã stop) ghi đè trạng thái của lần start mới.

public actor PriceFeed {
    private enum Connection {
        case idle
        case connecting(id: Int, task: Task<AsyncStream<PriceTick>, any Error>)
        case live(id: Int, pump: Task<Void, Never>)
    }

    private struct Subscriber {
        let symbol: String
        let continuation: AsyncStream<PriceTick>.Continuation
    }

    private let socket: any PriceSocket
    private var connection: Connection = .idle
    private var nextConnectionID = 0
    private var subscribers: [UUID: Subscriber] = [:]

    public init(socket: any PriceSocket) {
        self.socket = socket
    }

    public var subscriberCount: Int { subscribers.count }

    public func prices(for symbol: String) async throws -> AsyncStream<PriceTick> {
        let id = UUID()
        // Giá chứng khoán: chỉ cần giá mới nhất. Giữ một bộ đệm nhỏ để consumer chậm
        // không làm bộ nhớ tăng mãi (dùng .bufferingNewest(1) nếu muốn "chỉ giá cuối").
        let (stream, continuation) = AsyncStream.makeStream(
            of: PriceTick.self,
            bufferingPolicy: .bufferingNewest(64)
        )
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.unsubscribe(id) }
        }
        // Đăng ký TRƯỚC khi chờ kết nối để `subscriberCount` phản ánh đúng người đang chờ.
        subscribers[id] = Subscriber(symbol: symbol, continuation: continuation)

        do {
            try await ensureConnected()
        } catch {
            subscribers[id] = nil
            continuation.finish()
            throw error
        }
        return stream
    }

    // MARK: - Private

    private func ensureConnected() async throws {
        switch connection {
        case .live:
            return

        case .connecting(_, let task):
            _ = try await task.value

        case .idle:
            nextConnectionID += 1
            let connectionID = nextConnectionID
            let task = Task { [socket] in try await socket.connect() }
            connection = .connecting(id: connectionID, task: task)

            let ticks: AsyncStream<PriceTick>
            do {
                ticks = try await task.value
            } catch {
                if case .connecting(let current, _) = connection, current == connectionID {
                    connection = .idle
                }
                throw error
            }

            // Sau `await`: thế giới có thể đã đổi (actor reentrancy). Kiểm tra lại.
            guard case .connecting(let current, _) = connection, current == connectionID else { return }

            if subscribers.isEmpty {
                // Mọi người đã rời đi trong lúc đang kết nối.
                connection = .idle
                socket.disconnect()
                return
            }

            let pump = Task {
                for await tick in ticks {
                    self.dispatch(tick)
                }
                self.connectionEnded(id: connectionID)
            }
            connection = .live(id: connectionID, pump: pump)
        }
    }

    private func unsubscribe(_ id: UUID) {
        guard subscribers.removeValue(forKey: id) != nil, subscribers.isEmpty else { return }
        // Đang connecting: để `ensureConnected` tự đóng khi kết nối xong.
        guard case .live(_, let pump) = connection else { return }
        connection = .idle
        pump.cancel()
        socket.disconnect()
    }

    private func dispatch(_ tick: PriceTick) {
        for subscriber in subscribers.values where subscriber.symbol == tick.symbol {
            subscriber.continuation.yield(tick)
        }
    }

    /// Socket tự đóng (server ngắt, mất mạng). Kết thúc mọi stream để UI biết.
    /// Bài nâng cao: tự kết nối lại với exponential backoff thay vì kết thúc.
    private func connectionEnded(id: Int) {
        guard case .live(let current, _) = connection, current == id else { return }
        connection = .idle
        let ended = Array(subscribers.values)
        subscribers.removeAll()
        for subscriber in ended { subscriber.continuation.finish() }
    }
}

@MainActor
@Observable
public final class PriceViewModel {
    public private(set) var latest: PriceTick?
    public private(set) var isStreaming = false

    private let symbol: String
    private let feed: PriceFeed
    private let subscription = SubscriptionHandle()
    @ObservationIgnored private var generation = 0

    public init(symbol: String, feed: PriceFeed) {
        self.symbol = symbol
        self.feed = feed
    }

    public func start() {
        guard !isStreaming else { return }
        isStreaming = true
        generation += 1
        let myGeneration = generation

        let task = Task { [weak self, feed, symbol] in
            do {
                let stream = try await feed.prices(for: symbol)
                for await tick in stream {
                    // `self` mạnh chỉ sống trong một lượt lặp. Giữa các lượt (lúc đang await)
                    // không có tham chiếu mạnh nào tới ViewModel.
                    guard let self else { return }
                    self.latest = tick
                }
            } catch {
                // Không kết nối được: dừng stream, UI có thể hiện trạng thái offline.
            }
            guard let self, self.generation == myGeneration else { return }
            self.isStreaming = false
        }
        subscription.replace(with: task)
    }

    public func stop() {
        generation += 1
        subscription.replace(with: nil)
        isStreaming = false
    }
}

/// Giữ một Task và huỷ nó khi bị thay thế hoặc khi chính handle bị giải phóng.
///
/// Vì sao không huỷ trong `deinit` của ViewModel? Ở Swift 6, deinit của class @MainActor
/// là nonisolated nên không được đọc property @MainActor. Đặt việc huỷ vào deinit của một
/// object Sendable riêng tránh được vấn đề đó (Swift 6.2+ có thể dùng `isolated deinit`).
final class SubscriptionHandle: Sendable {
    private let task = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    func replace(with newTask: Task<Void, Never>?) {
        let old = task.withLock { (current: inout Task<Void, Never>?) -> Task<Void, Never>? in
            let old = current
            current = newTask
            return old
        }
        old?.cancel()
    }

    deinit {
        let current = task.withLock { (current: inout Task<Void, Never>?) in current }
        current?.cancel()
    }
}
