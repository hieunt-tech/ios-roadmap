import Foundation
import LabCore
import LabTestSupport
import Testing
#if SOLUTION
import Solutions
#else
import Exercises
#endif

private func event(_ id: Int) -> AnalyticsEvent {
    AnalyticsEvent(id: id, name: "event-\(id)")
}

@Suite("Bài 4 · EventBatcher")
struct Bai4EventBatcherTests {

    @Test("10.000 sự kiện log từ nhiều thread: không mất, không trùng, không upload song song")
    func concurrentLoggingIsSafe() async throws {
        let uploader = RecordingUploader()
        let batcher = EventBatcher(uploader: uploader, batchSize: 100, maxBufferedEvents: 20_000)

        // Mô phỏng code cũ gọi log từ nhiều thread GCD cùng lúc.
        DispatchQueue.concurrentPerform(iterations: 10_000) { index in
            batcher.log(AnalyticsEvent(id: index, name: "tap"))
        }
        try await withTimeout(10) { await batcher.flush() }

        let ids = uploader.uploadedEvents.map(\.id)
        #expect(ids.count == 10_000, "Gửi \(ids.count)/10.000 sự kiện")
        #expect(Set(ids).count == 10_000, "Có sự kiện bị gửi trùng")
        #expect(uploader.maxConcurrentUploads == 1, "Có \(uploader.maxConcurrentUploads) upload chạy song song")
        #expect(batcher.bufferedCount == 0)
        #expect(batcher.droppedCount == 0)
    }

    @Test("Sự kiện log trong lúc đang upload không bị mất")
    func eventsLoggedDuringUploadSurvive() async throws {
        let uploader = ControlledUploader()
        let batcher = EventBatcher(uploader: uploader, batchSize: 3)

        for id in 0..<3 { batcher.log(event(id)) }   // chạm batchSize → tự flush
        try await withTimeout { try await uploader.calls.pendingCount.wait(atLeast: 1) }

        batcher.log(event(3))                       // log trong lúc upload đang bay
        batcher.log(event(4))
        uploader.calls.resolveAll(with: .success(()))

        let flushing = Task { await batcher.flush() }
        try await withTimeout { try await uploader.calls.pendingCount.wait(atLeast: 1) }
        uploader.calls.resolveAll(with: .success(()))
        try await finish(flushing)

        #expect(uploader.calls.inputs.flatMap { $0 } == (0..<5).map(event))
        #expect(batcher.bufferedCount == 0)
    }

    @Test("Upload lỗi: sự kiện được xếp lại đầu hàng đợi đúng thứ tự, lần flush sau gửi lại")
    func failedUploadIsRetriedInOrder() async throws {
        let uploader = ControlledUploader()
        let batcher = EventBatcher(uploader: uploader, batchSize: 10)

        for id in 0..<4 { batcher.log(event(id)) }
        let first = Task { await batcher.flush() }
        try await withTimeout { try await uploader.calls.pendingCount.wait(atLeast: 1) }

        batcher.log(event(4))   // đến sau, phải đứng sau 0...3
        uploader.calls.resolveAll(with: .failure(URLError(.notConnectedToInternet)))
        try await finish(first)
        #expect(batcher.bufferedCount == 5)

        let second = Task { await batcher.flush() }
        try await withTimeout { try await uploader.calls.pendingCount.wait(atLeast: 1) }
        uploader.calls.resolveAll(with: .success(()))
        try await finish(second)

        #expect(uploader.calls.inputs.last == (0..<5).map(event))
        #expect(batcher.bufferedCount == 0)
    }

    @Test("Offline lâu: buffer có giới hạn, bỏ sự kiện cũ nhất và đếm số bị bỏ")
    func bufferDropsOldestWhenFull() async throws {
        let uploader = RecordingUploader()
        let batcher = EventBatcher(uploader: uploader, batchSize: 100, maxBufferedEvents: 10)

        for id in 0..<15 { batcher.log(event(id)) }

        #expect(batcher.bufferedCount == 10)
        #expect(batcher.droppedCount == 5)

        try await withTimeout { await batcher.flush() }
        #expect(uploader.uploadedEvents == (5..<15).map(event), "Phải giữ 10 sự kiện MỚI nhất.")
    }

    @Test("Hai lần flush cùng lúc: chỉ một upload, không gửi trùng")
    func concurrentFlushesDoNotDuplicate() async throws {
        let uploader = ControlledUploader()
        let batcher = EventBatcher(uploader: uploader, batchSize: 10)

        for id in 0..<5 { batcher.log(event(id)) }
        let a = Task { await batcher.flush() }   // ví dụ: app vào background
        let b = Task { await batcher.flush() }   // ví dụ: timer định kỳ
        try await withTimeout { try await uploader.calls.pendingCount.wait(atLeast: 1) }
        try await settle()

        #expect(uploader.calls.pendingCount.value == 1, "Có \(uploader.calls.pendingCount.value) upload cùng bay")
        uploader.calls.resolveAll(with: .success(()))
        try await finish(a)
        try await finish(b)

        #expect(uploader.calls.inputs == [(0..<5).map(event)])
    }
}
