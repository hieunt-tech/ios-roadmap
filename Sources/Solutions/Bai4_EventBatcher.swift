import Foundation
import LabCore
import os

// ĐÁP ÁN BÀI 4 · Giải thích chi tiết: GIAI_THICH.md, mục Bài 4.
//
// Ý tưởng chính:
//   1. `log` phải đồng bộ → không dùng actor cho buffer. Dùng lock (OSAllocatedUnfairLock)
//      và giữ lock thật ngắn: chỉ append, cắt buffer, quyết định có tự flush hay không.
//   2. KHÔNG BAO GIỜ giữ lock qua `await`. Lấy batch ra khỏi buffer trong lock,
//      upload ngoài lock, lỗi thì trả batch về đầu buffer trong lock.
//   3. Mọi lần flush được xếp hàng tuần tự bằng một actor nhỏ (FlushSerializer):
//      tại mỗi thời điểm chỉ có một upload đang bay, không sự kiện nào bị gửi hai lần.
//   4. Buffer có giới hạn: đầy thì bỏ sự kiện CŨ NHẤT và đếm lại để báo cho đội data.

public final class EventBatcher: Sendable {
    private struct State: Sendable {
        var buffer: [AnalyticsEvent] = []
        var dropped = 0
        var autoFlushScheduled = false
    }

    private let uploader: any EventUploader
    private let batchSize: Int
    private let maxBufferedEvents: Int
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let serializer = FlushSerializer()

    public init(uploader: any EventUploader, batchSize: Int = 50, maxBufferedEvents: Int = 1_000) {
        precondition(batchSize > 0, "batchSize phải > 0")
        precondition(maxBufferedEvents > 0, "maxBufferedEvents phải > 0")
        self.uploader = uploader
        self.batchSize = batchSize
        self.maxBufferedEvents = maxBufferedEvents
    }

    public var bufferedCount: Int {
        state.withLock { (s: inout State) in s.buffer.count }
    }

    public var droppedCount: Int {
        state.withLock { (s: inout State) in s.dropped }
    }

    public func log(_ event: AnalyticsEvent) {
        let batchSize = self.batchSize
        let limit = self.maxBufferedEvents
        let shouldFlush = state.withLock { (s: inout State) -> Bool in
            s.buffer.append(event)
            Self.dropOverflow(&s, limit: limit)
            // Cờ `autoFlushScheduled` chặn "bão" Task khi log dồn dập vượt ngưỡng.
            guard s.buffer.count >= batchSize, !s.autoFlushScheduled else { return false }
            s.autoFlushScheduled = true
            return true
        }
        if shouldFlush {
            Task { await self.autoFlush() }
        }
    }

    public func flush() async {
        let work = await serializer.enqueue { [self] in
            await self.drain()
        }
        await work.value
    }

    // MARK: - Private

    private func autoFlush() async {
        state.withLock { (s: inout State) in s.autoFlushScheduled = false }
        await flush()
    }

    /// Gửi lần lượt từng batch cho tới khi buffer rỗng hoặc gặp lỗi. Luôn chạy tuần tự (qua serializer).
    private func drain() async {
        let batchSize = self.batchSize
        let limit = self.maxBufferedEvents
        while let batch = state.withLock({ (s: inout State) -> [AnalyticsEvent]? in
            guard !s.buffer.isEmpty else { return nil }
            let batch = Array(s.buffer.prefix(batchSize))
            s.buffer.removeFirst(batch.count)
            return batch
        }) {
            do {
                try await uploader.upload(batch)
            } catch {
                // Trả batch về ĐẦU hàng đợi để giữ thứ tự; sự kiện log trong lúc upload nằm sau nó.
                state.withLock { (s: inout State) in
                    s.buffer.insert(contentsOf: batch, at: 0)
                    Self.dropOverflow(&s, limit: limit)
                }
                return
            }
        }
    }

    private static func dropOverflow(_ s: inout State, limit: Int) {
        let overflow = s.buffer.count - limit
        guard overflow > 0 else { return }
        s.buffer.removeFirst(overflow)
        s.dropped += overflow
    }
}

/// Xếp các công việc async thành hàng đợi FIFO: việc sau chỉ bắt đầu khi việc trước xong.
///
/// Không thể dùng actor + `await` trực tiếp vì actor reentrant: tại điểm `await upload`,
/// một lời gọi flush khác sẽ chen vào. Chuỗi Task giải quyết điều đó.
private actor FlushSerializer {
    private var tail: Task<Void, Never>?

    func enqueue(_ work: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        let previous = tail
        let task = Task {
            await previous?.value
            await work()
        }
        tail = task
        return task
    }
}
