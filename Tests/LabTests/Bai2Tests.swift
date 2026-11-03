import Foundation
import LabCore
import LabTestSupport
import Testing
#if SOLUTION
import Solutions
#else
import Exercises
#endif

private let initialTokens = TokenPair(accessToken: "access-0", refreshToken: "refresh-0")
private let profile = APIRequest(path: "/me")

@Suite("Bài 2 · AuthenticatedClient")
struct Bai2AuthenticatedClientTests {

    @Test("5 request cùng gặp 401: chỉ refresh 1 lần, cả 5 đều thành công")
    func concurrent401sTriggerSingleRefresh() async throws {
        let server = FakeAuthServer(tokens: initialTokens)
        server.expireAccessToken()
        server.holdAllRefreshes()
        let client = AuthenticatedClient(api: server, tokens: initialTokens)

        let responses = try await withTimeout {
            try await withThrowingTaskGroup(of: APIResponse.self) { group in
                for index in 0..<5 {
                    group.addTask { try await client.send(APIRequest(path: "/home/section/\(index)")) }
                }
                try await server.heldRefreshes.pendingCount.wait(atLeast: 1)
                try await settle()   // để mọi request kịp nhận 401
                server.heldRefreshes.resolveAll(with: .success(()))

                var all: [APIResponse] = []
                for try await response in group { all.append(response) }
                return all
            }
        }

        #expect(responses.count == 5)
        #expect(responses.allSatisfy { $0.statusCode == 200 })
        #expect(
            server.refreshCount.value == 1,
            "Đã refresh \(server.refreshCount.value) lần. Với refresh-token rotation, mọi lần sau lần đầu đều bị invalidGrant."
        )
        #expect(await client.tokens == server.validTokens)
    }

    @Test("Refresh token bị thu hồi: mọi request nhận .sessionExpired, token bị xoá, không gọi mạng thêm")
    func revokedRefreshTokenExpiresSession() async throws {
        let server = FakeAuthServer(tokens: initialTokens)
        server.expireAccessToken()
        server.revokeRefreshToken()
        let client = AuthenticatedClient(api: server, tokens: initialTokens)

        let outcomes = try await withTimeout {
            await withTaskGroup(of: Result<APIResponse, any Error>.self) { group in
                for index in 0..<3 {
                    group.addTask {
                        do {
                            return .success(try await client.send(APIRequest(path: "/feed/\(index)")))
                        } catch {
                            return .failure(error)
                        }
                    }
                }
                var all: [Result<APIResponse, any Error>] = []
                for await outcome in group { all.append(outcome) }
                return all
            }
        }

        for outcome in outcomes {
            guard case .failure(let error) = outcome else {
                Issue.record("Request lẽ ra phải thất bại vì phiên đã hết hạn")
                continue
            }
            #expect(error as? AuthError == .sessionExpired, "Nhận \(error) thay vì AuthError.sessionExpired")
        }
        #expect(server.refreshCount.value == 1)
        #expect(await client.tokens == nil, "Phiên hết hạn thì phải xoá token để UI đưa về màn hình đăng nhập.")

        let sendsBefore = server.sendCount.value
        await #expect(throws: AuthError.sessionExpired) {
            try await withTimeout { try await client.send(profile) }
        }
        #expect(server.sendCount.value == sendsBefore, "Không có token thì không được gọi mạng.")
    }

    @Test("Request nhận 401 muộn sau khi token đã được refresh: chỉ retry, không refresh lần 2")
    func late401ReusesAlreadyRefreshedToken() async throws {
        let server = FakeAuthServer(tokens: initialTokens)
        server.expireAccessToken()
        server.holdNextSends(1)   // request "chậm" bị giữ ở server
        let client = AuthenticatedClient(api: server, tokens: initialTokens)

        let slow = Task { try await client.send(APIRequest(path: "/slow-report")) }
        try await withTimeout { try await server.heldSends.pendingCount.wait(atLeast: 1) }

        // Trong lúc đó một request nhanh gặp 401, refresh và thành công.
        let fast = try await withTimeout { try await client.send(APIRequest(path: "/fast")) }
        #expect(fast.statusCode == 200)
        #expect(server.refreshCount.value == 1)

        // Giờ request chậm mới nhận 401 (vì nó gửi bằng access-0).
        server.heldSends.resolveAll(with: .success(()))
        let slowResponse = try await finish(slow)

        #expect(slowResponse.statusCode == 200)
        #expect(
            server.refreshCount.value == 1,
            "Token đã được làm mới bởi request khác; refresh lần nữa sẽ đốt refresh token mới."
        )
    }

    @Test("Server luôn trả 401 kể cả với token mới: dừng sau 1 lần retry, ném .unauthorized")
    func persistent401StopsAfterOneRetry() async throws {
        let server = FakeAuthServer(tokens: initialTokens)
        server.expireAccessToken()
        server.rejectAllRequests()
        let client = AuthenticatedClient(api: server, tokens: initialTokens)

        await #expect(throws: AuthError.unauthorized) {
            try await withTimeout { try await client.send(profile) }
        }
        #expect(server.refreshCount.value == 1)
        #expect(server.sendCount.value == 2, "Một lần gửi đầu + đúng một lần retry.")
    }

    @Test("Refresh lỗi mạng: không đăng xuất người dùng; lần sau refresh lại được")
    func networkErrorDuringRefreshKeepsSession() async throws {
        let server = FakeAuthServer(tokens: initialTokens)
        server.expireAccessToken()
        server.failNextRefresh(with: URLError(.notConnectedToInternet))
        let client = AuthenticatedClient(api: server, tokens: initialTokens)

        await #expect(throws: URLError.self) {
            try await withTimeout { try await client.send(profile) }
        }
        #expect(await client.tokens == initialTokens, "Mất mạng không có nghĩa là phiên hết hạn.")

        let response = try await withTimeout { try await client.send(profile) }
        #expect(response.statusCode == 200)
        #expect(server.refreshCount.value == 2)
    }
}
