import Foundation
import LabCore
import LabTestSupport
import Testing
#if SOLUTION
import Solutions
#else
import Exercises
#endif

private let urlA = URL(string: "https://cdn.example.com/a.png")!
private let urlB = URL(string: "https://cdn.example.com/b.png")!
private let urlC = URL(string: "https://cdn.example.com/c.png")!
private let payload = Data([0xFF, 0xD8, 0xFF, 0xE0])

@Suite("Bài 1 · ImageLoader")
struct Bai1ImageLoaderTests {

    @Test("10 lời gọi đồng thời cùng URL chỉ tạo đúng 1 request mạng")
    func concurrentCallsShareOneRequest() async throws {
        let network = FakeImageNetwork()
        let loader = ImageLoader(network: network)

        let results = try await withTimeout {
            try await withThrowingTaskGroup(of: Data.self) { group in
                for _ in 0..<10 {
                    group.addTask { try await loader.image(for: urlA) }
                }
                try await network.calls.pendingCount.wait(atLeast: 1)
                try await settle()
                network.calls.resolveAll(with: .success(payload))

                var collected: [Data] = []
                for try await data in group { collected.append(data) }
                return collected
            }
        }

        #expect(results.count == 10)
        #expect(results.allSatisfy { $0 == payload })
        #expect(
            network.calls.callCount.value == 1,
            "Đã gửi \(network.calls.callCount.value) request cho cùng một ảnh. Gợi ý: actor reentrancy tại `await`."
        )
    }

    @Test("Ảnh đã tải được trả từ cache, không gọi mạng lần 2")
    func cachedImageIsReused() async throws {
        let network = FakeImageNetwork { _ in payload }
        let loader = ImageLoader(network: network)

        _ = try await withTimeout { try await loader.image(for: urlA) }
        let second = try await withTimeout { try await loader.image(for: urlA) }

        #expect(second == payload)
        #expect(network.calls.callCount.value == 1)
        #expect(await loader.cachedImage(for: urlA) == payload)
    }

    @Test("Lỗi mạng được trả cho mọi caller đang chờ và không bị cache")
    func failureIsSharedButNotCached() async throws {
        let network = FakeImageNetwork()
        let loader = ImageLoader(network: network)

        let first = Task { try await loader.image(for: urlA) }
        let second = Task { try await loader.image(for: urlA) }
        try await withTimeout { try await network.calls.pendingCount.wait(atLeast: 1) }
        try await settle()
        network.calls.resolveAll(with: .failure(URLError(.timedOut)))

        await #expect(throws: URLError.self) { try await finish(first) }
        await #expect(throws: URLError.self) { try await finish(second) }
        #expect(await loader.cachedImage(for: urlA) == nil)

        // Lần gọi sau phải tải lại chứ không trả lỗi cũ.
        let retry = Task { try await loader.image(for: urlA) }
        try await withTimeout { try await network.calls.pendingCount.wait(atLeast: 1) }
        network.calls.resolveAll(with: .success(payload))

        #expect(try await finish(retry) == payload)
        #expect(network.calls.callCount.value == 2, "1 request cho hai caller đầu + 1 request retry")
    }

    @Test("Một caller huỷ thì caller còn lại vẫn nhận ảnh; download dùng chung không bị huỷ")
    func cancellingOneCallerKeepsSharedDownload() async throws {
        let network = FakeImageNetwork()
        let loader = ImageLoader(network: network)

        let leaving = Task { try await loader.image(for: urlA) }   // cell bị reuse
        let staying = Task { try await loader.image(for: urlA) }   // cell khác vẫn hiển thị
        try await withTimeout { try await network.calls.pendingCount.wait(atLeast: 1) }
        try await settle()

        leaving.cancel()
        await #expect(throws: CancellationError.self) { try await finish(leaving) }
        #expect(
            network.calls.cancelledCount.value == 0,
            "Request mạng không được huỷ khi vẫn còn caller khác đang chờ."
        )

        network.calls.resolveAll(with: .success(payload))
        #expect(try await finish(staying) == payload)
        #expect(network.calls.callCount.value == 1)
    }

    @Test("Mọi caller huỷ thì request mạng bị huỷ; lần gọi sau tải mới bình thường")
    func cancellingAllCallersCancelsDownload() async throws {
        let network = FakeImageNetwork()
        let loader = ImageLoader(network: network)

        let a = Task { try await loader.image(for: urlA) }
        let b = Task { try await loader.image(for: urlA) }
        try await withTimeout { try await network.calls.pendingCount.wait(atLeast: 1) }
        try await settle()

        a.cancel()
        b.cancel()
        await #expect(throws: CancellationError.self) { try await finish(a) }
        await #expect(throws: CancellationError.self) { try await finish(b) }
        try await withTimeout { try await network.calls.cancelledCount.wait(atLeast: 1) }
        try await settle()
        #expect(network.calls.cancelledCount.value == 1, "Chỉ có một request, và nó phải bị huỷ đúng một lần.")

        let again = Task { try await loader.image(for: urlA) }
        try await withTimeout { try await network.calls.pendingCount.wait(atLeast: 1) }
        network.calls.resolveAll(with: .success(payload))
        #expect(try await finish(again) == payload)
        #expect(await loader.cachedImage(for: urlA) == payload)
    }

    @Test("Cache giới hạn theo dung lượng, loại ảnh ít dùng gần đây nhất (LRU)")
    func cacheEvictsLeastRecentlyUsed() async throws {
        let network = FakeImageNetwork { _ in Data(count: 6) }
        let loader = ImageLoader(network: network, cacheCapacityBytes: 12)

        _ = try await withTimeout { try await loader.image(for: urlA) }   // [A]
        _ = try await withTimeout { try await loader.image(for: urlB) }   // [A, B]
        _ = try await withTimeout { try await loader.image(for: urlA) }   // A vừa dùng → [B, A]
        _ = try await withTimeout { try await loader.image(for: urlC) }   // 18 byte > 12 → loại B

        #expect(await loader.cachedImage(for: urlA) != nil)
        #expect(await loader.cachedImage(for: urlB) == nil, "B là ảnh ít dùng gần đây nhất, phải bị loại.")
        #expect(await loader.cachedImage(for: urlC) != nil)
        #expect(network.calls.callCount.value == 3)
    }

    @Test("Ảnh lớn hơn toàn bộ dung lượng cache vẫn được trả về nhưng không được cache")
    func oversizedImageIsNotCached() async throws {
        let network = FakeImageNetwork { _ in Data(count: 6) }
        let loader = ImageLoader(network: network, cacheCapacityBytes: 5)

        let data = try await withTimeout { try await loader.image(for: urlA) }

        #expect(data.count == 6)
        #expect(await loader.cachedImage(for: urlA) == nil)
    }
}
