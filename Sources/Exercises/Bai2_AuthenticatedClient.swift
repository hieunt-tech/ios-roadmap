import Foundation
import LabCore

// ============================================================================
// BÀI 2 · AuthenticatedClient — tự refresh token khi gặp 401
// ============================================================================
//
// Sự cố production (app ngân hàng số):
//   • Mở app sau 1 giờ không dùng, màn hình Home gọi 5 API song song. Access token đã hết hạn
//     nên cả 5 cùng nhận 401 → 5 lần refresh. Server dùng refresh-token rotation: lần đầu
//     thành công, 4 lần sau bị `invalidGrant` → người dùng bị đá ra màn hình đăng nhập
//     dù phiên vẫn còn hiệu lực. Tỉ lệ "đăng xuất bất thường" tăng vọt trên dashboard.
//   • Một tài khoản bị khoá quyền: server trả 401 kể cả với token mới → app retry vô hạn,
//     nóng máy, hết pin, spam server.
//   • Đi thang máy mất mạng đúng lúc refresh → app đăng xuất người dùng. Lỗi mạng
//     không có nghĩa là phiên hết hạn.
//
// Sửa để vượt qua Tests/LabTests/Bai2Tests.swift. Yêu cầu chi tiết: BAI_KIEM_TRA.md, mục Bài 2.

public actor AuthenticatedClient {
    private let api: any AuthAPI
    private var currentTokens: TokenPair?

    public init(api: any AuthAPI, tokens: TokenPair) {
        self.api = api
        self.currentTokens = tokens
    }

    /// Token hiện tại. `nil` nghĩa là phiên đã hết hạn.
    public var tokens: TokenPair? { currentTokens }

    public func send(_ request: APIRequest) async throws -> APIResponse {
        guard let tokens = currentTokens else { throw AuthError.sessionExpired }
        let response = try await api.send(request, accessToken: tokens.accessToken)
        if response.statusCode == 401 {
            let renewed = try await api.refresh(refreshToken: currentTokens!.refreshToken)
            currentTokens = renewed
            return try await send(request)
        }
        return response
    }
}
