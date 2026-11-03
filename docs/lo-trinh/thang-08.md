# Tháng 8 — Hiệu năng

**Mục tiêu:** đo trước khi sửa. Dùng thành thạo Instruments để tìm nguyên nhân app chậm, giật, tốn bộ nhớ, tốn pin; sửa và chứng minh bằng số liệu.
**Đầu ra cuối tháng:** báo cáo hiệu năng của dự án xuyên suốt có số liệu trước/sau cho thời gian khởi động, độ mượt cuộn, bộ nhớ đỉnh.

**Quy tắc cả tháng:** luôn đo trên **máy thật**, bản **Release** (Edit Scheme → Profile dùng Release). Simulator và bản Debug cho số liệu sai.

[← Tháng 7](thang-07.md) · [Mục lục](../../README.md) · [Tháng 9 →](thang-09.md)

---

## Tuần 1 · CPU và độ mượt

### Ngày 1 — Tổng quan Instruments

**Kiến thức**
- Mở bằng Product → Profile (⌘I). Template hay dùng: Time Profiler, Allocations, Leaks, Hangs, SwiftUI, App Launch, Network, Energy Log.
- Quy trình: tái hiện vấn đề → ghi → chọn khoảng thời gian có vấn đề → đọc call tree → giả thuyết → sửa → đo lại.
- Ghi số liệu cụ thể (ms, MB, fps) trước khi sửa, nếu không sẽ không biết sửa có tác dụng không.

**Ví dụ (mẫu ghi chép một lần đo)**
```
Vấn đề: cuộn danh sách đơn hàng giật trên iPhone 12
Cách tái hiện: mở tab Đơn hàng, cuộn nhanh 5 giây
Đo bằng: Time Profiler + Hangs, bản Release, máy thật
Trước: 14 hang > 250 ms, hàm nặng nhất DateFormatter.init (38% main thread)
Sau:   0 hang, DateFormatter dùng chung (static let)
```

**Bài tập:** Chọn 3 màn hình trong dự án xuyên suốt, ghi một lần Time Profiler cho mỗi màn khi thao tác bình thường. Tìm 3 hàm tốn thời gian nhất trên main thread của mỗi màn và ghi theo mẫu trên.

### Ngày 2 — Time Profiler chuyên sâu

**Kiến thức**
- Call tree: bật *Separate by Thread*, *Hide System Libraries*, *Invert Call Tree* để thấy hàm lá tốn nhất.
- Lọc theo main thread: mọi thứ chạy trên main quá 16 ms (60 Hz) hoặc 8 ms (120 Hz ProMotion) đều có thể làm rớt khung hình.
- Thủ phạm hay gặp: tạo `DateFormatter`/`NumberFormatter` liên tục, parse JSON trên main, regex trong `body`, sắp xếp mảng lớn mỗi lần render.

**Ví dụ**
```swift
// Chậm: tạo formatter mỗi lần cell hiển thị
func configure(_ order: Order) {
    let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"
    dateLabel.text = f.string(from: order.createdAt)
}

// Nhanh: FormatStyle được cache nội bộ, hoặc formatter dùng chung
func configure(_ order: Order) {
    dateLabel.text = order.createdAt.formatted(.dateTime.day().month().year().hour().minute())
}
```

**Bài tập:** Tạo danh sách 5.000 đơn hàng có ngày, tiền, trạng thái. Cố tình viết cell chậm (formatter mới mỗi lần, ảnh giải mã trên main). Đo, sửa từng điểm, ghi thời gian main thread mỗi lần sửa.

### Ngày 3 — Hang và main thread

**Kiến thức**
- Hang: main thread bị chặn ≥ 250 ms, người dùng thấy app đứng. Instruments → Hangs và Xcode Organizer → Hangs (dữ liệu từ người dùng thật).
- Nguồn: I/O đồng bộ trên main (`Data(contentsOf:)`, đọc file lớn), `DispatchQueue.main.sync`, chờ semaphore, lock bị giữ lâu.
- Thread Performance Checker (Edit Scheme → Diagnostics) báo khi main thread chờ thread có ưu tiên thấp hơn.

**Ví dụ**
```swift
// Hang: đọc file 30 MB trên main
let data = try Data(contentsOf: bigFileURL)

// Không hang: đọc trong task nền rồi quay về
let data = try await Task.detached(priority: .userInitiated) {
    try Data(contentsOf: bigFileURL)
}.value
```

**Bài tập:** Bật Thread Performance Checker và Main Thread Checker cho dự án. Chạy mọi màn hình, sửa mọi cảnh báo. Mở Xcode Organizer (nếu app đã có trên TestFlight/App Store) và đọc báo cáo Hangs.

### Ngày 4 — Hiệu năng SwiftUI

**Kiến thức**
- Instruments → SwiftUI template: đếm số lần `body` được tính, thời gian mỗi view, nguyên nhân cập nhật (bản Xcode mới hiển thị *cause & effect*).
- View cập nhật quá nhiều thường do: đọc model lớn ở view cha, closure tạo mới mỗi lần, `ForEach` id không ổn định, `@Observable` chứa computed property nặng.
- Tách view nhỏ để giới hạn phạm vi cập nhật; tính sẵn dữ liệu trong model.

**Ví dụ**
```swift
// Cả danh sách render lại khi một bộ đếm đổi
struct OrdersScreen: View {
    @Bindable var model: OrdersModel
    var body: some View {
        VStack {
            Text("Còn \(model.secondsLeft) giây")       // đổi mỗi giây
            List(model.orders) { OrderRow(order: $0) }  // bị kéo theo
        }
    }
}

// Tách bộ đếm ra view riêng: chỉ view nhỏ cập nhật
struct CountdownLabel: View {
    let model: OrdersModel
    var body: some View { Text("Còn \(model.secondsLeft) giây") }
}
```

**Bài tập:** Dùng SwiftUI instrument trên màn hình chính của dự án xuyên suốt. Tìm view có số lần cập nhật cao bất thường, sửa, và ghi số lần cập nhật trước/sau khi thao tác 10 giây.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Sửa danh sách giật (dùng màn hình nặng nhất của dự án hoặc danh sách 5.000 đơn ở Ngày 2). Nghiệm thu: không có hang > 100 ms khi cuộn nhanh 10 giây trên máy thật đời cũ nhất bạn có; viết báo cáo 1 trang có ảnh chụp Instruments trước/sau.

---

## Tuần 2 · Bộ nhớ, khởi động và số liệu thật

### Ngày 6 — Allocations và Leaks

**Kiến thức**
- Allocations: bộ nhớ theo loại object; *Mark Generation* trước và sau một thao tác để thấy bộ nhớ tăng mà không giảm (abandoned memory).
- Leaks: object không còn đường tham chiếu nào tới (thường do retain cycle).
- Bộ nhớ tăng dần khi mở/đóng một màn hình nhiều lần = rò rỉ, dù Leaks không báo (cycle vẫn còn được tham chiếu, hoặc cache không giới hạn).

**Ví dụ (quy trình Mark Generation)**
```
1. Mở app, vào màn hình chính → Mark Generation A
2. Mở rồi đóng màn Chi tiết 10 lần → Mark Generation B
3. Generation B phải gần 0. Nếu B có 10 × DetailViewModel → leak.
```

**Bài tập:** Áp dụng Mark Generation cho 3 luồng của dự án (mở/đóng chi tiết, tìm kiếm 20 lần, đăng xuất/đăng nhập). Ghi bộ nhớ tăng mỗi luồng; sửa mọi luồng tăng hơn 1 MB.

### Ngày 7 — Bộ nhớ ảnh

**Kiến thức**
- Bộ nhớ ảnh giải mã = rộng × cao × 4 byte, không phụ thuộc dung lượng file JPEG.
- `UIImage(named:)` cache ảnh trong bộ nhớ hệ thống; `UIImage(contentsOfFile:)` thì không.
- Downsample (Tháng 6, Ngày 7) và `UIImage.preparingThumbnail(of:)` / `byPreparingForDisplay()` để giải mã ngoài main thread.

**Ví dụ**
```swift
// Ảnh 4032×3024 từ camera: ~48 MB khi giải mã
let full = UIImage(data: photoData)

// Hiển thị trong ô 120×120 pt ở @3x: ~0,5 MB
let thumbnail = await full?.byPreparingThumbnail(ofSize: CGSize(width: 360, height: 360))
```

**Bài tập:** Màn hình thư viện ảnh hiển thị 200 ảnh từ camera. Đo bộ nhớ đỉnh khi cuộn hết (Xcode Debug Navigator → Memory). Áp dụng downsample + giải mã nền, mục tiêu giảm ≥ 80% bộ nhớ đỉnh.

### Ngày 8 — Thời gian khởi động

**Kiến thức**
- Cold launch (app chưa có trong bộ nhớ) và warm launch. Mục tiêu khung hình đầu tiên dưới khoảng 400 ms.
- Khởi động chậm do: nhiều dynamic framework, code chạy trong `+load`/static initializer, khởi tạo SDK đồng bộ trong `didFinishLaunching`, tải dữ liệu lớn trước khung hình đầu.
- Hoãn mọi thứ không cần cho khung hình đầu: khởi tạo analytics, tải cấu hình từ xa, dọn cache.

**Ví dụ**
```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    CrashReporter.start()                         // cần sớm để bắt crash khởi động
    Task(priority: .utility) {                    // không chặn khung hình đầu
        await Analytics.configure()
        await RemoteConfig.refresh()
        await CacheJanitor.cleanUpOldFiles()
    }
    return true
}
```

**Bài tập:** Dùng Instruments → App Launch đo cold launch của dự án 5 lần, lấy trung vị. Liệt kê mọi việc chạy trước khung hình đầu, hoãn những việc không cần, đo lại. Mục tiêu giảm ≥ 30%.

### Ngày 9 — MetricKit và số liệu từ người dùng thật

**Kiến thức**
- Máy dev không đại diện cho người dùng. MetricKit gửi báo cáo hằng ngày từ máy người dùng: thời gian khởi động, hang, tốc độ cuộn (hitch rate), bộ nhớ, pin, crash.
- iOS 27 có API MetricKit mới theo phong cách Swift (theo hướng dẫn xem WWDC26); vẫn cần hiểu các nhóm chỉ số giống bản cũ.
- Xcode Organizer hiển thị số liệu tổng hợp theo phiên bản app.

**Ví dụ (API truyền thống, chạy được trên các iOS cũ)**
```swift
import MetricKit

final class MetricsSubscriber: NSObject, MXMetricManagerSubscriber {
    func start() { MXMetricManager.shared.add(self) }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                Logger.metrics.info("Launch histogram: \(launch.histogrammedTimeToFirstDraw)")
            }
            upload(payload.jsonRepresentation())
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        payloads.forEach { upload($0.jsonRepresentation()) }   // hang, crash, disk write
    }

    private func upload(_ json: Data) { /* gửi về server của bạn */ }
}
```

**Bài tập:** Tích hợp MetricKit vào dự án, lưu payload vào file để xem (Xcode → Debug → Simulate MetricKit Payloads). Xem phiên WWDC26 về MetricKit mới và ghi lại khác biệt API so với bản trên.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Giảm thời gian khởi động và bộ nhớ đỉnh của dự án xuyên suốt. Báo cáo có: trung vị cold launch trước/sau (5 lần đo), bộ nhớ đỉnh khi cuộn feed ảnh trước/sau, danh sách thay đổi và tác động của từng thay đổi.

---

## Tuần 3 · Hiệu năng của chính code Swift

### Ngày 11 — Chi phí ẩn trong Swift

**Kiến thức**
- ARC traffic: truyền class qua nhiều lớp gây retain/release liên tục; struct nhỏ không có chi phí này.
- Existential (`any P`) có chi phí cấp phát và dispatch động; generic (`some P`) được specialize. Đo trước khi tối ưu.
- `final class` giúp compiler bỏ dynamic dispatch; Whole Module Optimization (mặc định ở Release) càng giúp nhiều hơn.

**Ví dụ**
```swift
protocol Shape { func area() -> Double }

func totalArea(_ shapes: [any Shape]) -> Double { shapes.reduce(0) { $0 + $1.area() } }
func totalArea<S: Shape>(_ shapes: [S]) -> Double { shapes.reduce(0) { $0 + $1.area() } }
// Đo 1 triệu phần tử: bản generic thường nhanh hơn đáng kể khi mọi phần tử cùng kiểu.
```

**Bài tập:** Viết benchmark (XCTest `measure` hoặc `ContinuousClock`) so sánh 3 phiên bản: `[any Shape]`, `[S]` generic, `enum ShapeKind`. Chạy ở Release. Ghi kết quả và giải thích chênh lệch.

### Ngày 12 — Hiệu năng collection

**Kiến thức**
- `reserveCapacity` khi biết trước số phần tử; tránh `array.insert(_, at: 0)` trong vòng lặp (O(n) mỗi lần).
- `Set`/`Dictionary` cho tra cứu O(1) thay vì `array.contains` O(n) trong vòng lặp (O(n²) tổng).
- `String` trong Swift dùng Unicode: `count` là O(n); dùng `utf8.count` khi chỉ cần số byte.

**Ví dụ**
```swift
// O(n × m)
let visible = allProducts.filter { favoritesArray.contains($0.id) }

// O(n + m)
let favoriteIDs = Set(favoritesArray)
let visible = allProducts.filter { favoriteIDs.contains($0.id) }
```

**Bài tập:** Tìm trong dự án mọi chỗ có `contains`/`first(where:)`/`firstIndex` bên trong vòng lặp hoặc `filter`. Sửa những chỗ chạy trên dữ liệu > 100 phần tử, đo trước/sau với 10.000 phần tử.

### Ngày 13 — Pin và mạng

**Kiến thức**
- Radio di động tốn pin nhất khi bật lên; gom nhiều request nhỏ thành ít request lớn, tránh polling mỗi vài giây.
- `URLSessionConfiguration.background` cho tải lớn; hệ thống tự chọn lúc phù hợp (đang sạc, có Wi-Fi).
- Vị trí: dùng độ chính xác thấp nhất đủ dùng, dừng cập nhật khi không cần. Animation chạy liên tục cũng tốn pin.

**Ví dụ**
```swift
// Polling mỗi 5 giây: radio không bao giờ được nghỉ
// Thay bằng: push notification, WebSocket khi màn hình đang mở, hoặc gom theo phút

let config = URLSessionConfiguration.background(withIdentifier: "com.example.shop.sync")
config.isDiscretionary = true          // cho hệ thống chọn lúc thuận lợi
config.sessionSendsLaunchEvents = true
```

**Bài tập:** Dùng Energy Log (Instruments trên máy thật) đo 10 phút dùng app. Tìm 3 nguồn tốn pin (polling, vị trí, animation). Thay polling trạng thái đơn hàng bằng cách cập nhật khi màn hình đang mở và push khi app ở nền.

### Ngày 14 — Kích thước app

**Kiến thức**
- Kích thước tải về ảnh hưởng tỉ lệ cài đặt, nhất là khi dùng 4G. App Store Connect hiển thị kích thước theo từng thiết bị.
- Nguồn phình: ảnh không nén, font đầy đủ, nhiều SDK, video trong bundle, asset trùng lặp.
- Asset Catalog nén và cắt ảnh theo thiết bị (app thinning); On-Demand Resources hoặc tải sau cho nội dung lớn.

**Ví dụ (đọc báo cáo kích thước)**
```
Xcode → Product → Archive → Distribute App → Development
→ App Thinning: All compatible device variants
→ xuất ra thư mục, mở App Thinning Size Report.txt
(Bitcode đã bị bỏ từ Xcode 14, không còn tuỳ chọn này)
```

**Bài tập:** Tạo App Thinning Size Report cho dự án. Liệt kê 10 file lớn nhất, giảm kích thước tải về ít nhất 15% (nén ảnh sang HEIC/WebP qua Asset Catalog, bỏ font không dùng, bỏ SDK thừa).

### Ngày 15 — Thực hành tuần 3

**Bài tập:** Viết bộ benchmark cho 5 thao tác nặng nhất của dự án (parse feed 1.000 mục, lọc tìm kiếm, tính giỏ hàng lớn, import SwiftData, downsample 50 ảnh) bằng XCTest `measure` với baseline. Cố tình làm chậm một thao tác 20% và xác nhận test báo đỏ.

---

## Tuần 4 · Đo lường liên tục

### Ngày 16 — `os_signpost` và khoảng đo tự định nghĩa

**Kiến thức**
- `OSSignposter` đánh dấu khoảng thời gian của nghiệp vụ ("tải trang chủ", "đặt hàng") để thấy trên timeline của Instruments.
- Kết hợp với Time Profiler: chọn đúng khoảng signpost để xem CPU trong khoảng đó.
- Signpost gần như không tốn chi phí khi không có Instruments ghi.

**Ví dụ**
```swift
import os

let signposter = OSSignposter(subsystem: "com.example.shop", category: .pointsOfInterest)

func loadHome() async throws -> Home {
    let state = signposter.beginInterval("LoadHome", id: signposter.makeSignpostID())
    defer { signposter.endInterval("LoadHome", state) }
    return try await homeService.load()
}
```

**Bài tập:** Thêm signpost cho 5 luồng chính (khởi động đến khung hình đầu có dữ liệu, tải trang chủ, tìm kiếm, mở chi tiết, đặt hàng). Ghi Instruments → Points of Interest và lập bảng thời gian trung vị của mỗi luồng.

### Ngày 17 — Background task

**Kiến thức**
- `BGAppRefreshTask` (vài chục giây, làm mới dữ liệu) và `BGProcessingTask` (lâu hơn, có thể yêu cầu đang sạc).
- Đăng ký identifier trong `Info.plist` (`BGTaskSchedulerPermittedIdentifiers`), đăng ký handler khi khởi động, lên lịch khi vào background.
- Hệ thống quyết định lúc chạy dựa trên thói quen dùng app; luôn xử lý `expirationHandler`.

**Ví dụ**
```swift
// SwiftUI
WindowGroup { RootView() }
    .backgroundTask(.appRefresh("com.example.shop.refresh")) {
        await FeedCache.shared.refresh()
        scheduleNextRefresh()
    }

func scheduleNextRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.shop.refresh")
    request.earliestBeginDate = .now.addingTimeInterval(60 * 60)
    try? BGTaskScheduler.shared.submit(request)
}
```

**Bài tập:** Thêm làm mới nền cho feed: mở app buổi sáng đã có dữ liệu mới. Kiểm tra bằng lệnh debugger `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.example.shop.refresh"]`. Xử lý trường hợp hết thời gian giữa chừng.

### Ngày 18 — Ngân sách hiệu năng và phát hiện hồi quy

**Kiến thức**
- Ngân sách: con số cụ thể team cam kết giữ (cold launch < 500 ms trên iPhone 12, bộ nhớ feed < 150 MB, hitch rate < 5 ms/s).
- Chạy benchmark và `measure` với baseline trên CI; PR làm chậm quá ngưỡng thì báo.
- Theo dõi số liệu MetricKit/Organizer theo từng phiên bản phát hành.

**Ví dụ**
```swift
final class LaunchPerformanceTests: XCTestCase {
    func testColdLaunch() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
```

**Bài tập:** Viết tài liệu "Ngân sách hiệu năng" 1 trang cho dự án với 5 chỉ số, giá trị hiện tại và ngưỡng. Thêm test `XCTApplicationLaunchMetric` và benchmark vào pipeline (chuẩn bị cho Tháng 9).

### Ngày 19 — Phân tích một sự cố hiệu năng

**Kiến thức**
- Khi người dùng báo "app chậm": thu thập thiết bị, phiên bản iOS, thao tác; xem Organizer; tái hiện trên máy tương tự; đo; sửa; theo dõi sau phát hành.
- Phân biệt chậm do mạng (server, kết nối) và chậm do app (CPU, main thread). Network instrument và log thời gian request giúp phân biệt.

**Ví dụ (khung phân tích)**
```
Triệu chứng → Phạm vi (máy nào, bản nào, bao nhiêu % người dùng)
→ Tái hiện → Đo (công cụ, số liệu) → Nguyên nhân gốc
→ Sửa → Kiểm chứng (số liệu sau) → Phòng ngừa (test, ngân sách, cảnh báo)
```

**Bài tập:** Viết một bản phân tích sự cố hiệu năng theo khung trên cho một vấn đề thật bạn đã gặp (hoặc vấn đề đã sửa trong tháng này). Tối đa 1 trang, có số liệu.

### Ngày 20 — Ôn tập và kiểm tra tháng 8

**Bài tập:** Hoàn thiện báo cáo hiệu năng của dự án xuyên suốt: cold launch, hitch khi cuộn, bộ nhớ đỉnh, kích thước tải về, mỗi chỉ số có số liệu trước/sau và ảnh chụp Instruments. Làm lại câu 15 của bài trắc nghiệm.

**Tự đánh giá:** giải thích không nhìn tài liệu: vì sao phải đo ở Release trên máy thật; Mark Generation dùng để làm gì; công thức bộ nhớ ảnh giải mã; 3 cách giảm thời gian khởi động; signpost giúp gì.
