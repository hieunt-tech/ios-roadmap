import Foundation
import LabCore

// ĐÁP ÁN BÀI 2 · Giải thích chi tiết: GIAI_THICH.md, mục Bài 2.
//
// Ý tưởng chính:
//   1. Single-flight refresh: chỉ một `refreshTask` tồn tại tại một thời điểm,
//      mọi request gặp 401 cùng `await` task đó.
//   2. So token: request bị 401 với token CŨ trong khi client đã có token MỚI
//      → chỉ cần retry, không refresh lại (tránh dùng refresh token đã bị rotate).
//   3. Retry đúng một lần. Vẫn 401 → `.unauthorized`, không lặp vô hạn.
//   4. Phân biệt lỗi: `invalidGrant` → phiên hết hạn, xoá token. Lỗi mạng → giữ phiên.

public actor AuthenticatedClient {
    private let api: any AuthAPI
    private var currentTokens: TokenPair?
    private var refreshTask: Task<TokenPair, any Error>?

    public init(api: any AuthAPI, tokens: TokenPair) {
        self.api = api
        self.currentTokens = tokens
    }

    public var tokens: TokenPair? { currentTokens }

    public func send(_ request: APIRequest) async throws -> APIResponse {
        guard let used = currentTokens else { throw AuthError.sessionExpired }

        let first = try await api.send(request, accessToken: used.accessToken)
        guard first.statusCode == 401 else { return first }

        let fresh = try await refreshedTokens(replacing: used)
        let retried = try await api.send(request, accessToken: fresh.accessToken)
        guard retried.statusCode != 401 else { throw AuthError.unauthorized }
        return retried
    }

    /// Trả về token còn dùng được thay cho `rejected`, refresh nếu cần (tối đa một refresh song song).
    private func refreshedTokens(replacing rejected: TokenPair) async throws -> TokenPair {
        guard let current = currentTokens else { throw AuthError.sessionExpired }

        // Trong lúc request này đang bay, một request khác đã refresh xong.
        if current.accessToken != rejected.accessToken { return current }

        // Một refresh đang chạy: chờ chung.
        if let refreshTask { return try await refreshTask.value }

        // Task không cấu trúc: caller đầu tiên bị huỷ thì refresh vẫn chạy tiếp cho người khác.
        // Closure bắt `self` nên được cô lập trên actor: ghi `currentTokens` không cần await.
        let task = Task { () throws -> TokenPair in
            defer { self.refreshTask = nil }
            do {
                let renewed = try await self.api.refresh(refreshToken: current.refreshToken)
                self.currentTokens = renewed
                return renewed
            } catch RefreshError.invalidGrant {
                self.currentTokens = nil
                throw AuthError.sessionExpired
            }
            // Lỗi khác (mạng, timeout, 5xx) đi thẳng ra ngoài; token được giữ nguyên.
        }
        refreshTask = task
        return try await task.value
    }
}
