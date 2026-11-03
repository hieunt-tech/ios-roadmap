# Tháng 4 — Swift Concurrency

**Mục tiêu:** viết code bất đồng bộ đúng trong Swift 6 strict concurrency: hiểu task, actor, isolation, cancellation, `Sendable`, và các race logic mà compiler không bắt được.
**Đầu ra cuối tháng:** hoàn thành cả 5 bài của **ConcurrencyLab** (đề ở [BAI_KIEM_TRA.md](../../BAI_KIEM_TRA.md)), chạy `swift test` xanh và sạch Thread Sanitizer.

Đây là tháng nặng nhất. Các buổi gắn với bài ConcurrencyLab có thể cần 3 giờ thay vì 2.

[← Tháng 3](thang-03.md) · [Mục lục](../../README.md) · [Tháng 5 →](thang-05.md)

---

## Tuần 1 · async/await và Task

### Ngày 1 — async/await và điểm treo

**Kiến thức**
- `async` đánh dấu hàm có thể *treo* (suspend). `await` đánh dấu điểm treo: tại đó thread được trả lại để làm việc khác, hàm tiếp tục sau, **có thể trên thread khác**.
- Không có gì chạy song song chỉ vì có `async`. Song song chỉ xảy ra khi tạo nhiều task.
- Giữa hai `await`, code chạy liền mạch; tại `await`, mọi giả định về state bên ngoài có thể đã sai.

**Ví dụ**
```swift
func loadProfile(id: User.ID) async throws -> Profile {
    let user = try await api.user(id)            // điểm treo 1
    let stats = try await api.stats(for: user)   // điểm treo 2, chạy SAU điểm 1
    return Profile(user: user, stats: stats)
}
```

**Bài tập:** Chuyển 3 hàm dùng completion handler trong dự án của bạn sang `async`. Vẽ sơ đồ thời gian (timeline) cho `loadProfile` ở trên, đánh dấu chỗ thread được trả lại. Giải thích vì sao gọi `loadProfile` trong `viewDidLoad` cần bọc `Task { }`.

### Ngày 2 — Task có cấu trúc và không cấu trúc

**Kiến thức**
- **Có cấu trúc** (`async let`, `TaskGroup`): task con sống trong phạm vi task cha, tự bị huỷ khi cha bị huỷ, cha chờ con xong mới thoát.
- **Không cấu trúc** (`Task { }`): sống độc lập, kế thừa actor và priority của ngữ cảnh tạo ra nó, *không* tự bị huỷ. Bạn phải giữ handle để huỷ.
- `Task.detached { }`: không kế thừa gì. Hiếm khi cần.

**Ví dụ**
```swift
@MainActor
final class DetailViewModel {
    private var loadTask: Task<Void, Never>?

    func onAppear() {
        loadTask = Task {            // kế thừa @MainActor
            await self.load()
        }
    }

    func onDisappear() {
        loadTask?.cancel()           // không ai huỷ hộ bạn
    }

    private func load() async { /* ... */ }
}
```

**Bài tập:** Viết 4 đoạn code nhỏ chứng minh bằng `print`: (1) `Task {}` trong hàm `@MainActor` chạy trên main thread, (2) `Task.detached` thì không, (3) huỷ task cha thì task con `async let` bị huỷ, (4) huỷ task cha không ảnh hưởng `Task {}` tạo bên trong nó.

### Ngày 3 — `async let` và `TaskGroup`

**Kiến thức**
- `async let`: số lượng việc song song cố định, biết trước lúc viết code.
- `withThrowingTaskGroup`: số lượng động (tải 20 ảnh). Một con ném lỗi thì nên `group.cancelAll()`.
- Giới hạn song song bằng cách chỉ thêm task mới khi một task cũ xong (sliding window).

**Ví dụ**
```swift
func loadHome() async throws -> Home {
    async let banners = api.banners()
    async let categories = api.categories()
    async let nearby = api.nearbyRestaurants()
    return try await Home(banners: banners, categories: categories, nearby: nearby)
}

func downloadAll(_ urls: [URL], maxConcurrent: Int = 4) async throws -> [URL: Data] {
    try await withThrowingTaskGroup(of: (URL, Data).self) { group in
        var results: [URL: Data] = [:]
        var iterator = urls.makeIterator()
        for _ in 0..<maxConcurrent {
            guard let url = iterator.next() else { break }
            group.addTask { (url, try await self.fetch(url)) }
        }
        while let finished = try await group.next() {
            let (url, data) = finished
            results[url] = data
            if let next = iterator.next() { group.addTask { (next, try await self.fetch(next)) } }
        }
        return results
    }
}
```

**Bài tập:** Viết `loadHome` sao cho banner lỗi thì vẫn hiển thị phần còn lại (không ném lỗi cả trang). Viết `downloadAll` có giới hạn 4 request song song và đo bằng một fake network rằng không bao giờ có quá 4 request cùng lúc.

### Ngày 4 — Cancellation là hợp tác

**Kiến thức**
- `task.cancel()` chỉ **đặt cờ**. Code phải tự kiểm tra: `try Task.checkCancellation()` hoặc `Task.isCancelled`.
- API hệ thống như `URLSession`, `Task.sleep` tự phản ứng: ném lỗi khi bị huỷ. `URLSession` ném `URLError(.cancelled)`, không phải `CancellationError`.
- Vòng lặp nặng phải kiểm tra cờ huỷ định kỳ.

**Ví dụ**
```swift
func resize(_ images: [UIImage]) async throws -> [UIImage] {
    var output: [UIImage] = []
    for image in images {
        try Task.checkCancellation()      // thoát sớm nếu người dùng rời màn hình
        output.append(await image.byPreparingThumbnail(ofSize: CGSize(width: 200, height: 200)) ?? image)
    }
    return output
}
```

**Bài tập:** Viết hàm xử lý 1.000 ảnh có thanh tiến độ và nút Huỷ. Chứng minh: không kiểm tra cờ thì bấm Huỷ vẫn chạy hết; có kiểm tra thì dừng trong vòng 1 ảnh. Viết hàm `isCancellation(_ error: any Error) -> Bool` nhận cả `CancellationError` và `URLError(.cancelled)`.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Tải dự án ConcurrencyLab, chạy `swift test -Xswiftc -DSOLUTION` để chắc môi trường đúng, rồi đọc kỹ `Sources/LabTestSupport/ControlledCalls.swift` và `Metric.swift`. Viết lại bằng lời vào `NOTES.md`: fake giữ request lại bằng cách nào, vì sao test không cần `sleep` dài mà vẫn tất định, và vì sao `Metric.wait` phải xử lý trường hợp bị huỷ *trước khi* kịp đăng ký continuation.

---

## Tuần 2 · Actor và isolation

### Ngày 6 — Actor

**Kiến thức**
- Actor bảo vệ state của nó: tại một thời điểm chỉ một đoạn code chạy trên actor. Truy cập từ ngoài phải `await`.
- Hàm `nonisolated` của actor không được đọc state có thể thay đổi; dùng cho hàm thuần hoặc `let` hằng.
- Actor không thay thế mọi lock: truy cập luôn bất đồng bộ.

**Ví dụ**
```swift
actor BankAccount {
    private(set) var balance: Decimal = 0
    let accountNumber: String
    init(accountNumber: String) { self.accountNumber = accountNumber }

    func deposit(_ amount: Decimal) { balance += amount }
    func withdraw(_ amount: Decimal) throws {
        guard balance >= amount else { throw BankError.insufficientFunds }
        balance -= amount
    }
    nonisolated var maskedNumber: String { "••••" + accountNumber.suffix(4) }
}

let account = BankAccount(accountNumber: "0123456789")
await account.deposit(100)
```

**Bài tập:** Viết `actor Inventory` quản lý tồn kho với `reserve(productID:quantity:)` và `release`. Chạy 1.000 lệnh `reserve` song song bằng `TaskGroup` và chứng minh tồn kho không bao giờ âm. Viết lại bằng class + không lock, chạy với `--sanitize=thread` và đọc báo cáo của TSan.

### Ngày 7 — Actor reentrancy

**Kiến thức**
- Tại mỗi `await` bên trong actor, actor có thể chạy lời gọi khác. Đây là **reentrancy**.
- Không có data race, nhưng có **race logic**: "kiểm tra → `await` → hành động" không còn nguyên tử.
- Cách chữa: lưu *việc đang làm* (một `Task`) thay vì *cờ đang làm*; kiểm tra lại state sau mỗi `await`.

**Ví dụ**
```swift
actor TokenStore {
    private var token: String?

    // SAI: hai lời gọi đồng thời cùng thấy token == nil, cùng refresh
    func validToken() async throws -> String {
        if let token { return token }
        let fresh = try await api.refresh()      // actor nhả ra ở đây
        token = fresh
        return fresh
    }
}
```

**Bài tập:** Viết test chứng minh `validToken()` ở trên gọi `refresh` 2 lần khi có 2 caller đồng thời (dùng `ControlledCalls` để giữ refresh lại). Sửa bằng cách lưu `Task<String, Error>?` đang chạy. Đây là bước khởi động cho Bài 1 và Bài 2.

### Ngày 8 — `@MainActor` và global actor

**Kiến thức**
- `@MainActor` đảm bảo code chạy trên main thread: bắt buộc cho UI. Gắn cho cả class ViewModel.
- `MainActor.run { }` hoặc `await` một hàm `@MainActor` để quay về main thread.
- Swift 6.2 có chế độ *default isolation MainActor* cho target app: mọi thứ mặc định trên main, chỉ đánh dấu `nonisolated` / `@concurrent` cho phần chạy nền. Hợp với code UI, giảm lỗi biên dịch khi mới chuyển sang Swift 6.

**Ví dụ**
```swift
@MainActor
@Observable
final class FeedViewModel {
    var posts: [Post] = []
    private let service: FeedService

    init(service: FeedService) { self.service = service }

    func refresh() async {
        let fetched = (try? await service.fetchPosts()) ?? []   // service chạy nền
        posts = fetched                                         // quay về main tự động
    }
}
```

**Bài tập:** Lấy một ViewModel cũ đang dùng `DispatchQueue.main.async` rải rác, chuyển sang `@MainActor`, xoá mọi `DispatchQueue.main`. Thử bật cài đặt *Default Actor Isolation = MainActor* (Swift 6.2+) cho target app, ghi lại số lỗi/cảnh báo trước và sau.

### Ngày 9 — `Sendable` và region isolation

**Kiến thức**
- `Sendable`: an toàn để chuyển qua ranh giới isolation. Struct/enum có thành phần đều `Sendable` tự suy ra; class phải `final` và chỉ có `let` `Sendable`, hoặc được bảo vệ bằng lock (`@unchecked Sendable` kèm chứng minh).
- Region isolation (Swift 6) cho phép chuyển giá trị *không* `Sendable` nếu compiler chứng minh được bạn không dùng nó nữa ở chỗ cũ (`sending`).
- `@unchecked Sendable` và `nonisolated(unsafe)` là lời hứa với compiler; sai là crash lúc chạy.

**Ví dụ**
```swift
struct Order: Sendable { let id: UUID; let items: [String] }     // tự Sendable

final class ImageCache: @unchecked Sendable {                     // tự chứng minh an toàn
    private let lock = NSLock()
    private var storage: [URL: Data] = [:]
    func value(for url: URL) -> Data? { lock.withLock { storage[url] } }
    func insert(_ data: Data, for url: URL) { lock.withLock { storage[url] = data } }
}
```

**Bài tập:** Bật Swift 6 language mode cho một module trong dự án của bạn. Phân loại mọi lỗi `Sendable` thành 3 nhóm: sửa bằng cách đổi sang struct, sửa bằng actor/`@MainActor`, phải dùng lock. Viết lý do cho mỗi chỗ dùng `@unchecked Sendable` còn lại.

### Ngày 10 — ConcurrencyLab Bài 1: ImageLoader

**Bài tập:** Làm **Bài 1** trong ConcurrencyLab (`swift test --filter Bai1`). Yêu cầu chi tiết trong `BAI_KIEM_TRA.md`. Gom request trùng, cho phép từng caller huỷ riêng, huỷ download khi caller cuối rời đi, cache LRU theo byte. Viết đoạn PR description 5–10 dòng vào `NOTES.md`. Chưa mở `Solutions/`.

---

## Tuần 3 · Bắc cầu với code cũ và luồng bất đồng bộ

### Ngày 11 — Continuation: chuyển callback sang async

**Kiến thức**
- `withCheckedThrowingContinuation` biến API callback thành `async`. Continuation phải được resume **đúng một lần**: không resume thì task treo mãi, resume 2 lần thì crash.
- Dùng bản `Checked` khi phát triển (báo lỗi khi dùng sai), `Unsafe` chỉ khi đã đo được chi phí.
- Delegate gọi nhiều lần (vị trí GPS) không hợp với continuation; dùng `AsyncStream` (Ngày 13).

**Ví dụ**
```swift
extension CLGeocoder {
    func placemark(for location: CLLocation) async throws -> CLPlacemark? {
        try await withCheckedThrowingContinuation { continuation in
            reverseGeocodeLocation(location) { placemarks, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: placemarks?.first) }
            }
        }
    }
}
```

**Bài tập:** Chuyển một SDK giả lập có `func login(completion: @escaping (Result<User, Error>) -> Void)` sang `async`. Viết test cho trường hợp SDK gọi completion 2 lần (phải không crash: tự chặn bằng cờ) và không bao giờ gọi (phải có timeout).

### Ngày 12 — `withTaskCancellationHandler`

**Kiến thức**
- Continuation không tự phản ứng với cancellation. `withTaskCancellationHandler(operation:onCancel:)` cho bạn một chỗ để huỷ công việc bên dưới.
- `onCancel` chạy **đồng bộ, ngay lập tức, trên thread gọi `cancel()`**, có thể trước cả khi `operation` kịp đăng ký continuation. Phải xử lý race này.
- Đây là nền tảng để mỗi caller của Bài 1 thoát riêng.

**Ví dụ**
```swift
func download(_ url: URL) async throws -> Data {
    let box = DownloadBox()                      // class Sendable giữ URLSessionTask, có lock
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: url) { data, _, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? URLError(.unknown)) }
            }
            box.start(task)                      // nếu đã bị huỷ từ trước, box huỷ ngay
        }
    } onCancel: {
        box.cancel()
    }
}
```

**Bài tập:** Cài đặt `DownloadBox` ở trên: lưu task trong lock; `cancel()` gọi trước `start()` thì `start()` phải huỷ task ngay. Viết test cho cả hai thứ tự. So sánh với cách `Metric.wait` trong ConcurrencyLab xử lý cùng vấn đề.

### Ngày 13 — `AsyncSequence` và `AsyncStream`

**Kiến thức**
- `AsyncSequence`: dãy giá trị đến dần, đọc bằng `for await`. Ví dụ: `URL.lines`, `NotificationCenter.notifications(named:)`.
- `AsyncStream.makeStream(of:bufferingPolicy:)` biến delegate/callback nhiều lần thành stream. `continuation.onTermination` được gọi khi người đọc ngừng (task bị huỷ) để dọn dẹp.
- Chọn `bufferingPolicy` có chủ đích: `.bufferingNewest(1)` cho giá trị "chỉ cần mới nhất" như vị trí, giá cổ phiếu.

**Ví dụ**
```swift
// CLLocationManager chỉ được tạo và dùng trên main thread, nên ở đây tự chứng minh an toàn.
final class LocationStream: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<CLLocation>.Continuation?

    func locations() -> AsyncStream<CLLocation> {
        let (stream, continuation) = AsyncStream.makeStream(of: CLLocation.self,
                                                            bufferingPolicy: .bufferingNewest(1))
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in self?.manager.stopUpdatingLocation() }
        manager.delegate = self
        manager.startUpdatingLocation()
        return stream
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.forEach { continuation?.yield($0) }
    }
}
```

**Bài tập:** Viết `func keyboardHeights() -> AsyncStream<CGFloat>` từ notification bàn phím, và một view dùng nó qua `.task`. Kiểm tra rằng rời màn hình thì `onTermination` chạy. Đọc trước Bài 5 trong `BAI_KIEM_TRA.md`.

### Ngày 14 — Chuyển dự án sang Swift 6

**Kiến thức**
- Lộ trình an toàn: bật `Strict Concurrency Checking = Complete` ở Swift 5 mode → sửa cảnh báo theo từng module → bật Swift 6 language mode.
- `@preconcurrency import` cho thư viện bên thứ ba chưa cập nhật; ghi chú để gỡ sau.
- Swift 6.2: `nonisolated(nonsending)` cho hàm async chạy trên isolation của người gọi, `@concurrent` khi muốn chắc chắn chạy nền.

**Ví dụ**
```swift
// Package.swift: bật từng module
.target(
    name: "Networking",
    swiftSettings: [.swiftLanguageMode(.v6)]
),
.target(
    name: "LegacyUI",
    swiftSettings: [.swiftLanguageMode(.v5),
                    .enableUpcomingFeature("StrictConcurrency")]
)
```

**Bài tập:** Lập kế hoạch chuyển dự án của bạn sang Swift 6: danh sách module theo thứ tự (lá trước, gốc sau), ước lượng số cảnh báo mỗi module, rủi ro. Thực hiện cho 1 module lá và ghi lại 5 loại lỗi gặp nhiều nhất.

### Ngày 15 — ConcurrencyLab Bài 2: AuthenticatedClient

**Bài tập:** Làm **Bài 2** (`swift test --filter Bai2`): refresh token single-flight, so token đã dùng với token hiện tại, retry đúng một lần, phân biệt `invalidGrant` với lỗi mạng. Viết PR description vào `NOTES.md`. Câu hỏi thêm: nếu app có Notification Service Extension cũng cần token thì thiết kế thế nào?

---

## Tuần 4 · Thời gian, lock và vòng đời task

### Ngày 16 — Clock, sleep, debounce và ConcurrencyLab Bài 3

**Kiến thức**
- `Task.sleep(for:)` tôn trọng cancellation: hợp làm debounce. `ContinuousClock` (tính cả lúc máy ngủ) và `SuspendingClock`.
- Debounce = chờ một khoảng rồi mới làm, mỗi lần có sự kiện mới thì huỷ lần chờ trước.
- Trừu tượng hoá thời gian (`protocol Sleeper` hoặc `any Clock<Duration>`) để test không phải chờ thật.

**Ví dụ**
```swift
@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    func call(after delay: Duration, _ action: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await action()
        }
    }
}
```

**Bài tập:** Làm **Bài 3** (`swift test --filter Bai3`): bỏ qua response lỗi thời, debounce, xoá ô tìm kiếm, cắt khoảng trắng, xoá lỗi khi thành công. Chú ý API trong test phớt lờ cancellation.

### Ngày 17 — Lock hay actor? ConcurrencyLab Bài 4

**Kiến thức**
- Lock cho state cần truy cập **đồng bộ** từ mọi nơi, giữ trong thời gian cực ngắn: `OSAllocatedUnfairLock` (iOS 16+), `Mutex` trong module `Synchronization` (iOS 18+), `NSLock`.
- **Không bao giờ giữ lock qua `await`.** Lấy dữ liệu ra trong lock, xử lý ngoài lock.
- Actor cho state mà mọi truy cập đều có thể `async`. Lock và actor kết hợp được.

**Ví dụ**
```swift
import Synchronization

final class Counter: Sendable {
    private let value = Mutex(0)
    func increment() -> Int {
        value.withLock { v in v += 1; return v }
    }
}
```

**Bài tập:** Làm **Bài 4** (`swift test --filter Bai4 --sanitize=thread`): `log` đồng bộ an toàn luồng, không mất sự kiện khi đang upload, trả batch lỗi về đầu hàng đợi, buffer có giới hạn, flush tuần tự. Viết PR description, giải thích vì sao không đổi cả class thành actor.

### Ngày 18 — Task bắt `self`, `isolated deinit`, ConcurrencyLab Bài 5

**Kiến thức**
- `Task { for await x in stream { self.value = x } }` giữ `self` suốt vòng lặp; stream không kết thúc thì object không bao giờ được giải phóng.
- `[weak self]` + `guard let self` **trong thân vòng lặp**; giữ handle của Task để huỷ.
- `deinit` của class `@MainActor` là nonisolated ở Swift 6. Swift 6.2 có `isolated deinit`; cách tương thích là để một object `Sendable` nhỏ giữ Task và huỷ trong `deinit` của nó.

**Ví dụ**
```swift
Task { [weak self, stream] in
    for await price in stream {
        guard let self else { return }   // self mạnh chỉ trong một lượt lặp
        self.latest = price
    }
}
```

**Bài tập:** Làm **Bài 5** (`swift test --filter Bai5`): một kết nối socket dùng chung, huỷ đăng ký qua `onTermination`, đóng socket khi không còn ai, ViewModel không leak khi quên `stop()`, `start()` lặp lại không tạo hai subscription.

### Ngày 19 — Có gì mới trong Swift 6.4

**Kiến thức**
- `await` dùng được trong `defer`: dọn dẹp tài nguyên bất đồng bộ (đóng kết nối, xoá file tạm) đáng tin cậy hơn.
- Khai báo availability chung `@available(anyAppleOS 27, *)` thay vì liệt kê từng hệ điều hành.
- Điều khiển cảnh báo theo vùng code: ẩn cảnh báo ở chỗ chưa xử lý được, hoặc nâng thành lỗi ở chỗ quan trọng.
- Type checker nhanh hơn với biểu thức phức tạp, thông báo lỗi rõ hơn.
- Nguồn: phiên *Platforms State of the Union* và *What's new in Swift* của WWDC26.

**Ví dụ**
```swift
func exportReport() async throws -> URL {
    let temp = try await TempFolder.create()
    defer { await temp.cleanUp() }        // Swift 6.4: await trong defer
    return try await renderPDF(into: temp)
}
```

**Bài tập:** Xem video *What's new in Swift* (WWDC26). Viết 1 trang ghi chú: 5 thay đổi ảnh hưởng tới dự án của bạn, mỗi thay đổi kèm một đoạn code trước/sau. Thay một chỗ dọn dẹp dùng `Task { }` trong `defer` bằng `await` trực tiếp.

### Ngày 20 — Ôn tập và kiểm tra tháng 4

**Bài tập:**
- Chạy `swift test --sanitize=thread` cho toàn bộ ConcurrencyLab: phải xanh 31/31 và không có cảnh báo TSan.
- Bây giờ mới mở `Sources/Solutions/` và `GIAI_THICH.md`. Với mỗi bài, so với đáp án và ghi vào `NOTES.md` một điểm bạn làm khác và đánh giá cách nào tốt hơn.
- Tự chấm theo barem trong `BAI_KIEM_TRA.md` (100 điểm).
- Làm lại câu 8–12 của bài trắc nghiệm.

**Tự đánh giá:** giải thích không nhìn tài liệu: actor reentrancy là gì và 3 cách chữa; khác biệt task có cấu trúc/không cấu trúc về cancellation; vì sao `Task.value` không dừng khi người chờ bị huỷ; khi nào chọn lock thay vì actor.
