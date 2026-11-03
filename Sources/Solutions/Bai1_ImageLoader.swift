import Foundation
import LabCore

// ĐÁP ÁN BÀI 1 · Giải thích chi tiết: GIAI_THICH.md, mục Bài 1.
//
// Ý tưởng chính:
//   1. Gộp request trùng (request coalescing): mỗi URL có tối đa MỘT download đang chạy.
//      Mọi caller cùng URL đăng ký làm "waiter" của download đó.
//   2. Mỗi waiter có continuation RIÊNG, nên caller bị huỷ được trả `CancellationError`
//      ngay lập tức mà không ảnh hưởng waiter khác.
//   3. Download chỉ bị huỷ khi waiter CUỐI CÙNG rời đi (đếm tham chiếu).
//   4. Mỗi download có `token`. Kết quả của download đã bị huỷ không được ghi đè
//      lên download mới hơn của cùng URL.
//   5. Cache LRU giới hạn theo byte, lỗi không bị cache.

public actor ImageLoader {
    private struct Download {
        let token: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<Data, any Error>]
    }

    private let network: any ImageNetwork
    private var cache: LRUCache<URL, Data>
    private var downloads: [URL: Download] = [:]

    public init(network: any ImageNetwork, cacheCapacityBytes: Int = 50_000_000) {
        self.network = network
        self.cache = LRUCache(capacity: cacheCapacityBytes)
    }

    public func image(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        if let hit = cache.value(for: url) { return hit }

        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
                // Closure này chạy ĐỒNG BỘ trên actor (Swift 6 kế thừa isolation qua #isolation),
                // nên đọc/ghi state ở đây an toàn và không bị chen ngang.
                join(url: url, waiterID: waiterID, continuation: continuation)
            }
        } onCancel: {
            // onCancel chạy đồng bộ trên thread của người gọi `cancel()`, KHÔNG phải trên actor.
            // Phải nhảy về actor bằng một Task. Nếu nó tới trước khi `join` kịp đăng ký,
            // `join` đã tự kiểm tra `Task.isCancelled` nên không có waiter bị bỏ quên.
            Task { await self.leave(url: url, waiterID: waiterID) }
        }
    }

    public func cachedImage(for url: URL) -> Data? {
        cache.peek(url)
    }

    // MARK: - Private

    private func join(url: URL, waiterID: UUID, continuation: CheckedContinuation<Data, any Error>) {
        if Task.isCancelled {
            continuation.resume(throwing: CancellationError())
            return
        }
        // Kiểm tra lại cache: phòng trường hợp có điểm treo giữa lần kiểm tra đầu và lúc này.
        if let hit = cache.value(for: url) {
            continuation.resume(returning: hit)
            return
        }
        if var download = downloads[url] {
            download.waiters[waiterID] = continuation
            downloads[url] = download
            return
        }

        let token = UUID()
        // Task không cấu trúc: KHÔNG kế thừa cancellation của caller đầu tiên.
        // Nếu dùng `async let` hay gọi thẳng, caller đầu bị huỷ sẽ kéo theo mọi caller khác.
        let task = Task { [network] in
            let result: Result<Data, any Error>
            do {
                result = .success(try await network.data(from: url))
            } catch {
                result = .failure(error)
            }
            self.complete(url: url, token: token, result: result)
        }
        downloads[url] = Download(token: token, task: task, waiters: [waiterID: continuation])
    }

    private func leave(url: URL, waiterID: UUID) {
        guard var download = downloads[url],
              let continuation = download.waiters.removeValue(forKey: waiterID)
        else { return } // Đã nhận kết quả từ trước, hoặc đã rời đi.

        continuation.resume(throwing: CancellationError())
        if download.waiters.isEmpty {
            download.task.cancel()
            downloads[url] = nil
        } else {
            downloads[url] = download
        }
    }

    private func complete(url: URL, token: UUID, result: Result<Data, any Error>) {
        // Download này đã bị bỏ (mọi waiter rời đi) và có thể đã có download mới cho cùng URL.
        guard let download = downloads[url], download.token == token else { return }
        downloads[url] = nil
        if case .success(let data) = result {
            cache.insert(data, for: url, cost: data.count)
        }
        for continuation in download.waiters.values {
            continuation.resume(with: result)
        }
    }
}
