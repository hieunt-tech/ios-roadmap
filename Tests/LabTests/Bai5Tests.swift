import Foundation
import LabCore
import LabTestSupport
import Testing
#if SOLUTION
import Solutions
#else
import Exercises
#endif

private func tick(_ symbol: String, _ price: Decimal) -> PriceTick {
    PriceTick(symbol: symbol, price: price)
}

@Suite("Bài 5 · PriceFeed")
struct Bai5PriceFeedTests {

    @Test("Hai màn hình subscribe cùng lúc: chỉ mở 1 kết nối socket")
    func concurrentSubscribersShareOneConnection() async throws {
        let socket = FakePriceSocket(holdConnects: true)
        let feed = PriceFeed(socket: socket)

        let watchlist = Task { try await feed.prices(for: "FPT") }
        let detail = Task { try await feed.prices(for: "FPT") }
        try await withTimeout { try await socket.heldConnects.pendingCount.wait(atLeast: 1) }
        try await settle()
        socket.heldConnects.resolveAll(with: .success(()))

        let first = try await finish(watchlist)
        let second = try await finish(detail)
        #expect(socket.connectCount.value == 1, "Mở \(socket.connectCount.value) kết nối cho cùng một thiết bị.")

        socket.emit(tick("FPT", 128_500))
        #expect(try await firstValues(first, count: 1) == [tick("FPT", 128_500)])
        #expect(try await firstValues(second, count: 1) == [tick("FPT", 128_500)])
    }

    @Test("Giá được chuyển đúng mã cổ phiếu và giữ nguyên thứ tự")
    func ticksAreRoutedBySymbolInOrder() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)

        let fpt = try await withTimeout { try await feed.prices(for: "FPT") }
        let vnm = try await withTimeout { try await feed.prices(for: "VNM") }

        socket.emit(tick("FPT", 1))
        socket.emit(tick("VNM", 2))
        socket.emit(tick("FPT", 3))
        socket.emit(tick("FPT", 4))

        #expect(try await firstValues(fpt, count: 3) == [tick("FPT", 1), tick("FPT", 3), tick("FPT", 4)])
        #expect(try await firstValues(vnm, count: 1) == [tick("VNM", 2)])
    }

    @Test("Subscriber cuối cùng rời đi thì đóng socket; subscribe lại thì kết nối lại")
    func lastSubscriberClosesSocketAndResubscribeReconnects() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)

        let stream = try await withTimeout { try await feed.prices(for: "FPT") }
        let consumer = Task { for await _ in stream {} }
        consumer.cancel()   // người dùng rời màn hình

        try await withTimeout { try await socket.disconnectCount.wait(atLeast: 1) }
        try await eventually { await feed.subscriberCount == 0 }
        #expect(socket.openConnections == 0)
        #expect(socket.disconnectCount.value == 1)

        let again = try await withTimeout { try await feed.prices(for: "FPT") }
        #expect(socket.connectCount.value == 2, "Phải mở kết nối mới khi có người subscribe lại.")
        socket.emit(tick("FPT", 130_000))
        #expect(try await firstValues(again, count: 1) == [tick("FPT", 130_000)])
    }

    @Test("Một trong hai subscriber rời đi: socket vẫn mở, subscriber còn lại vẫn nhận giá")
    func remainingSubscriberKeepsReceiving() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)

        let leaving = try await withTimeout { try await feed.prices(for: "FPT") }
        let staying = try await withTimeout { try await feed.prices(for: "FPT") }
        let consumer = Task { for await _ in leaving {} }
        consumer.cancel()

        try await eventually { await feed.subscriberCount == 1 }
        #expect(socket.disconnectCount.value == 0)

        socket.emit(tick("FPT", 42))
        #expect(try await firstValues(staying, count: 1) == [tick("FPT", 42)])
    }
}

@Suite("Bài 5 · PriceViewModel")
@MainActor
struct Bai5PriceViewModelTests {

    @Test("ViewModel hiển thị giá mới nhất")
    func showsLatestTick() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)
        let vm = PriceViewModel(symbol: "FPT", feed: feed)

        vm.start()
        let price = tick("FPT", 101)
        try await eventually {
            socket.emit(price)
            return await vm.latest == price
        }
        #expect(vm.isStreaming)
    }

    @Test("stop() huỷ subscription và đóng socket")
    func stopCancelsSubscription() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)
        let vm = PriceViewModel(symbol: "FPT", feed: feed)

        vm.start()
        try await withTimeout { try await socket.connectCount.wait(atLeast: 1) }
        try await eventually { await feed.subscriberCount == 1 }

        vm.stop()
        #expect(vm.isStreaming == false)
        try await withTimeout { try await socket.disconnectCount.wait(atLeast: 1) }

        socket.emit(tick("FPT", 1))
        try await settle()
        #expect(vm.latest == nil)
    }

    @Test("Đóng màn hình mà quên gọi stop(): ViewModel vẫn được giải phóng và socket được đóng")
    func releasingViewModelCleansUp() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)
        var vm: PriceViewModel? = PriceViewModel(symbol: "FPT", feed: feed)

        vm?.start()
        try await withTimeout { try await socket.connectCount.wait(atLeast: 1) }
        try await eventually { await feed.subscriberCount == 1 }

        weak var released = vm
        vm = nil

        #expect(released == nil, "ViewModel vẫn còn sống: có thứ gì đó đang giữ tham chiếu mạnh tới nó.")
        try await withTimeout { try await socket.disconnectCount.wait(atLeast: 1) }
        try await eventually { await feed.subscriberCount == 0 }
    }

    @Test("Gọi start() hai lần không tạo hai subscription")
    func startIsIdempotent() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)
        let vm = PriceViewModel(symbol: "FPT", feed: feed)

        vm.start()
        vm.start()   // ví dụ: onAppear bị gọi 2 lần khi đổi tab
        try await withTimeout { try await socket.connectCount.wait(atLeast: 1) }
        try await eventually { await feed.subscriberCount >= 1 }
        try await settle(milliseconds: 100)

        #expect(await feed.subscriberCount == 1)
    }

    @Test("stop() rồi start() lại ngay (đổi tab qua lại): vẫn stream và nhận giá")
    func restartAfterStopKeepsStreaming() async throws {
        let socket = FakePriceSocket()
        let feed = PriceFeed(socket: socket)
        let vm = PriceViewModel(symbol: "FPT", feed: feed)

        vm.start()
        try await withTimeout { try await socket.connectCount.wait(atLeast: 1) }
        try await eventually { await feed.subscriberCount == 1 }

        vm.stop()
        vm.start()

        let price = tick("FPT", 7)
        try await eventually {
            socket.emit(price)
            return await vm.latest == price
        }
        try await settle()   // để task của lần start() cũ kịp kết thúc
        #expect(vm.isStreaming, "Task cũ kết thúc muộn đã ghi đè trạng thái của lần start() mới.")
        try await eventually { await feed.subscriberCount == 1 }
    }
}
