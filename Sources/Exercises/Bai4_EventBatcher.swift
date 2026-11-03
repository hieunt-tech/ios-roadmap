import Foundation
import LabCore

// ============================================================================
// BÀI 4 · EventBatcher — gom sự kiện analytics rồi gửi theo lô
// ============================================================================
//
// Sự cố production (app mạng xã hội, codebase 6 năm tuổi):
//   • Crashlytics có crash EXC_BAD_ACCESS trong `Array.append` không tái hiện được
//     trên máy dev. Xảy ra nhiều nhất trên iPhone đời mới (nhiều core).
//   • Đội data báo số sự kiện "tap" thấp hơn thực tế ~3%.
//   • Một số sự kiện bị gửi 2 lần làm sai funnel chuyển đổi.
//   • Người dùng dùng app trên máy bay 8 tiếng → buffer phình vài trăm nghìn sự kiện → crash vì thiếu bộ nhớ.
//
// Ràng buộc thực tế: `log(_:)` được gọi từ khắp nơi trong code cũ (UIKit delegate,
// callback GCD, thread nền của SDK bên thứ ba). Nó PHẢI là hàm đồng bộ, không được `async`,
// và không được chặn thread gọi lâu.
//
// Gợi ý chạy: `swift test --filter Bai4 --sanitize=thread` để Thread Sanitizer chỉ ra race.
// Nếu test crash ngay với code này: đó chính là bug cần sửa.
//
// Sửa để vượt qua Tests/LabTests/Bai4Tests.swift. Yêu cầu chi tiết: BAI_KIEM_TRA.md, mục Bài 4.

public final class EventBatcher: @unchecked Sendable {
    private let uploader: any EventUploader
    private let batchSize: Int
    private let maxBufferedEvents: Int

    private var buffer: [AnalyticsEvent] = []
    private var dropped = 0

    public init(uploader: any EventUploader, batchSize: Int = 50, maxBufferedEvents: Int = 1_000) {
        self.uploader = uploader
        self.batchSize = batchSize
        self.maxBufferedEvents = maxBufferedEvents
    }

    /// Số sự kiện đang chờ gửi.
    public var bufferedCount: Int { buffer.count }

    /// Số sự kiện đã bị bỏ vì buffer đầy.
    public var droppedCount: Int { dropped }

    /// Ghi một sự kiện. Gọi được từ BẤT KỲ thread nào, đồng bộ.
    public func log(_ event: AnalyticsEvent) {
        buffer.append(event)
        if buffer.count >= batchSize {
            Task { await self.flush() }
        }
    }

    /// Gửi mọi sự kiện đang chờ. Trả về khi đã gửi xong (hoặc khi upload lỗi).
    public func flush() async {
        guard !buffer.isEmpty else { return }
        let batch = buffer
        do {
            try await uploader.upload(batch)
            buffer.removeAll()
        } catch {
            // Thử lại ở lần flush sau.
        }
    }
}
