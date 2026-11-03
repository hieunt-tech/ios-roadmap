import Foundation
import LabCore

// ============================================================================
// BÀI 1 · ImageLoader — tải ảnh dùng chung cho cả app
// ============================================================================
//
// Sự cố production (app thương mại điện tử, màn hình feed sản phẩm):
//   • Cuộn nhanh, cùng một ảnh thumbnail xuất hiện ở 3–4 cell → app tải ảnh đó 3–4 lần.
//     Hoá đơn CDN tăng 40% sau khi chuyển sang code "async/await cho hiện đại".
//   • Cell bị reuse thì task của nó bị huỷ, nhưng có lúc cell KHÁC đang chờ cùng ảnh
//     cũng mất ảnh theo, có lúc ngược lại: không ai cần ảnh nữa mà request vẫn chạy.
//   • Sau 10 phút lướt, app bị hệ điều hành kill vì cache phình to không giới hạn.
//
// Code dưới đây "chạy được", nhưng sai ở cả ba điểm trên. Sửa để vượt qua Tests/LabTests/Bai1Tests.swift.
// Đọc yêu cầu chi tiết trong BAI_KIEM_TRA.md, mục Bài 1.
//
// Ràng buộc: giữ nguyên API public (tên type, init, method). Được thêm type/hàm internal.

public actor ImageLoader {
    private let network: any ImageNetwork
    private var cache: [URL: Data] = [:]

    public init(network: any ImageNetwork, cacheCapacityBytes: Int = 50_000_000) {
        self.network = network
        // TODO: cacheCapacityBytes đang bị bỏ qua.
    }

    /// Trả ảnh từ cache nếu có, nếu không thì tải.
    public func image(for url: URL) async throws -> Data {
        if let cached = cache[url] {
            return cached
        }
        // Câu hỏi: actor đảm bảo không có data race. Vậy tại sao 10 lời gọi
        // đồng thời vẫn tạo ra 10 request?
        let data = try await network.data(from: url)
        cache[url] = data
        return data
    }

    /// Đọc cache mà không làm thay đổi thứ tự LRU. Dùng cho test và cho prefetch.
    public func cachedImage(for url: URL) -> Data? {
        cache[url]
    }
}
