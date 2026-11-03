import Foundation
import LabCore
import os

// Fake cho từng bài. Mỗi fake mô phỏng một hành vi có thật của server/SDK
// mà code production thường xử lý sai.

// MARK: - Bài 1

/// Mạng tải ảnh. Mặc định mọi request TREO cho tới khi test gọi `calls.resolve...`.
public final class FakeImageNetwork: ImageNetwork {
    public let calls: ControlledCalls<URL, Data>

    public init(responder: ControlledCalls<URL, Data>.Responder? = nil) {
        calls = ControlledCalls(honorsCancellation: true, responder: responder)
    }

    public func data(from url: URL) async throws -> Data {
        try await calls.call(url)
    }
}

// MARK: - Bài 2

/// Server xác thực có refresh-token rotation, giống OAuth 2.1 / Auth0 / Firebase.
///
/// - Access token hợp lệ duy nhất là `validTokens.accessToken`.
/// - `refresh` thành công sẽ VÔ HIỆU refresh token cũ. Gọi refresh lần 2 bằng token cũ
///   → `RefreshError.invalidGrant` (đây là lý do refresh trùng làm người dùng bị đăng xuất).
public final class FakeAuthServer: AuthAPI {
    private struct State: Sendable {
        var validAccess: String
        var validRefresh: String
        var generation = 0
        var rejectEverything = false
        var nextRefreshError: (any Error)?
        var sendsToHold = 0
        var holdRefreshes = false
    }

    private let state: OSAllocatedUnfairLock<State>

    public let sendCount = Metric()
    public let refreshCount = Metric()
    /// Các lần `send` đang bị giữ lại (xem `holdNextSends`).
    public let heldSends = ControlledCalls<String, Void>()
    /// Các lần `refresh` đang bị giữ lại (xem `holdAllRefreshes`).
    public let heldRefreshes = ControlledCalls<String, Void>()

    public init(tokens: TokenPair) {
        state = OSAllocatedUnfairLock(initialState: State(
            validAccess: tokens.accessToken,
            validRefresh: tokens.refreshToken
        ))
    }

    public var validTokens: TokenPair {
        state.withLock { (s: inout State) in
            TokenPair(accessToken: s.validAccess, refreshToken: s.validRefresh)
        }
    }

    /// Access token phía client hết hạn (server không còn chấp nhận), refresh token vẫn còn dùng được.
    public func expireAccessToken() {
        state.withLock { (s: inout State) in s.validAccess = "server-side-access-\(UUID().uuidString)" }
    }

    /// Refresh token bị thu hồi (người dùng đổi mật khẩu, đăng xuất trên thiết bị khác...).
    public func revokeRefreshToken() {
        state.withLock { (s: inout State) in s.validRefresh = "revoked-\(UUID().uuidString)" }
    }

    /// Server từ chối MỌI request, kể cả token mới (ví dụ tài khoản bị khoá quyền).
    public func rejectAllRequests() {
        state.withLock { (s: inout State) in s.rejectEverything = true }
    }

    /// Lần refresh kế tiếp thất bại với lỗi cho trước (ví dụ mất mạng).
    public func failNextRefresh(with error: any Error) {
        state.withLock { (s: inout State) in s.nextRefreshError = error }
    }

    /// Giữ `count` lần `send` kế tiếp lại cho tới khi test gọi `heldSends.resolve...`.
    /// Token được kiểm tra lúc server TRẢ LỜI, không phải lúc nhận request.
    public func holdNextSends(_ count: Int) {
        state.withLock { (s: inout State) in s.sendsToHold = count }
    }

    /// Giữ mọi lần `refresh` lại cho tới khi test gọi `heldRefreshes.resolve...`.
    public func holdAllRefreshes() {
        state.withLock { (s: inout State) in s.holdRefreshes = true }
    }

    public func send(_ request: APIRequest, accessToken: String) async throws -> APIResponse {
        try Task.checkCancellation()
        sendCount.add()
        let shouldHold = state.withLock { (s: inout State) -> Bool in
            guard s.sendsToHold > 0 else { return false }
            s.sendsToHold -= 1
            return true
        }
        if shouldHold { try await heldSends.call(accessToken) }
        let accepted = state.withLock { (s: inout State) -> Bool in
            !s.rejectEverything && s.validAccess == accessToken
        }
        return accepted
            ? APIResponse(statusCode: 200, body: "ok \(request.path)")
            : APIResponse(statusCode: 401, body: "unauthorized")
    }

    public func refresh(refreshToken: String) async throws -> TokenPair {
        try Task.checkCancellation()
        refreshCount.add()
        let hold = state.withLock { (s: inout State) in s.holdRefreshes }
        if hold { try await heldRefreshes.call(refreshToken) }
        return try state.withLock { (s: inout State) throws -> TokenPair in
            if let error = s.nextRefreshError {
                s.nextRefreshError = nil
                throw error
            }
            guard refreshToken == s.validRefresh else { throw RefreshError.invalidGrant }
            s.generation += 1
            s.validAccess = "access-\(s.generation)"
            s.validRefresh = "refresh-\(s.generation)"
            return TokenPair(accessToken: s.validAccess, refreshToken: s.validRefresh)
        }
    }
}

// MARK: - Bài 3

/// API tìm kiếm PHỚT LỜ cancellation: request đã gửi đi vẫn trả kết quả về, dù muộn.
/// Đây là tình huống thật với nhiều backend và SDK.
public final class FakeSearchAPI: SearchAPI {
    public let calls: ControlledCalls<String, [String]>

    public init(responder: ControlledCalls<String, [String]>.Responder? = nil) {
        calls = ControlledCalls(honorsCancellation: false, responder: responder)
    }

    public func search(_ query: String) async throws -> [String] {
        try await calls.call(query)
    }
}

/// Bỏ qua thời gian chờ nhưng vẫn tôn trọng cancellation.
public struct ImmediateSleeper: Sleeper {
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        await Task.yield()
    }
}

/// Mỗi lần `sleep` treo cho tới khi test gọi `calls.resolve...`; bị huỷ thì ném `CancellationError`.
public final class ControlledSleeper: Sleeper {
    public let calls = ControlledCalls<Duration, Void>(honorsCancellation: true)
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try await calls.call(duration)
    }
}

// MARK: - Bài 4

/// Uploader luôn thành công sau ~1 ms, ghi lại mọi batch và số upload chạy song song tối đa.
public final class RecordingUploader: EventUploader {
    private struct State: Sendable {
        var batches: [[AnalyticsEvent]] = []
        var active = 0
        var maxActive = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    public init() {}

    public var batches: [[AnalyticsEvent]] {
        state.withLock { (s: inout State) in s.batches }
    }

    public var uploadedEvents: [AnalyticsEvent] {
        batches.flatMap { $0 }
    }

    public var maxConcurrentUploads: Int {
        state.withLock { (s: inout State) in s.maxActive }
    }

    public func upload(_ events: [AnalyticsEvent]) async throws {
        state.withLock { (s: inout State) in
            s.active += 1
            s.maxActive = max(s.maxActive, s.active)
        }
        // Độ trễ mạng giả lập: đủ để hai upload chồng lên nhau nếu code cho phép.
        try? await Task.sleep(for: .milliseconds(1))
        state.withLock { (s: inout State) in
            s.active -= 1
            s.batches.append(events)
        }
    }
}

/// Uploader mà mọi lần upload đều treo cho tới khi test trả kết quả.
public final class ControlledUploader: EventUploader {
    public let calls = ControlledCalls<[AnalyticsEvent], Void>(honorsCancellation: true)
    public init() {}
    public func upload(_ events: [AnalyticsEvent]) async throws {
        try await calls.call(events)
    }
}

// MARK: - Bài 5

/// WebSocket giả. `emit` đẩy giá xuống mọi kết nối đang mở.
public final class FakePriceSocket: PriceSocket {
    private struct State: Sendable {
        var connections: [AsyncStream<PriceTick>.Continuation] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let holdConnects: Bool

    /// Các lần `connect` đang bị giữ lại (khi khởi tạo với `holdConnects: true`).
    public let heldConnects = ControlledCalls<Void, Void>(honorsCancellation: true)
    /// Số kết nối đã mở THÀNH CÔNG.
    public let connectCount = Metric()
    public let disconnectCount = Metric()

    public init(holdConnects: Bool = false) {
        self.holdConnects = holdConnects
    }

    public var openConnections: Int {
        state.withLock { (s: inout State) in s.connections.count }
    }

    public func connect() async throws -> AsyncStream<PriceTick> {
        try Task.checkCancellation()
        if holdConnects { try await heldConnects.call(()) }
        let (stream, continuation) = AsyncStream.makeStream(of: PriceTick.self)
        state.withLock { (s: inout State) in s.connections.append(continuation) }
        connectCount.add()
        return stream
    }

    public func disconnect() {
        let open = state.withLock { (s: inout State) -> [AsyncStream<PriceTick>.Continuation] in
            let all = s.connections
            s.connections.removeAll()
            return all
        }
        for connection in open { connection.finish() }
        disconnectCount.add()
    }

    public func emit(_ tick: PriceTick) {
        let open = state.withLock { (s: inout State) in s.connections }
        for connection in open { connection.yield(tick) }
    }
}
