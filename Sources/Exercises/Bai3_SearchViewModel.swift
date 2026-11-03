import Foundation
import LabCore
import Observation

// ============================================================================
// BÀI 3 · SearchViewModel — tìm kiếm khi người dùng đang gõ
// ============================================================================
//
// Sự cố production (app đặt đồ ăn, ô tìm món):
//   • Gõ "pho" → thấy kết quả của "ph". Do response của "ph" (chậm) về SAU response của "pho".
//     Khách đặt nhầm "phở cuốn" thay vì "phở bò", tổng đài nhận khiếu nại.
//   • Mỗi phím gõ là một request. Gõ "bún bò huế" = 10 request, backend tìm kiếm bị quá tải giờ trưa.
//   • Xoá trắng ô tìm kiếm, vài trăm ms sau danh sách cũ lại hiện về.
//   • Gõ nhanh thì thỉnh thoảng hiện banner lỗi "The operation couldn't be completed (cancelled)".
//
// API tìm kiếm trong test (FakeSearchAPI) PHỚT LỜ cancellation, giống backend thật:
// huỷ Task không có nghĩa là response sẽ không về.
//
// Sửa để vượt qua Tests/LabTests/Bai3Tests.swift. Yêu cầu chi tiết: BAI_KIEM_TRA.md, mục Bài 3.

@MainActor
@Observable
public final class SearchViewModel {
    public private(set) var query = ""
    public private(set) var results: [String] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    /// Task tìm kiếm gần nhất. Test dùng để chờ kết quả; app thật không cần đọc.
    @ObservationIgnored public private(set) var searchTask: Task<Void, Never>?

    private let api: any SearchAPI
    private let sleeper: any Sleeper
    private let debounce: Duration

    public init(api: any SearchAPI, sleeper: any Sleeper = TaskSleeper(), debounce: Duration = .milliseconds(300)) {
        self.api = api
        self.sleeper = sleeper
        self.debounce = debounce
    }

    /// Gọi mỗi khi nội dung ô tìm kiếm thay đổi.
    public func queryChanged(_ text: String) {
        query = text
        guard !text.isEmpty else {
            results = []
            return
        }
        isLoading = true
        searchTask = Task {
            do {
                try await self.sleeper.sleep(for: self.debounce)
                let found = try await self.api.search(text)
                self.results = found
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
