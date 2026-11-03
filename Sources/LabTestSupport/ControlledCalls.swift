import os

/// Ghi lại mọi lời gọi tới một dependency và GIỮ chúng lại cho tới khi test quyết định trả kết quả.
///
/// Đây là chìa khoá để tái hiện race condition một cách tất định: test điều khiển
/// chính xác request nào xong trước, request nào xong sau, request nào bị huỷ.
///
/// - `honorsCancellation = true`: lời gọi đang treo ném `CancellationError` khi task gọi bị huỷ
///   (giống `URLSession.data(from:)`).
/// - `honorsCancellation = false`: lời gọi phớt lờ cancellation (giống SDK cũ hoặc backend
///   không hỗ trợ huỷ). Code của bạn phải tự bỏ qua kết quả trả về muộn.
public final class ControlledCalls<Input: Sendable, Output: Sendable>: Sendable {
    public typealias Responder = @Sendable (Input) throws -> Output

    private struct Entry: Sendable {
        let id: Int
        let input: Input
        let continuation: CheckedContinuation<Output, any Error>
    }

    private struct State: Sendable {
        var nextID = 0
        var inputs: [Input] = []
        var pending: [Entry] = []
        var cancelledBeforeSuspending: Set<Int> = []
        var responder: Responder?
    }

    private let state: OSAllocatedUnfairLock<State>
    private let honorsCancellation: Bool

    /// Tổng số lời gọi đã nhận.
    public let callCount = Metric()
    /// Số lời gọi đang treo chờ test trả kết quả.
    public let pendingCount = Metric()
    /// Số lời gọi đã bị huỷ trong lúc treo.
    public let cancelledCount = Metric()

    /// - Parameter responder: nếu có, mọi lời gọi được trả lời ngay (không treo).
    public init(honorsCancellation: Bool = true, responder: Responder? = nil) {
        self.honorsCancellation = honorsCancellation
        self.state = OSAllocatedUnfairLock(initialState: State(responder: responder))
    }

    /// Bật/tắt chế độ tự trả lời.
    public func respond(with responder: Responder?) {
        state.withLock { (s: inout State) in s.responder = responder }
    }

    /// Mọi input đã nhận, theo thứ tự.
    public var inputs: [Input] {
        state.withLock { (s: inout State) in s.inputs }
    }

    /// Input của các lời gọi đang treo, theo thứ tự đến.
    public var pendingInputs: [Input] {
        state.withLock { (s: inout State) in s.pending.map(\.input) }
    }

    public func call(_ input: Input) async throws -> Output {
        let (id, responder) = state.withLock { (s: inout State) -> (Int, Responder?) in
            s.nextID += 1
            s.inputs.append(input)
            return (s.nextID, s.responder)
        }
        callCount.add()
        if let responder { return try responder(input) }
        guard honorsCancellation else {
            return try await suspend(id: id, input: input)
        }
        return try await withTaskCancellationHandler {
            try await self.suspend(id: id, input: input)
        } onCancel: {
            self.cancel(id: id)
        }
    }

    /// Trả kết quả cho lời gọi đang treo ĐẦU TIÊN thoả điều kiện. Trả `false` nếu không có.
    @discardableResult
    public func resolve(first matches: (Input) -> Bool, with result: Result<Output, any Error>) -> Bool {
        let candidates = state.withLock { (s: inout State) in s.pending }
        guard let target = candidates.first(where: { matches($0.input) }) else { return false }
        let targetID = target.id
        let entry = state.withLock { (s: inout State) -> Entry? in
            guard let index = s.pending.firstIndex(where: { $0.id == targetID }) else { return nil }
            return s.pending.remove(at: index)
        }
        guard let entry else { return false }
        pendingCount.add(-1)
        entry.continuation.resume(with: result)
        return true
    }

    /// Trả kết quả cho lời gọi đang treo lâu nhất.
    @discardableResult
    public func resolveNext(with result: Result<Output, any Error>) -> Bool {
        resolve(first: { _ in true }, with: result)
    }

    /// Trả cùng một kết quả cho mọi lời gọi đang treo. Trả về số lời gọi đã được giải phóng.
    @discardableResult
    public func resolveAll(with result: Result<Output, any Error>) -> Int {
        let entries = state.withLock { (s: inout State) -> [Entry] in
            let all = s.pending
            s.pending.removeAll()
            return all
        }
        if !entries.isEmpty { pendingCount.add(-entries.count) }
        for entry in entries { entry.continuation.resume(with: result) }
        return entries.count
    }

    // MARK: - Private

    private func suspend(id: Int, input: Input) async throws -> Output {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Output, any Error>) in
            let alreadyCancelled = self.state.withLock { (s: inout State) -> Bool in
                if s.cancelledBeforeSuspending.remove(id) != nil { return true }
                s.pending.append(Entry(id: id, input: input, continuation: continuation))
                return false
            }
            if alreadyCancelled {
                self.cancelledCount.add()
                continuation.resume(throwing: CancellationError())
            } else {
                self.pendingCount.add()
            }
        }
    }

    private func cancel(id: Int) {
        let entry = state.withLock { (s: inout State) -> Entry? in
            if let index = s.pending.firstIndex(where: { $0.id == id }) {
                return s.pending.remove(at: index)
            }
            s.cancelledBeforeSuspending.insert(id)
            return nil
        }
        guard let entry else { return }
        pendingCount.add(-1)
        cancelledCount.add()
        entry.continuation.resume(throwing: CancellationError())
    }
}
