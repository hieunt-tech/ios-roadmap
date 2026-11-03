import Foundation
import os

// Tiện ích để test code async KHÔNG BAO GIỜ treo vô hạn.
// Quy tắc của bộ test: không `await task.value` trực tiếp (không huỷ được khi quá hạn),
// luôn đi qua `withTimeout`, `finish(_:)` hoặc `eventually`.

public struct TimeoutError: Error, CustomStringConvertible {
    public let seconds: Double
    public init(seconds: Double) { self.seconds = seconds }
    public var description: String {
        "Quá \(seconds)s mà chưa xong — có thể code đang treo (deadlock, continuation không được resume, hoặc chờ một việc không bao giờ xảy ra)."
    }
}

/// Chạy `operation`, ném `TimeoutError` nếu quá `seconds` giây. Operation bị huỷ khi quá hạn.
public func withTimeout<T: Sendable>(
    _ seconds: Double = 2,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError(seconds: seconds)
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw CancellationError() }
        return first
    }
}

/// Chờ một `Task` có thể ném lỗi kết thúc, có giới hạn thời gian.
/// Nếu quá hạn, task bị huỷ để không chạy ngầm làm ảnh hưởng test khác.
@discardableResult
public func finish<T: Sendable>(_ task: Task<T, any Error>, timeout seconds: Double = 2) async throws -> T {
    let box = ResultBox<Result<T, any Error>>()
    let done = Metric()
    Task {
        box.set(await task.result)
        done.add()
    }
    do {
        try await withTimeout(seconds) { try await done.wait(atLeast: 1) }
    } catch {
        task.cancel()
        throw error
    }
    guard let result = box.get() else { throw TimeoutError(seconds: seconds) }
    return try result.get()
}

/// Chờ một `Task` không ném lỗi kết thúc, có giới hạn thời gian. `nil` được coi là đã xong.
@discardableResult
public func finish<T: Sendable>(_ task: Task<T, Never>?, timeout seconds: Double = 2) async throws -> T? {
    guard let task else { return nil }
    let box = ResultBox<T>()
    let done = Metric()
    Task {
        box.set(await task.value)
        done.add()
    }
    do {
        try await withTimeout(seconds) { try await done.wait(atLeast: 1) }
    } catch {
        task.cancel()
        throw error
    }
    return box.get()
}

/// Kiểm tra lặp lại cho tới khi `condition` đúng, hoặc ném `TimeoutError`.
/// Dùng cho trạng thái được cập nhật bất đồng bộ mà không có điểm chờ rõ ràng.
public func eventually(
    timeout seconds: Double = 2,
    _ condition: @Sendable () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(seconds))
    while !(await condition()) {
        guard clock.now < deadline else { throw TimeoutError(seconds: seconds) }
        try await Task.sleep(for: .milliseconds(10))
    }
}

/// Lấy `count` phần tử đầu tiên của một async sequence, có giới hạn thời gian.
public func firstValues<S: AsyncSequence & Sendable>(
    _ sequence: S,
    count: Int,
    timeout seconds: Double = 2
) async throws -> [S.Element] where S.Element: Sendable {
    try await withTimeout(seconds) {
        var collected: [S.Element] = []
        for try await value in sequence {
            collected.append(value)
            if collected.count == count { break }
        }
        return collected
    }
}

/// Cho các task khác thời gian chạy tới điểm treo của chúng.
///
/// Chỉ dùng để LÀM LỘ lỗi của code sai (ví dụ: chờ để mọi caller kịp gửi request trùng).
/// Đáp án đúng không phụ thuộc vào khoảng chờ này.
public func settle(milliseconds: Int = 50) async throws {
    try await Task.sleep(for: .milliseconds(milliseconds))
}

/// Ô nhớ an toàn luồng chứa một giá trị.
public final class ResultBox<Value: Sendable>: Sendable {
    private let storage = OSAllocatedUnfairLock<Value?>(initialState: nil)
    public init() {}
    public func set(_ value: Value) {
        storage.withLock { (stored: inout Value?) in stored = value }
    }
    public func get() -> Value? {
        storage.withLock { (stored: inout Value?) in stored }
    }
}
