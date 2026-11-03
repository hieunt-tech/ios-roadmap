# Tháng 6 — Networking và lưu trữ dữ liệu

**Mục tiêu:** viết lớp mạng chịu được lỗi thật (mất mạng, timeout, 401, phân trang), lưu dữ liệu cục bộ bằng SwiftData, thiết kế offline-first.
**Đầu ra cuối tháng:** Mốc **M2** hoàn chỉnh (module Networking dùng actor, strict concurrency bật, ADR) và bài kiểm tra năng lực **lần 2**.

[← Tháng 5](thang-05.md) · [Mục lục](../../README.md) · [Tháng 7 →](thang-07.md)

---

## Tuần 1 · Lớp mạng

### Ngày 1 — URLSession async và HTTP căn bản

**Kiến thức**
- `let (data, response) = try await URLSession.shared.data(for: request)`. Phải ép kiểu `response` thành `HTTPURLResponse` để đọc status code; URLSession **không** ném lỗi khi server trả 404 hay 500.
- Phương thức, header, body; `Content-Type`, `Accept`; timeout (`timeoutInterval`).
- `URLSessionConfiguration`: `waitsForConnectivity`, `requestCachePolicy`, `httpMaximumConnectionsPerHost`.

**Ví dụ**
```swift
var request = URLRequest(url: URL(string: "https://api.example.com/products?page=1")!)
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.timeoutInterval = 15

let (data, response) = try await URLSession.shared.data(for: request)
guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
guard (200..<300).contains(http.statusCode) else { throw APIError.status(http.statusCode, data) }
let products = try JSONDecoder().decode([Product].self, from: data)
```

**Bài tập:** Dùng một API công khai miễn phí (ví dụ JSONPlaceholder). Gọi GET danh sách, GET chi tiết, POST tạo mới, xử lý 404. Dùng Proxyman hoặc Charles để xem request thật, chụp ảnh header gửi đi.

### Ngày 2 — API client theo Endpoint

**Kiến thức**
- Mô tả mỗi API bằng một giá trị `Endpoint<Response>` (path, method, query, body) thay vì một hàm riêng cho mỗi API.
- Client chung: dựng `URLRequest`, gửi, kiểm tra status, decode. Inject `URLSession` hoặc protocol `HTTPTransport` để test.
- Generic `Response` giữ type-safety: gọi sai kiểu là lỗi biên dịch.

**Ví dụ**
```swift
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    var path: String
    var method = "GET"
    var query: [URLQueryItem] = []
    var body: Data?
}

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct APIClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport
    let decoder = JSONDecoder()

    func send<R>(_ endpoint: Endpoint<R>) async throws -> R {
        var components = URLComponents(url: baseURL.appending(path: endpoint.path),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method
        request.httpBody = endpoint.body
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.status(response.statusCode, data)
        }
        return try decoder.decode(R.self, from: data)
    }
}

extension Endpoint where Response == [Product] {
    static func products(page: Int) -> Self {
        Endpoint(path: "products", query: [URLQueryItem(name: "page", value: "\(page)")])
    }
}
```

**Bài tập:** Viết module `Networking` theo mẫu trên, với 5 endpoint của dự án xuyên suốt. Viết `FakeTransport` trả dữ liệu từ file JSON trong thư mục test. Viết test cho: query string đúng, header đúng, 404 thành lỗi, JSON sai thành lỗi decode.

### Ngày 3 — Lỗi, retry và exponential backoff

**Kiến thức**
- Chỉ retry lỗi *tạm thời*: timeout, mất mạng, 502/503/504, 429 (đọc header `Retry-After`). Không retry 400, 401, 404, lỗi decode.
- Exponential backoff + jitter: chờ 0,5s → 1s → 2s (± ngẫu nhiên) để hàng nghìn máy không cùng retry một lúc.
- Request không idempotent (POST tạo đơn) chỉ retry khi có idempotency key, nếu không sẽ tạo đơn trùng.

**Ví dụ**
```swift
func withRetry<T: Sendable>(
    maxAttempts: Int = 3,
    baseDelay: Duration = .milliseconds(500),
    shouldRetry: (any Error) -> Bool,
    _ operation: () async throws -> T
) async throws -> T {
    var attempt = 1
    while true {
        do { return try await operation() }
        catch where attempt < maxAttempts && shouldRetry(error) {
            let exponential = baseDelay * (1 << (attempt - 1))
            let jitter = Duration.milliseconds(Int.random(in: 0...200))
            try await Task.sleep(for: exponential + jitter)
            attempt += 1
        }
    }
}
```

**Bài tập:** Thêm retry vào `APIClient` theo bảng phân loại lỗi của bạn. Inject `Sleeper` (giống ConcurrencyLab) để test không phải chờ thật. Viết test: 503 hai lần rồi 200 → thành công sau 3 lần; 404 → không retry; bị huỷ giữa lúc chờ → dừng ngay.

### Ngày 4 — Xác thực: header, Keychain, refresh

**Kiến thức**
- Lưu token trong **Keychain**, không trong `UserDefaults`. Chọn `kSecAttrAccessibleAfterFirstUnlock` nếu cần dùng ở background.
- Gắn header `Authorization: Bearer <token>` ở một chỗ (decorator quanh transport).
- Refresh token: dùng lại lời giải Bài 2 ConcurrencyLab (single-flight, so token, retry một lần).

**Ví dụ**
```swift
struct KeychainStore {
    let service: String

    func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}
```

**Bài tập:** Hoàn thiện `KeychainStore` (save/load/delete) có test trên simulator. Viết `AuthenticatedTransport` bọc `HTTPTransport`: gắn token, gặp 401 thì refresh theo logic Bài 2, lưu token mới vào Keychain. Đăng xuất phải xoá Keychain.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Hoàn thiện module `Networking` cho dự án xuyên suốt: endpoint, retry có backoff, xác thực tự refresh, log bằng `Logger` (ẩn token). Coverage của module ≥ 70%. Mọi type public là `Sendable`, module bật Swift 6 language mode.

---

## Tuần 2 · Cache, ảnh, mạng chập chờn và phân trang

### Ngày 6 — HTTP caching: URLCache, ETag

**Kiến thức**
- `URLCache` tôn trọng header `Cache-Control` của server. Cấu hình dung lượng bộ nhớ/đĩa trong `URLSessionConfiguration`.
- ETag / `If-None-Match`: server trả 304 Not Modified nếu dữ liệu không đổi, tiết kiệm băng thông.
- Cache của app (dữ liệu đã parse) khác cache HTTP (bytes thô). Thường cần cả hai.

**Ví dụ**
```swift
let configuration = URLSessionConfiguration.default
configuration.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024,
                                  diskCapacity: 100 * 1024 * 1024)
configuration.requestCachePolicy = .useProtocolCachePolicy
let session = URLSession(configuration: configuration)
```

**Bài tập:** Viết endpoint danh mục sản phẩm dùng ETag: lưu ETag lần trước, gửi `If-None-Match`, nhận 304 thì dùng dữ liệu đã lưu. Đo số byte tải về qua 10 lần mở màn hình trước và sau.

### Ngày 7 — Pipeline ảnh

**Kiến thức**
- Ảnh là nguồn tốn bộ nhớ số 1: ảnh 4000×3000 giải mã chiếm khoảng 48 MB dù hiển thị ở 100×100.
- **Downsample** bằng ImageIO trước khi hiển thị: `CGImageSourceCreateThumbnailAtIndex` với `kCGImageSourceThumbnailMaxPixelSize`.
- Pipeline đầy đủ: cache bộ nhớ (ảnh đã giải mã) → cache đĩa (bytes) → mạng; gộp request trùng (Bài 1).

**Ví dụ**
```swift
func downsample(_ data: Data, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
    let maxPixel = max(pointSize.width, pointSize.height) * scale
    let thumbOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxPixel] as CFDictionary
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
    return UIImage(cgImage: cg)
}
```

**Bài tập:** Mở rộng `ImageLoader` của Bài 1 thành pipeline: downsample theo kích thước cell, cache đĩa trong thư mục `Caches`, cache bộ nhớ giới hạn. Đo bộ nhớ bằng Xcode Memory Report khi cuộn 500 ảnh lớn, trước và sau khi downsample.

### Ngày 8 — Mạng chập chờn: NWPathMonitor

**Kiến thức**
- `NWPathMonitor` cho biết có mạng không, mạng đắt (cellular, hotspot) hay bị giới hạn (Low Data Mode).
- Đừng chặn request chỉ vì monitor báo mất mạng: cứ thử, `waitsForConnectivity` cho phép chờ mạng.
- Dùng Network Link Conditioner (Settings → Developer trên máy thật) để giả lập 3G, mất gói.

**Ví dụ**
```swift
import Network

func networkStatus() -> AsyncStream<NWPath> {
    AsyncStream { continuation in
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { continuation.yield($0) }
        continuation.onTermination = { _ in monitor.cancel() }
        monitor.start(queue: DispatchQueue(label: "network-monitor"))
    }
}
```

**Bài tập:** Thêm banner "Bạn đang offline" vào app, tự ẩn khi có mạng. Khi đang dùng 4G và bật Low Data Mode, chỉ tải ảnh thumbnail, không tải video tự phát. Thử với Network Link Conditioner ở profile "Very Bad Network".

### Ngày 9 — Phân trang

**Kiến thức**
- Offset (`page=3`) đơn giản nhưng lệch khi có dữ liệu mới chèn vào đầu. Cursor (`after=abc`) ổn định hơn.
- Tránh tải trùng: chỉ một request trang tiếp theo tại một thời điểm; trạng thái `idle / loadingMore / reachedEnd / failed`.
- Kích hoạt tải thêm khi phần tử gần cuối xuất hiện (`onAppear` của hàng thứ n−5).

**Ví dụ**
```swift
@MainActor @Observable
final class FeedPager {
    enum Phase: Equatable { case idle, loadingMore, reachedEnd, failed }
    private(set) var posts: [Post] = []
    private(set) var phase: Phase = .idle
    private var cursor: String?
    private let api: any FeedAPI
    init(api: any FeedAPI) { self.api = api }

    func loadMoreIfNeeded(current post: Post) async {
        // Chỉ tải khi hàng đang hiện nằm trong 5 hàng cuối
        let threshold = max(posts.count - 5, 0)
        guard phase == .idle,
              let index = posts.firstIndex(where: { $0.id == post.id }),
              index >= threshold else { return }
        phase = .loadingMore
        do {
            let page = try await api.feed(after: cursor)
            posts += page.items.filter { new in !posts.contains { $0.id == new.id } }
            cursor = page.nextCursor
            phase = page.nextCursor == nil ? .reachedEnd : .idle
        } catch { phase = .failed }
    }
}
```

**Bài tập:** Viết test cho `FeedPager`: cuộn nhanh gọi `loadMoreIfNeeded` 10 lần → chỉ 1 request; trang trả về có phần tử trùng → không hiển thị trùng; lỗi → hiện nút "Thử lại" ở cuối danh sách; hết dữ liệu → không gọi thêm.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Feed vô hạn hoàn chỉnh: kéo để làm mới (thay danh sách, giữ vị trí cuộn hợp lý), tải thêm theo cursor, ảnh qua pipeline Ngày 7, banner offline, retry khi có mạng lại. Kiểm tra với Network Link Conditioner và ghi lại 3 lỗi tìm được.

---

## Tuần 3 · SwiftData

### Ngày 11 — `@Model` và `ModelContainer`

**Kiến thức**
- `@Model` biến class thành model lưu trữ. `ModelContainer` quản lý lưu trữ; `ModelContext` là "phiên làm việc" để thêm, sửa, xoá.
- SwiftUI: `.modelContainer(for: [Note.self])` ở `App`, lấy context bằng `@Environment(\.modelContext)`.
- Dùng `ModelConfiguration(isStoredInMemoryOnly: true)` cho preview và test.

**Ví dụ**
```swift
import SwiftData

@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date
    var isPinned = false
    init(title: String, body: String, createdAt: Date = .now) {
        self.title = title; self.body = body; self.createdAt = createdAt
    }
}

@main
struct NotesApp: App {
    var body: some Scene { WindowGroup { NoteList() }.modelContainer(for: Note.self) }
}
```

**Bài tập:** Viết app ghi chú: thêm, sửa, xoá, ghim. Dữ liệu còn sau khi tắt app. Viết preview dùng container trong bộ nhớ với 20 ghi chú mẫu.

### Ngày 12 — `@Query`, `#Predicate`, sắp xếp

**Kiến thức**
- `@Query(filter:sort:)` trong view tự cập nhật khi dữ liệu đổi.
- `#Predicate<Note> { $0.isPinned && $0.title.localizedStandardContains(text) }` được dịch sang truy vấn của kho lưu trữ; không phải mọi biểu thức Swift đều hỗ trợ.
- Query động theo tham số: tạo `@Query` trong `init` của view con.

**Ví dụ**
```swift
struct NoteList: View {
    @Query private var notes: [Note]

    init(search: String) {
        let predicate = #Predicate<Note> { note in
            search.isEmpty || note.title.localizedStandardContains(search)
        }
        _notes = Query(filter: predicate,
                       sort: [SortDescriptor(\.isPinned, order: .reverse),
                              SortDescriptor(\.createdAt, order: .reverse)])
    }

    var body: some View { List(notes) { Text($0.title) } }
}
```

**Bài tập:** Thêm tìm kiếm, lọc theo nhãn, sắp xếp theo ngày/tên vào app ghi chú. Dùng `FetchDescriptor` với `fetchLimit` để đếm số ghi chú mỗi nhãn mà không tải hết. Đo thời gian với 10.000 ghi chú.

### Ngày 13 — Quan hệ và migration

**Kiến thức**
- Quan hệ: `@Relationship(deleteRule: .cascade, inverse: \Tag.notes) var tags: [Tag]`.
- Thêm thuộc tính có giá trị mặc định thường migrate tự động (lightweight). Đổi tên, tách dữ liệu cần `VersionedSchema` + `SchemaMigrationPlan`.
- `@Attribute(.unique)` cho khoá duy nhất; `@Attribute(originalName:)` khi đổi tên thuộc tính.

**Ví dụ**
```swift
enum NotesSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Note.self] }
    @Model final class Note { var title: String = ""; init() {} }
}

enum NotesSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Note.self] }
    @Model final class Note {
        @Attribute(originalName: "title") var heading: String = ""
        var isPinned = false
        init() {}
    }
}

enum NotesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NotesSchemaV1.self, NotesSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: NotesSchemaV1.self, toVersion: NotesSchemaV2.self)]
    }
}
```

**Bài tập:** Thêm `Tag` quan hệ nhiều-nhiều với `Note`. Mô phỏng phát hành phiên bản 2 có đổi tên `title` → `heading` và tách `body` thành `summary` + `content` (custom migration). Viết test mở store V1 có dữ liệu, migrate lên V2, kiểm tra dữ liệu không mất.

### Ngày 14 — SwiftData và concurrency

**Kiến thức**
- Model và `ModelContext` **không** `Sendable`: không truyền model giữa các actor. Truyền `PersistentIdentifier` rồi lấy lại trong context đích.
- `@ModelActor` tạo actor có context riêng để ghi dữ liệu lớn ở nền (import 10.000 bản ghi) mà không khựng UI.
- Lưu theo lô (`save()` mỗi 500 bản ghi) để giới hạn bộ nhớ.

**Ví dụ**
```swift
@ModelActor
actor NoteImporter {
    func importNotes(_ dtos: [NoteDTO]) throws {
        for (index, dto) in dtos.enumerated() {
            modelContext.insert(Note(title: dto.title, body: dto.body))
            if index % 500 == 499 { try modelContext.save() }
        }
        try modelContext.save()
    }
}

let importer = NoteImporter(modelContainer: container)
try await importer.importNotes(dtos)
```

**Bài tập:** Import 20.000 ghi chú từ file JSON ở nền, có thanh tiến độ và nút huỷ, UI vẫn cuộn mượt. Kiểm tra bằng Instruments → Hangs: không có hang nào trên main thread khi import.

### Ngày 15 — Thực hành tuần 3

**Bài tập:** App ghi chú offline đầy đủ: SwiftData, nhãn, tìm kiếm, import/export JSON, migration V1→V2 có test. Mọi thao tác ghi nặng chạy trong `@ModelActor`. Chạy với Swift 6 language mode không cảnh báo.

---

## Tuần 4 · Lưu trữ khác, đồng bộ và bảo mật

### Ngày 16 — Core Data: đọc hiểu code cũ

**Kiến thức**
- Nhiều app đang chạy vẫn dùng Core Data. Cần đọc được: `NSPersistentContainer`, `viewContext` (main) và `newBackgroundContext()`.
- Quy tắc vàng: object chỉ dùng trên context tạo ra nó; giữa các context truyền `NSManagedObjectID`; mọi thao tác trong `context.perform { }`.
- SwiftData được xây trên cùng nền tảng lưu trữ; có thể dùng chung store khi migrate dần.

**Ví dụ**
```swift
let context = container.newBackgroundContext()
try await context.perform {
    let request = NSFetchRequest<NSManagedObject>(entityName: "Order")
    request.predicate = NSPredicate(format: "status == %@", "pending")
    let pending = try context.fetch(request)
    pending.forEach { $0.setValue("cancelled", forKey: "status") }
    try context.save()
}
```

**Bài tập:** Đọc một dự án mẫu dùng Core Data (template Xcode có tick "Core Data"). Viết 1 trang: luồng dữ liệu từ màn hình xuống store, chỗ nào có nguy cơ dùng object sai thread, và kế hoạch chuyển dần sang SwiftData.

### Ngày 17 — UserDefaults, FileManager, App Group

**Kiến thức**
- `UserDefaults`: cài đặt nhỏ (dưới vài KB). Không lưu token, không lưu danh sách lớn.
- File: `Documents` (người dùng thấy, được sao lưu), `Application Support` (dữ liệu app, được sao lưu), `Caches` (hệ thống có thể xoá), `tmp`.
- App Group: chia sẻ dữ liệu giữa app và widget/extension (`UserDefaults(suiteName:)`, `containerURL(forSecurityApplicationGroupIdentifier:)`).

**Ví dụ**
```swift
let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)
let draftURL = support.appending(path: "draft.json")
try JSONEncoder().encode(draft).write(to: draftURL, options: [.atomic, .completeFileProtection])

let shared = UserDefaults(suiteName: "group.com.example.shop")
shared?.set(cart.items.count, forKey: "cartCount")   // widget đọc được
```

**Bài tập:** Viết `DraftStore` lưu bản nháp đơn hàng bằng file (ghi atomic, có bảo vệ dữ liệu), tự xoá bản nháp cũ hơn 7 ngày. Tạo App Group và chia sẻ số món trong giỏ cho một widget đơn giản.

### Ngày 18 — Đồng bộ offline-first

**Kiến thức**
- Offline-first: ghi vào kho cục bộ trước, UI đọc từ kho cục bộ, một tiến trình đồng bộ đẩy thay đổi lên server khi có mạng.
- Hàng đợi thay đổi (outbox) với id ổn định để retry không tạo bản trùng.
- Xung đột: last-write-wins (đơn giản, có thể mất dữ liệu), so phiên bản (`version`/`updatedAt`), hoặc gộp theo trường.

**Ví dụ**
```swift
@Model
final class PendingChange {
    @Attribute(.unique) var id: UUID
    var entityID: UUID
    var kind: String          // "create" | "update" | "delete"
    var payload: Data
    var attempts = 0
    var createdAt: Date
    init(entityID: UUID, kind: String, payload: Data) {
        id = UUID(); self.entityID = entityID; self.kind = kind
        self.payload = payload; createdAt = .now
    }
}
```

**Bài tập:** Thiết kế (viết tài liệu, chưa cần code đầy đủ) đồng bộ cho app ghi chú: luồng tạo/sửa/xoá khi offline, outbox, chiến lược xung đột khi cùng ghi chú bị sửa trên 2 máy, và hiển thị trạng thái "chưa đồng bộ" trên từng ghi chú. Cài đặt phần outbox + retry.

### Ngày 19 — Bảo mật dữ liệu và mạng

**Kiến thức**
- App Transport Security bắt buộc HTTPS; đừng thêm ngoại lệ `NSAllowsArbitraryLoads`.
- Certificate pinning (`URLSessionDelegate` kiểm tra public key) cho app tài chính; phải có kế hoạch xoay vòng khoá để không khoá chết người dùng.
- Data Protection: file nhạy cảm dùng `.completeFileProtection`. Không log token, không đưa dữ liệu cá nhân vào URL query.

**Ví dụ**
```swift
final class PinningDelegate: NSObject, URLSessionDelegate {
    let pinnedKeyHashes: Set<String>
    init(pinnedKeyHashes: Set<String>) { self.pinnedKeyHashes = pinnedKeyHashes }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge)
        async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let trust = challenge.protectionSpace.serverTrust,
              let key = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
                .flatMap(SecCertificateCopyKey),
              let keyData = SecKeyCopyExternalRepresentation(key, nil) as Data?,
              pinnedKeyHashes.contains(keyData.sha256Base64) else {
            return (.cancelAuthenticationChallenge, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}
// sha256Base64: tự viết bằng CryptoKit (SHA256.hash(data:))
```

**Bài tập:** Rà soát bảo mật dự án theo checklist 10 mục (ATS, Keychain, log, URL query, file protection, clipboard, screenshot khi vào background cho màn hình nhạy cảm, jailbreak không cần chặn nhưng cần biết, dữ liệu trong `UserDefaults`, quyền truy cập). Sửa các mục chưa đạt.

### Ngày 20 — Mốc M2 và kiểm tra lần 2

**Bài tập (Mốc M2):** Dự án xuyên suốt có: ≥ 3 Swift Package, module Networking dùng actor cho phần có state (token, cache), strict concurrency/Swift 6 bật cho mọi module mới, dữ liệu offline bằng SwiftData, 1 ADR cập nhật.

**Kiểm tra lần 2:** làm lại toàn bộ bài kiểm tra năng lực (Phần A, ConcurrencyLab làm lại từ đầu trên một nhánh mới, Phần C thiết kế màn hình feed có phân trang + offline). Ghi điểm vào bảng tiến độ trong README và so với lần 1.
