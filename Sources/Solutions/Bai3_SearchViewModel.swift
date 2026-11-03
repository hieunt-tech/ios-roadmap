import Foundation
import LabCore
import Observation

// ĐÁP ÁN BÀI 3 · Giải thích chi tiết: GIAI_THICH.md, mục Bài 3.
//
// Ý tưởng chính:
//   1. Chuẩn hoá truy vấn (trim), bỏ qua nếu trùng truy vấn hiện tại.
//   2. Huỷ task cũ TRƯỚC khi tạo task mới. Debounce nằm TRONG task nên bị huỷ cùng.
//   3. Không tin vào cancellation: API có thể vẫn trả về. Trước khi ghi state,
//      kiểm tra task còn hiệu lực VÀ truy vấn của nó vẫn là truy vấn hiện tại.
//   4. Lỗi của task đã lỗi thời (kể cả `CancellationError`, `URLError.cancelled`) bị bỏ qua.

@MainActor
@Observable
public final class SearchViewModel {
    public private(set) var query = ""
    public private(set) var results: [String] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    @ObservationIgnored public private(set) var searchTask: Task<Void, Never>?

    private let api: any SearchAPI
    private let sleeper: any Sleeper
    private let debounce: Duration

    public init(api: any SearchAPI, sleeper: any Sleeper = TaskSleeper(), debounce: Duration = .milliseconds(300)) {
        self.api = api
        self.sleeper = sleeper
        self.debounce = debounce
    }

    public func queryChanged(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != query else { return }

        query = normalized
        searchTask?.cancel()

        guard !normalized.isEmpty else {
            searchTask = nil
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        // Task kế thừa @MainActor nên ghi state trực tiếp. `[weak self]` để màn hình đóng
        // trong lúc đang chờ thì ViewModel vẫn được giải phóng.
        searchTask = Task { [weak self, api, sleeper, debounce] in
            do {
                try await sleeper.sleep(for: debounce)
                let found = try await api.search(normalized)
                guard let self, self.isCurrent(normalized) else { return }
                self.results = found
                self.errorMessage = nil
                self.isLoading = false
            } catch {
                guard let self, self.isCurrent(normalized) else { return }
                self.errorMessage = "Không tải được kết quả. Vui lòng thử lại."
                self.isLoading = false
            }
        }
    }

    /// Task đang chạy còn đại diện cho truy vấn hiện tại không?
    private func isCurrent(_ searchedQuery: String) -> Bool {
        !Task.isCancelled && searchedQuery == query
    }
}
