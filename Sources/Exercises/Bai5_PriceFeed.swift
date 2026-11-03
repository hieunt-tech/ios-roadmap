import Foundation
import LabCore
import Observation

// ============================================================================
// BÀI 5 · PriceFeed + PriceViewModel — giá chứng khoán realtime qua WebSocket
// ============================================================================
//
// Sự cố production (app chứng khoán):
//   • Mở màn hình Watchlist và Chi tiết mã cùng lúc → server ghi nhận 2 kết nối WebSocket
//     từ cùng một thiết bị. Gói hạ tầng tính phí theo số kết nối.
//   • Đóng màn hình Chi tiết, Memory Graph vẫn thấy PriceViewModel sống, kèm Task của nó.
//     Mở/đóng 20 lần = 20 ViewModel ma, 20 vòng lặp `for await` vẫn chạy.
//   • Thoát hết các màn hình giá, socket vẫn mở → hao pin khi app ở background.
//   • Mở màn hình lại sau khi đã đóng hết thì không thấy giá nhảy nữa.
//
// Sửa để vượt qua Tests/LabTests/Bai5Tests.swift. Yêu cầu chi tiết: BAI_KIEM_TRA.md, mục Bài 5.

// MARK: - PriceFeed: một kết nối dùng chung cho mọi màn hình

public actor PriceFeed {
    private let socket: any PriceSocket
    private var subscribers: [UUID: (symbol: String, continuation: AsyncStream<PriceTick>.Continuation)] = [:]
    private var isConnected = false

    public init(socket: any PriceSocket) {
        self.socket = socket
    }

    /// Số subscriber đang lắng nghe.
    public var subscriberCount: Int { subscribers.count }

    /// Luồng giá của một mã. Luồng kết thúc khi người dùng ngừng lặp (task bị huỷ).
    public func prices(for symbol: String) async throws -> AsyncStream<PriceTick> {
        let (stream, continuation) = AsyncStream.makeStream(of: PriceTick.self)
        subscribers[UUID()] = (symbol, continuation)
        if !isConnected {
            let ticks = try await socket.connect()
            isConnected = true
            Task {
                for await tick in ticks {
                    self.dispatch(tick)
                }
            }
        }
        return stream
    }

    private func dispatch(_ tick: PriceTick) {
        for subscriber in subscribers.values where subscriber.symbol == tick.symbol {
            subscriber.continuation.yield(tick)
        }
    }
}

// MARK: - PriceViewModel: một màn hình hiển thị giá

@MainActor
@Observable
public final class PriceViewModel {
    public private(set) var latest: PriceTick?
    public private(set) var isStreaming = false

    private let symbol: String
    private let feed: PriceFeed
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(symbol: String, feed: PriceFeed) {
        self.symbol = symbol
        self.feed = feed
    }

    /// Gọi trong `.onAppear` / `viewWillAppear`.
    public func start() {
        isStreaming = true
        task = Task {
            guard let stream = try? await self.feed.prices(for: self.symbol) else { return }
            for await tick in stream {
                self.latest = tick
            }
        }
    }

    /// Gọi trong `.onDisappear` / `viewDidDisappear`.
    public func stop() {
        isStreaming = false
    }
}
