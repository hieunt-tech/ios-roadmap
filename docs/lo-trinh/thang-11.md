# Tháng 11 — Mobile system design

**Mục tiêu:** thiết kế một ứng dụng hoặc tính năng lớn từ yêu cầu mơ hồ: xác định phạm vi, chọn kiến trúc, mô hình dữ liệu, chiến lược cache, đồng bộ, xử lý lỗi, đo lường; trình bày được trong 45 phút.
**Đầu ra cuối tháng:** trả lời trọn vẹn một đề system design trong 45 phút (ghi âm lại), có tài liệu thiết kế cho 6 đề.

Tháng này ít code hơn. "Ví dụ" của mỗi buổi chủ yếu là sơ đồ và khung trả lời; "Bài tập" là một đề thiết kế cần viết ra giấy hoặc vẽ trên bảng trắng.

[← Tháng 10](thang-10.md) · [Mục lục](../../README.md) · [Tháng 12 →](thang-12.md)

---

## Tuần 1 · Khung trả lời

### Ngày 1 — Khung 45 phút

**Kiến thức**
- Trình tự: (1) Làm rõ yêu cầu, 5–8 phút → (2) Kiến trúc tổng thể, 10 phút → (3) Đào sâu 2–3 phần khó, 20 phút → (4) Đánh đổi, mở rộng, đo lường, 5 phút.
- Người phỏng vấn đánh giá cách bạn *đặt câu hỏi* và *nêu đánh đổi*, không phải một đáp án đúng duy nhất.
- Mobile system design khác backend: tập trung vào thiết bị (bộ nhớ, pin, mạng chập chờn, vòng đời app, offline), API contract với server, và trải nghiệm người dùng.

**Ví dụ (câu hỏi làm rõ yêu cầu cho đề "Thiết kế app Instagram feed")**
```
Chức năng: chỉ xem feed, hay cả đăng bài, thích, bình luận? Có video không?
Quy mô: bao nhiêu người dùng, mỗi người theo dõi bao nhiêu tài khoản?
Thiết bị: iPhone tối thiểu? iPad? Có hỗ trợ offline không?
Ưu tiên: tốc độ mở feed, tiết kiệm dữ liệu, hay độ tươi của nội dung?
Ngoài phạm vi: thuật toán xếp hạng phía server, quảng cáo.
```

**Bài tập:** Viết danh sách 15 câu hỏi làm rõ dùng chung cho mọi đề mobile system design, chia theo nhóm (chức năng, phi chức năng, ràng buộc, ngoài phạm vi). In ra, dán cạnh bàn học cho cả tháng.

### Ngày 2 — Yêu cầu phi chức năng và ước lượng

**Kiến thức**
- Phi chức năng: hiệu năng (thời gian mở màn hình), offline, tiết kiệm dữ liệu/pin, bảo mật, accessibility, đa ngôn ngữ, khả năng quan sát (log, metric).
- Ước lượng thô để ra quyết định: một trang feed 20 bài × 3 ảnh × 200 KB = 12 MB nếu không thu nhỏ ảnh → phải có ảnh nhiều kích thước.
- Ngân sách: ví dụ "feed hiện nội dung trong 1 giây khi mở lại app" quyết định phải có cache đĩa.

**Ví dụ**
```
Người dùng xem trung bình 100 bài/ngày, 60% có ảnh, 10% có video 15 giây.
Ảnh thumbnail 60 KB, ảnh đầy đủ 300 KB, video 720p ~2 MB/15 giây.
→ Dữ liệu/ngày ≈ 100 × (0,6 × 60 KB + 0,1 × 2 MB) ≈ 23,6 MB
→ Với gói 4G hạn chế: cần chế độ tiết kiệm dữ liệu (không tự phát video, chỉ thumbnail).
```

**Bài tập:** Ước lượng dung lượng mạng, bộ nhớ và đĩa cho app nghe podcast: 10 podcast theo dõi, mỗi tuần 2 tập/podcast, tập dài 45 phút ở 128 kbps, tự tải tập mới. Đưa ra 3 quyết định thiết kế từ con số.

### Ngày 3 — Kiến trúc client theo tầng

**Kiến thức**
- Sơ đồ chuẩn: UI → ViewModel/Presenter → Use case/Repository → nguồn dữ liệu (API client, cache bộ nhớ, kho đĩa) + dịch vụ dùng chung (auth, analytics, feature flag).
- Repository quyết định lấy dữ liệu từ đâu (cache trước rồi mạng, hay mạng trước) và hợp nhất kết quả.
- Nêu rõ thread/isolation: UI trên main, repository là actor, kho đĩa có context riêng.

**Ví dụ**
```
┌──────────── UI (SwiftUI, @MainActor) ────────────┐
│ FeedView → FeedViewModel                         │
└───────────────┬──────────────────────────────────┘
                ▼
        FeedRepository (actor)
       ┌────────┼─────────────┐
       ▼        ▼             ▼
  MemoryCache  DiskStore   APIClient ──▶ AuthenticatedTransport
              (SwiftData)                (refresh token single-flight)
       ImagePipeline (gộp request, downsample, LRU)
```

**Bài tập:** Vẽ sơ đồ tầng như trên cho dự án xuyên suốt của bạn, ghi rõ mỗi khối chạy trên isolation nào và giao tiếp bằng gì (`async` call, `AsyncStream`, notification).

### Ngày 4 — Mô hình dữ liệu và chiến lược cache

**Kiến thức**
- Chọn chiến lược theo loại dữ liệu: *cache-then-network* (feed: hiện ngay dữ liệu cũ, cập nhật sau), *network-first* (số dư tài khoản), *cache-only khi offline* (ghi chú).
- Thời hạn cache (TTL), vô hiệu hoá khi người dùng tự thay đổi (vừa thích một bài thì cập nhật cache ngay).
- Chuẩn hoá dữ liệu: lưu `User` một lần, bài viết tham chiếu `userID`, để đổi avatar là mọi chỗ cập nhật.

**Ví dụ**
```swift
func feed() -> AsyncThrowingStream<[Post], Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            if let cached = await disk.cachedFeed() { continuation.yield(cached) }   // hiện ngay
            do {
                let fresh = try await api.feed()
                await disk.save(fresh)
                continuation.yield(fresh)                                       // cập nhật
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

**Bài tập:** Lập bảng 8 loại dữ liệu của một app ngân hàng (số dư, lịch sử giao dịch, danh bạ người nhận, tỉ giá, thông báo, cấu hình, ảnh đại diện, điều khoản). Mỗi loại: chiến lược cache, TTL, lưu ở đâu, có được lưu xuống đĩa không (bảo mật).

### Ngày 5 — Thực hành tuần 1: thiết kế News Feed

**Bài tập:** Viết tài liệu thiết kế 2–3 trang cho "News Feed kiểu mạng xã hội": yêu cầu đã làm rõ, sơ đồ tầng, API contract (endpoint, cursor, kích thước ảnh), mô hình dữ liệu cục bộ, cache, tải ảnh/video, phân trang, thích/bình luận lạc quan (optimistic update) và xử lý khi thất bại, đo lường. Tự bấm giờ 45 phút trình bày lại.

---

## Tuần 2 · Thời gian thực, offline và tải lên

### Ngày 6 — Thời gian thực: polling, SSE, WebSocket, push

**Kiến thức**
- **Polling**: đơn giản, tốn pin và dữ liệu. **Long polling/SSE**: server đẩy một chiều. **WebSocket**: hai chiều, giữ kết nối, phải tự xử lý reconnect. **Push**: khi app ở nền.
- Kết hợp thường gặp: WebSocket khi màn hình đang mở, push khi app ở nền, đồng bộ lại khi quay vào app.
- Reconnect: exponential backoff + jitter, gửi `lastEventID` để server gửi bù những gì đã lỡ.

**Ví dụ**
```
Trạng thái kết nối:
disconnected ──connect──▶ connecting ──ok──▶ connected
     ▲                       │ lỗi             │ mất kết nối
     └──── chờ backoff ◀── reconnecting(attempt n) ◀──┘
Vào nền: đóng socket. Quay lại: connect + đồng bộ từ lastEventID.
```

**Bài tập:** So sánh 4 cách cho tính năng "trạng thái đơn giao hàng cập nhật trực tiếp" theo bảng: độ trễ, pin, dữ liệu, độ phức tạp server, hoạt động khi app ở nền. Chọn và biện luận. Mở rộng `PriceFeed` của ConcurrencyLab Bài 5 với trạng thái `reconnecting` trên giấy.

### Ngày 7 — Thiết kế app chat

**Kiến thức**
- Tin nhắn có id do client tạo (UUID) để gửi lại không bị trùng; trạng thái: đang gửi → đã gửi → đã nhận → đã xem, hoặc thất bại (cho gửi lại).
- Thứ tự: dùng số thứ tự do server cấp trong mỗi cuộc trò chuyện; client sắp tạm theo thời gian gửi cục bộ.
- Lưu cục bộ toàn bộ lịch sử đã tải; tải lịch sử cũ theo trang ngược khi cuộn lên.

**Ví dụ (mô hình tin nhắn cục bộ)**
```swift
struct LocalMessage: Identifiable, Sendable {
    enum Status: Sendable { case sending, sent(serverSeq: Int), delivered, read, failed(retryable: Bool) }
    let id: UUID                 // client tạo, dùng làm idempotency key
    let conversationID: UUID
    var body: String
    var status: Status
    let createdAtLocal: Date
}
```

**Bài tập:** Thiết kế app chat 1–1 và nhóm: gửi tin khi offline (outbox), nhận tin qua WebSocket, đồng bộ khi mở app, hiển thị "đang gõ", đã xem, gửi ảnh. Vẽ sơ đồ trình tự (sequence diagram) cho luồng "gửi tin khi mất mạng rồi có mạng lại".

### Ngày 8 — Offline-first và giải quyết xung đột

**Kiến thức**
- Mọi thao tác ghi vào kho cục bộ và outbox trước; UI phản hồi ngay; đồng bộ chạy nền.
- Xung đột: *last-write-wins* theo thời gian server, *version vector*, gộp theo trường, hoặc hỏi người dùng. Chọn theo mức độ quan trọng của dữ liệu.
- Phải hiển thị trạng thái đồng bộ: "Đã lưu trên máy", "Đang đồng bộ", "Lỗi đồng bộ, chạm để thử lại".

**Ví dụ**
```
Ghi chú sửa trên iPhone (version 4 → 5, offline)
Cùng ghi chú sửa trên iPad (version 4 → 5, online, server nhận trước)
iPhone có mạng, gửi "update từ version 4"
→ Server: version hiện tại là 5 ≠ 4 → trả 409 Conflict kèm bản server
→ Client: gộp theo trường (tiêu đề lấy bản mới hơn, nội dung giữ cả hai đoạn)
   hoặc tạo bản sao "Ghi chú (bản trên iPhone)"
```

**Bài tập:** Thiết kế đồng bộ cho app danh sách việc cần làm dùng chung trong gia đình (nhiều người cùng sửa). Định nghĩa API (`GET /changes?since=`, `POST /changes`), chiến lược xung đột cho từng trường (tên, hoàn thành, thứ tự), và 5 tình huống kiểm thử.

### Ngày 9 — Tải lên file lớn

**Kiến thức**
- Background `URLSession` upload: tiếp tục khi app bị đưa về nền hoặc bị hệ thống tắt; cần ghi dữ liệu ra file trước khi upload.
- Tải lên theo đoạn (chunked/resumable) để mất mạng giữa chừng không phải tải lại từ đầu.
- Nén/thu nhỏ trên máy trước khi tải (video 4K → 1080p), hiện tiến độ, cho phép huỷ.

**Ví dụ**
```swift
let config = URLSessionConfiguration.background(withIdentifier: "com.example.upload")
config.sessionSendsLaunchEvents = true
let session = URLSession(configuration: config, delegate: uploadDelegate, delegateQueue: nil)

var request = URLRequest(url: uploadURL)
request.httpMethod = "PUT"
let task = session.uploadTask(with: request, fromFile: compressedVideoURL)
task.resume()
// App bị tắt: hệ thống tiếp tục upload, gọi lại
// application(_:handleEventsForBackgroundURLSession:completionHandler:)
```

**Bài tập:** Thiết kế tính năng đăng video 60 giây: chọn video, cắt, nén, tải lên có thể tiếp tục, hiện bài viết ngay ở trạng thái "đang đăng", xử lý thất bại. Ước lượng thời gian tải trên 4G 5 Mbps.

### Ngày 10 — Thực hành tuần 2: thiết kế app chat

**Bài tập:** Hoàn thiện tài liệu thiết kế app chat (Ngày 7) thành 3 trang có: yêu cầu, sơ đồ tầng, mô hình dữ liệu, API và sự kiện WebSocket, outbox, đồng bộ, push, bảo mật (mã hoá đầu-cuối nêu ở mức ý tưởng), đo lường. Trình bày 45 phút với một người đóng vai người phỏng vấn, ghi lại câu hỏi khó.

---

## Tuần 3 · Các mảnh ghép nâng cao

### Ngày 11 — Phân trang và tính nhất quán

**Kiến thức**
- Cursor ổn định hơn offset khi dữ liệu thay đổi liên tục; cursor có thể là id cuối cùng hoặc chuỗi mã hoá do server cấp.
- Nội dung mới xuất hiện ở đầu khi người dùng đang đọc: không chèn làm nhảy vị trí; hiện nút "Có 5 bài mới".
- Xoá/sửa phía server: hợp nhất theo id, đánh dấu bài đã xoá thay vì để lỗ hổng trong danh sách.

**Ví dụ**
```
GET /feed?limit=20                 → items[1..20], next_cursor="c20"
GET /feed?limit=20&after=c20        → items[21..40], next_cursor="c40"
GET /feed/new?before=<id đầu tiên>  → số bài mới, không chèn tự động
```

**Bài tập:** Thiết kế phân trang hai chiều cho lịch sử giao dịch ngân hàng (cuộn xuống xem cũ, mở app thấy mới), có nhóm theo ngày và tổng tiền mỗi ngày đúng khi chỉ tải một phần dữ liệu.

### Ngày 12 — Hệ thống thông báo

**Kiến thức**
- Loại push: hiển thị (alert), im lặng (`content-available`, đánh thức app ngắn để đồng bộ, không đảm bảo được giao), Live Activity push.
- Device token thay đổi: gửi lại mỗi lần khởi động; server xoá token khi APNs báo không hợp lệ.
- Tôn trọng người dùng: cài đặt theo loại thông báo trong app, giờ yên lặng, gom nhiều thông báo (thread id, summary).

**Ví dụ (payload)**
```json
{
  "aps": {
    "alert": { "title": "Đơn hàng #A123", "body": "Tài xế đang tới, còn 5 phút" },
    "thread-id": "order-A123",
    "interruption-level": "time-sensitive",
    "mutable-content": 1
  },
  "deep_link": "shop://order/A123"
}
```

**Bài tập:** Thiết kế hệ thống thông báo cho app giao đồ ăn: các loại thông báo, kênh (push / Live Activity / in-app), tuỳ chọn người dùng, luồng đăng ký token, đo tỉ lệ mở. Nêu rõ thông báo nào được dùng `time-sensitive` và vì sao.

### Ngày 13 — Bảo mật và quyền riêng tư trong thiết kế

**Kiến thức**
- Mô hình đe doạ: thiết bị bị mất, mạng bị nghe lén, app bị dịch ngược, người dùng khác trên cùng máy.
- Biện pháp: Keychain + Data Protection, sinh trắc học (`LAContext`) cho thao tác nhạy cảm, che nội dung khi chụp màn hình/vào nền, pinning cho app tài chính, không lưu dữ liệu nhạy cảm không cần thiết.
- Quyền riêng tư: thu thập tối thiểu, xử lý trên máy khi có thể (Foundation Models), nêu rõ trong privacy manifest.

**Ví dụ**
```swift
import LocalAuthentication

func confirmTransfer() async throws -> Bool {
    let context = LAContext()
    context.localizedFallbackTitle = "Nhập mã PIN"
    return try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                            localizedReason: "Xác nhận chuyển 5.000.000đ")
}
```

**Bài tập:** Lập mô hình đe doạ cho tính năng chuyển tiền trong app ngân hàng: 8 mối đe doạ, khả năng xảy ra, tác động, biện pháp trên client, biện pháp cần server. Trình bày dưới dạng bảng.

### Ngày 14 — Khả năng quan sát (observability)

**Kiến thức**
- Ba trụ cột: log (chuyện gì đã xảy ra), metric (bao nhiêu, nhanh chậm thế nào), trace (một luồng đi qua những bước nào).
- Chỉ số mobile quan trọng: tỉ lệ người dùng không gặp crash, hang rate, thời gian khởi động, thời gian tải màn hình chính, tỉ lệ request lỗi theo endpoint, tỉ lệ hoàn thành funnel.
- Gắn `requestID` vào mỗi request để đối chiếu log client với log server.

**Ví dụ**
```swift
var request = URLRequest(url: url)
let requestID = UUID().uuidString
request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
Logger.network.info("→ \(requestID, privacy: .public) \(url.path, privacy: .public)")
```

**Bài tập:** Thiết kế dashboard sức khoẻ cho app của bạn: 10 chỉ số, nguồn dữ liệu (MetricKit, analytics, crash, server), ngưỡng cảnh báo, ai nhận cảnh báo. Thêm `X-Request-ID` vào `APIClient` của dự án.

### Ngày 15 — Thực hành tuần 3: thiết kế theo dõi giao hàng

**Bài tập:** Thiết kế tính năng "theo dõi đơn giao hàng trên bản đồ" (kiểu Grab/ShopeeFood): vị trí tài xế cập nhật trực tiếp, ETA, Live Activity, push khi đổi trạng thái, hoạt động khi app ở nền, tiết kiệm pin, mất mạng giữa chừng. Tài liệu 3 trang + trình bày 45 phút.

---

## Tuần 4 · Phỏng vấn thử

### Ngày 16 — Phỏng vấn thử lần 1

**Kiến thức**
- Nói to suy nghĩ; viết yêu cầu và giả định lên bảng trước khi vẽ.
- Khi bị hỏi "nếu X thì sao?": nhận đánh đổi, đưa phương án, không phòng thủ.
- Quản lý thời gian: đặt đồng hồ, chủ động chuyển phần.

**Ví dụ (mẫu đánh giá sau buổi thử)**
```
Làm rõ yêu cầu:        1 2 3 4 5
Kiến trúc tổng thể:     1 2 3 4 5
Đào sâu phần khó:       1 2 3 4 5
Nêu đánh đổi:           1 2 3 4 5
Giao tiếp, quản lý giờ: 1 2 3 4 5
Ba điều cần cải thiện: ...
```

**Bài tập:** Nhờ một đồng nghiệp hoặc bạn bè đóng vai người phỏng vấn với đề "Thiết kế app đặt xe" (không chuẩn bị trước). Ghi âm, chấm theo mẫu, nghe lại và viết 3 điều cần cải thiện.

### Ngày 17 — Câu hỏi hành vi (behavioral)

**Kiến thức**
- Phương pháp STAR: Situation (bối cảnh) → Task (nhiệm vụ của bạn) → Action (bạn đã làm gì) → Result (kết quả, có số liệu).
- Chủ đề hay gặp: sự cố production, bất đồng kỹ thuật, deadline gấp, sai lầm của bản thân, giúp đồng đội tiến bộ.
- Kể chuyện thật, nói "tôi" khi mô tả việc mình làm, có bài học rút ra.

**Ví dụ (khung một câu chuyện)**
```
S: App bị đăng xuất hàng loạt sau bản 2.3, 4% người dùng mỗi ngày.
T: Tôi được giao tìm nguyên nhân trong 24 giờ.
A: Đọc log, tái hiện bằng test giữ refresh lại; phát hiện refresh đồng thời
   với refresh-token rotation. Viết single-flight + test race.
R: Tỉ lệ đăng xuất bất thường về 0,02%; thêm test vào CI để không tái diễn.
```

**Bài tập:** Viết 6 câu chuyện STAR từ kinh nghiệm thật của bạn cho 6 chủ đề trên, mỗi câu chuyện nói được trong 2 phút. Tập nói trước gương hoặc ghi âm.

### Ngày 18 — Viết tài liệu đánh đổi

**Kiến thức**
- Mỗi quyết định thiết kế có ít nhất một phương án thay thế; ghi rõ vì sao chọn, chi phí, khi nào nên xem lại.
- Bảng so sánh với tiêu chí có trọng số giúp thảo luận khách quan hơn.
- Trong phỏng vấn, nói "Tôi chọn A vì B; đánh đổi là C; nếu yêu cầu đổi thành D thì tôi chuyển sang E."

**Ví dụ**
```
Quyết định: lưu feed bằng SwiftData hay file JSON?
                        SwiftData    File JSON
Truy vấn/lọc            tốt          kém
Độ phức tạp             trung bình   thấp
Migration               có công cụ   tự viết
Hiệu năng ghi lớn       cần actor    tốt
Chọn: File JSON cho cache feed (chỉ đọc toàn bộ, thay toàn bộ);
      SwiftData cho dữ liệu người dùng tạo (lọc, sửa, đồng bộ).
```

**Bài tập:** Viết bảng đánh đổi cho 5 quyết định trong các thiết kế của tháng này (ví dụ WebSocket hay SSE, offset hay cursor, cache đĩa hay chỉ bộ nhớ, last-write-wins hay gộp trường, MVVM hay reducer).

### Ngày 19 — Ôn lại và hoàn thiện tài liệu

**Kiến thức**
- Ôn lại các mảnh ghép dùng lại được: pipeline ảnh, lớp mạng có refresh, outbox, máy trạng thái kết nối, phân trang cursor, cache-then-network.
- Mỗi mảnh nên nói được trong 2–3 phút với sơ đồ.

**Ví dụ (thẻ ôn tập)**
```
Mảnh: Outbox
Vấn đề: ghi khi offline, không mất, không trùng
Cách: kho cục bộ + bảng PendingChange (id client) + worker nền gửi tuần tự
Đánh đổi: phức tạp hơn; cần hiển thị trạng thái đồng bộ
Liên quan: ConcurrencyLab Bài 4 (re-queue đầu hàng đợi, giữ thứ tự)
```

**Bài tập:** Làm 10 thẻ ôn tập như trên cho các mảnh ghép. Gom 6 tài liệu thiết kế của tháng thành một thư mục, sửa theo phản hồi đã nhận.

### Ngày 20 — Phỏng vấn thử 45 phút và kiểm tra

**Bài tập:** Phỏng vấn thử lần 2 với một đề chưa làm (gợi ý: "Thiết kế app nghe nhạc có tải về nghe offline" hoặc "Thiết kế Google Photos trên iOS"). Ghi âm, chấm theo mẫu Ngày 16, so với lần 1. Mục tiêu: hoàn thành cả 4 phần trong 45 phút, mỗi tiêu chí ≥ 4/5.

**Kiểm tra:** làm lại Phần C của bài kiểm tra năng lực với đề mới.
