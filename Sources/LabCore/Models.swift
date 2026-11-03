import Foundation

// Toàn bộ kiểu trong file này là "hợp đồng" giữa bài làm, đáp án và bộ test.
// KHÔNG sửa file này.

// MARK: - Bài 1 · ImageLoader

/// Lớp mạng tải dữ liệu ảnh. App thật bọc `URLSession`; test dùng fake có điều khiển.
public protocol ImageNetwork: Sendable {
    func data(from url: URL) async throws -> Data
}

// MARK: - Bài 2 · AuthenticatedClient

public struct TokenPair: Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public struct APIRequest: Sendable, Equatable {
    public var path: String
    public init(path: String) { self.path = path }
}

public struct APIResponse: Sendable, Equatable {
    public var statusCode: Int
    public var body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// Lỗi mà `AuthenticatedClient` ném ra cho tầng UI.
public enum AuthError: Error, Equatable {
    /// Phiên đăng nhập đã hết hạn hẳn (refresh token bị thu hồi). UI phải đưa về màn hình đăng nhập.
    case sessionExpired
    /// Đã refresh token nhưng server vẫn từ chối. Không được retry thêm.
    case unauthorized
}

/// Lỗi server trả về cho endpoint refresh.
public enum RefreshError: Error, Equatable {
    /// Refresh token không còn hợp lệ (đã dùng, đã bị thu hồi, hoặc hết hạn).
    case invalidGrant
}

public protocol AuthAPI: Sendable {
    /// Gửi request kèm access token. Server trả `statusCode == 401` nếu token không hợp lệ.
    func send(_ request: APIRequest, accessToken: String) async throws -> APIResponse
    /// Đổi refresh token lấy cặp token mới. Server dùng cơ chế *rotation*:
    /// refresh token cũ mất hiệu lực ngay khi đổi thành công.
    func refresh(refreshToken: String) async throws -> TokenPair
}

// MARK: - Bài 3 · SearchViewModel

public protocol SearchAPI: Sendable {
    func search(_ query: String) async throws -> [String]
}

/// Trừu tượng hoá việc chờ để test điều khiển được debounce.
public protocol Sleeper: Sendable {
    func sleep(for duration: Duration) async throws
}

public struct TaskSleeper: Sleeper {
    public init() {}
    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

// MARK: - Bài 4 · EventBatcher

public struct AnalyticsEvent: Sendable, Hashable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public protocol EventUploader: Sendable {
    func upload(_ events: [AnalyticsEvent]) async throws
}

// MARK: - Bài 5 · PriceFeed

public struct PriceTick: Sendable, Equatable {
    public let symbol: String
    public let price: Decimal

    public init(symbol: String, price: Decimal) {
        self.symbol = symbol
        self.price = price
    }
}

/// Một kết nối WebSocket nhận giá realtime. Mở kết nối tốn pin và tiền server,
/// nên cả app chỉ nên giữ tối đa MỘT kết nối, dùng chung cho mọi màn hình.
public protocol PriceSocket: Sendable {
    /// Mở kết nối và trả về luồng giá của MỌI mã cổ phiếu.
    func connect() async throws -> AsyncStream<PriceTick>
    /// Đóng kết nối hiện tại.
    func disconnect()
}
