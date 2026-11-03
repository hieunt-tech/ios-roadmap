# Tháng 10 — Nền tảng iOS 27

**Mục tiêu:** tích hợp app sâu vào hệ thống: App Intents (Siri, Shortcuts, Spotlight), widget, Live Activity, Foundation Models (AI trên máy), Liquid Glass, giao diện co giãn tự do.
**Đầu ra cuối tháng:** dự án xuyên suốt có 1 App Intent dùng được qua Siri/Shortcuts, 1 widget tương tác, 1 tính năng dùng Foundation Models (phần đầu của Mốc **M4**).

API trong tháng này thay đổi theo từng năm. Trước mỗi buổi, đối chiếu với tài liệu Apple và video WWDC26 tương ứng; ví dụ ở đây viết theo API đã có từ iOS 26.

[← Tháng 9](thang-09.md) · [Mục lục](../../README.md) · [Tháng 11 →](thang-11.md)

---

## Tuần 1 · App Intents và widget

### Ngày 1 — App Intents cơ bản

**Kiến thức**
- `AppIntent` mô tả một hành động của app mà hệ thống gọi được: Shortcuts, Siri, Spotlight, nút Action, widget.
- `static let title`, `@Parameter`, `func perform() async throws -> some IntentResult`.
- Ở các bản iOS mới, App Intents là cách chính để Siri hiểu và thao tác trong app bên thứ ba; SiriKit cũ dần nhường chỗ.

**Ví dụ**
```swift
import AppIntents

struct ReorderLastIntent: AppIntent {
    static let title: LocalizedStringResource = "Đặt lại đơn gần nhất"
    static let description = IntentDescription("Đặt lại đúng các món của đơn hàng gần nhất.")

    @Dependency var orders: OrderService

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let order = try await orders.reorderLast()
        return .result(dialog: "Đã đặt lại \(order.itemCount) món, giao lúc \(order.eta.formatted(date: .omitted, time: .shortened)).")
    }
}
```

**Bài tập:** Viết 2 intent cho dự án xuyên suốt (ví dụ "Bắt đầu buổi tập", "Ghi lại cân nặng" có tham số số). Đăng ký dependency bằng `AppDependencyManager.shared.add { ... }` khi khởi động. Chạy thử trong app Shortcuts.

### Ngày 2 — AppEntity và EntityQuery

**Kiến thức**
- `AppEntity` cho hệ thống biết "đồ vật" trong app (món ăn, bài tập, ghi chú) để dùng làm tham số và hiển thị.
- `EntityQuery` trả entity theo id và gợi ý; `EntityStringQuery` cho tìm kiếm bằng chữ.
- `displayRepresentation` quyết định cách entity hiện trong Shortcuts và Siri.

**Ví dụ**
```swift
struct DishEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Món ăn"
    static let defaultQuery = DishQuery()

    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct DishQuery: EntityStringQuery {
    @Dependency var menu: MenuService
    func entities(for identifiers: [UUID]) async throws -> [DishEntity] { try await menu.dishes(ids: identifiers) }
    func entities(matching string: String) async throws -> [DishEntity] { try await menu.search(string) }
    func suggestedEntities() async throws -> [DishEntity] { try await menu.favorites() }
}

struct OrderDishIntent: AppIntent {
    static let title: LocalizedStringResource = "Đặt món"
    @Parameter(title: "Món") var dish: DishEntity
    @Parameter(title: "Số lượng", default: 1) var quantity: Int
    func perform() async throws -> some IntentResult { .result() }
}
```

**Bài tập:** Tạo `ExerciseEntity` và query tìm theo tên cho dự án xuyên suốt. Viết intent "Thêm bài tập vào buổi hôm nay" nhận entity làm tham số. Kiểm tra Shortcuts hiển thị danh sách gợi ý và tìm kiếm được.

### Ngày 3 — App Shortcuts và Siri

**Kiến thức**
- `AppShortcutsProvider` khai báo câu lệnh sẵn có, dùng ngay sau khi cài app mà người dùng không cần tự tạo shortcut.
- Câu lệnh phải chứa `\(.applicationName)`; tham số entity có thể nằm trong câu.
- Để Siri mới khám phá và thao tác sâu trong app, Apple khuyến nghị khai báo entity, intent theo schema có sẵn của hệ thống và gắn annotation cho view. Xem phiên WWDC26 về App Intents để biết các schema hiện có.

**Ví dụ**
```swift
struct ShopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ReorderLastIntent(),
                    phrases: ["Đặt lại đơn trên \(.applicationName)",
                              "Reorder on \(.applicationName)"],
                    shortTitle: "Đặt lại đơn",
                    systemImageName: "arrow.clockwise")
    }
}
```

**Bài tập:** Khai báo 3 App Shortcut cho dự án xuyên suốt bằng tiếng Việt và tiếng Anh. Thử gọi bằng Siri và từ Spotlight. Xem phiên WWDC26 về App Intents, ghi lại schema nào phù hợp với app của bạn và kế hoạch áp dụng.

### Ngày 4 — Widget tương tác

**Kiến thức**
- WidgetKit: `TimelineProvider` cung cấp các mốc nội dung; widget là view SwiftUI tĩnh được hệ thống chụp lại.
- iOS 17+: `Button(intent:)` và `Toggle(isOn:intent:)` trong widget chạy App Intent mà không mở app.
- Dữ liệu chia sẻ với app qua App Group (Tháng 6, Ngày 17); làm mới bằng `WidgetCenter.shared.reloadTimelines(ofKind:)`.

**Ví dụ**
```swift
struct WaterEntry: TimelineEntry { let date: Date; let glasses: Int }

struct WaterWidgetView: View {
    let entry: WaterEntry
    var body: some View {
        VStack {
            Text("\(entry.glasses)/8 cốc").font(.title2.bold())
            Button(intent: LogWaterIntent()) { Label("Thêm cốc", systemImage: "plus") }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Ghi một cốc nước"
    func perform() async throws -> some IntentResult {
        SharedStore.incrementWater()           // ghi vào App Group
        return .result()
    }
}
```

**Bài tập:** Làm widget cỡ nhỏ và vừa cho dự án xuyên suốt (ví dụ "Buổi tập hôm nay" có nút đánh dấu hoàn thành). Nút trong widget chạy intent, app mở ra thấy trạng thái đã cập nhật.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Gói "tích hợp hệ thống" cho dự án: 3 intent, 1 entity có query, 3 App Shortcut, 1 widget tương tác, intent hiện trong Spotlight. Viết test cho logic `perform()` của mỗi intent bằng cách inject dependency giả.

---

## Tuần 2 · Live Activity và Foundation Models

### Ngày 6 — Live Activity

**Kiến thức**
- ActivityKit: hiển thị trạng thái đang diễn ra trên màn hình khoá và Dynamic Island (đơn giao hàng, buổi tập, trận đấu).
- `ActivityAttributes` (dữ liệu cố định) + `ContentState` (dữ liệu thay đổi). Cập nhật từ app hoặc qua push từ server.
- Kết thúc activity khi xong, nếu không nó tự hết hạn sau vài giờ.

**Ví dụ**
```swift
struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var status: String; var eta: Date }
    var orderID: String
}

let activity = try Activity.request(
    attributes: DeliveryAttributes(orderID: "A123"),
    content: .init(state: .init(status: "Đang chuẩn bị", eta: .now + 1800), staleDate: nil)
)
await activity.update(.init(state: .init(status: "Tài xế đang tới", eta: .now + 600), staleDate: nil))
```

**Bài tập:** Làm Live Activity "Buổi tập đang diễn ra" cho dự án: hiện bài tập hiện tại, số hiệp, đồng hồ đếm (`Text(timerInterval:)`), nút "Hiệp tiếp theo" chạy App Intent. Có giao diện Dynamic Island cả dạng gọn và mở rộng.

### Ngày 7 — Foundation Models: mô hình ngôn ngữ trên máy

**Kiến thức**
- Framework Foundation Models cho app gọi mô hình ngôn ngữ chạy trên máy: miễn phí, chạy offline, dữ liệu không rời máy.
- Luôn kiểm tra `SystemLanguageModel.default.availability`: máy không hỗ trợ, người dùng tắt Apple Intelligence, hoặc mô hình chưa tải xong.
- `LanguageModelSession` giữ ngữ cảnh hội thoại; `instructions` định hướng vai trò. Mô hình nhỏ: hợp với tóm tắt, phân loại, trích xuất; không hợp với kiến thức thế giới chính xác.

**Ví dụ**
```swift
import FoundationModels

func summarize(_ note: String) async throws -> String? {
    guard case .available = SystemLanguageModel.default.availability else { return nil }
    let session = LanguageModelSession(instructions: """
        Bạn tóm tắt ghi chú tập luyện bằng tiếng Việt, tối đa 2 câu, không thêm thông tin mới.
        """)
    let response = try await session.respond(to: note)
    return response.content
}
```

**Bài tập:** Thêm nút "Tóm tắt" cho ghi chú buổi tập. Xử lý cả 3 trường hợp: mô hình sẵn sàng, không hỗ trợ (ẩn nút), đang tải (hiện trạng thái chờ). Thử 20 ghi chú khác nhau và ghi lại các câu trả lời sai lệch.

### Ngày 8 — Sinh dữ liệu có cấu trúc và tool calling

**Kiến thức**
- `@Generable` + `@Guide` cho mô hình sinh thẳng ra struct Swift thay vì văn bản tự do; không cần tự parse JSON.
- `Tool`: cho mô hình gọi hàm của app (tra cứu dữ liệu cục bộ) để câu trả lời dựa trên dữ liệu thật.
- Stream kết quả từng phần (`streamResponse`) để UI hiện dần.

**Ví dụ**
```swift
@Generable
struct WorkoutPlan {
    @Guide(description: "Tên buổi tập ngắn gọn")
    var title: String
    @Guide(description: "Danh sách bài tập", .count(3...6))
    var exercises: [PlannedExercise]
}

@Generable
struct PlannedExercise {
    var name: String
    @Guide(description: "Số hiệp", .range(1...6)) var sets: Int
    @Guide(description: "Số lần mỗi hiệp", .range(3...20)) var reps: Int
}

let session = LanguageModelSession()
let plan = try await session.respond(
    to: "Tạo buổi tập thân trên 45 phút cho người mới, không có tạ đòn.",
    generating: WorkoutPlan.self
).content
```

**Bài tập:** Viết tính năng "Gợi ý buổi tập" sinh `WorkoutPlan` theo mục tiêu và thiết bị người dùng chọn. Thêm một `Tool` tra cứu danh sách bài tập có trong app để mô hình chỉ gợi ý bài có thật.

### Ngày 9 — Đánh giá và an toàn tính năng AI

**Kiến thức**
- Đầu ra của mô hình không tất định: cần bộ test đánh giá (eval) với nhiều đầu vào và tiêu chí chấm, không chỉ thử vài lần bằng tay.
- iOS 27 bổ sung Evaluations framework để đo chất lượng tính năng AI bằng Swift và tích hợp với Swift Testing; xem phiên WWDC26 tương ứng.
- Luôn có đường lui: tính năng vẫn dùng được khi mô hình từ chối, sai, hoặc không có. Hiển thị rõ nội dung do AI tạo; cho người dùng sửa.

**Ví dụ (eval đơn giản tự viết, không phụ thuộc framework mới)**
```swift
struct SummaryCase { let input: String; let mustMention: [String]; let maxSentences: Int }

@Test(arguments: SummaryCases.all)
func summaryQuality(_ c: SummaryCase) async throws {
    let summary = try #require(try await summarize(c.input))
    for keyword in c.mustMention { #expect(summary.localizedCaseInsensitiveContains(keyword)) }
    #expect(summary.split(whereSeparator: { ".!?".contains($0) }).count <= c.maxSentences)
}
```

**Bài tập:** Tạo bộ 30 trường hợp đánh giá cho tính năng tóm tắt và gợi ý buổi tập (có trường hợp khó: ghi chú rỗng, tiếng Anh lẫn tiếng Việt, nội dung không liên quan). Đo tỉ lệ đạt. Đọc tài liệu Evaluations framework và chuyển bộ eval sang framework đó nếu môi trường của bạn hỗ trợ iOS 27.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Hoàn thiện một tính năng AI cho dự án xuyên suốt (Mốc M4 phần 1): sinh dữ liệu có cấu trúc, có tool tra dữ liệu thật, có đường lui khi không khả dụng, có bộ eval ≥ 30 trường hợp với tỉ lệ đạt ≥ 80%, có nhãn "Gợi ý bởi AI" và cho phép sửa.

---

## Tuần 3 · Giao diện và tương tác hệ thống

### Ngày 11 — Liquid Glass

**Kiến thức**
- Thanh điều hướng, tab bar, toolbar, sheet của hệ thống tự dùng Liquid Glass khi build bằng SDK mới. Ở các bản 27, app không còn tuỳ chọn tắt, và người dùng có thanh trượt chỉnh độ trong.
- View tuỳ biến: `.glassEffect(.regular, in: .capsule)`, `.glassEffect(.regular.interactive())`; nhóm nhiều phần tử trong `GlassEffectContainer` để chúng hoà vào nhau khi gần.
- Glass dành cho lớp điều khiển nổi trên nội dung; không phủ glass lên nội dung chính, không chồng glass lên glass.

**Ví dụ**
```swift
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        Button("Bắt đầu", systemImage: "play.fill") { start() }
            .padding()
            .glassEffect(.regular.interactive())
        Button("Lịch sử", systemImage: "clock") { showHistory() }
            .padding()
            .glassEffect(.regular.interactive())
    }
}
```

**Bài tập:** Rà toàn bộ dự án trên SDK mới: gỡ nền tuỳ biến của thanh điều hướng/tab bar đang che hiệu ứng hệ thống, chuyển thanh công cụ nổi sang `GlassEffectContainer`. Kiểm tra độ đọc được ở cả 2 đầu thanh trượt độ trong và với Reduce Transparency bật.

### Ngày 12 — Giao diện co giãn tự do

**Kiến thức**
- Ở các bản 27, app iPhone phải co giãn được tự do (phục vụ iPhone Mirroring trên Mac và thiết bị có màn hình gập). Không được giả định kích thước cố định theo đời máy.
- Dùng size class, `ViewThatFits`, `NavigationSplitView` tự chuyển giữa một cột và nhiều cột.
- Device Hub trong Xcode 27 cho phép đổi kích thước màn hình simulator để thử.

**Ví dụ**
```swift
struct RootView: View {
    @State private var selection: Workout.ID?
    var body: some View {
        NavigationSplitView {
            WorkoutList(selection: $selection)
        } detail: {
            if let selection { WorkoutDetail(id: selection) }
            else { ContentUnavailableView("Chọn một buổi tập", systemImage: "figure.run") }
        }
    }
}
```

**Bài tập:** Kéo cửa sổ simulator (Device Hub) từ rất hẹp tới rất rộng cho mọi màn hình chính của dự án. Sửa mọi chỗ vỡ layout, chữ bị cắt, nút ra ngoài màn hình. Chuyển màn hình danh sách – chi tiết sang `NavigationSplitView`.

### Ngày 13 — Push notification

**Kiến thức**
- APNs: app xin quyền, nhận device token, gửi lên server; server gửi push qua APNs bằng khoá `.p8`.
- Notification Service Extension: sửa nội dung trước khi hiện (tải ảnh đính kèm, giải mã). Notification Content Extension: giao diện tuỳ biến khi nhấn giữ.
- Xin quyền đúng lúc (sau khi người dùng hiểu lợi ích), dùng provisional authorization để gửi lặng lẽ trước.

**Ví dụ**
```swift
let center = UNUserNotificationCenter.current()
let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound, .provisional])
if granted { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } }

// Thử push trên simulator: kéo file .apns vào simulator, hoặc
// xcrun simctl push booted com.example.shop payload.apns
```

**Bài tập:** Thêm push "Đến giờ tập" có nút hành động (Bắt đầu / Nhắc lại sau 30 phút) và ảnh đính kèm tải trong Service Extension. Mở push phải đi thẳng tới màn hình đúng qua deep link. Thử bằng `simctl push`.

### Ngày 14 — StoreKit 2

**Kiến thức**
- `Product.products(for:)`, `product.purchase()`, `Transaction.updates` (luôn lắng nghe từ lúc khởi động), `Transaction.currentEntitlements`.
- Kiểm tra trạng thái giao dịch đã xác minh (`VerificationResult.verified`); gọi `transaction.finish()` sau khi cấp quyền.
- StoreKit Configuration file để thử mua trong Xcode không cần App Store Connect; `SubscriptionStoreView` dựng màn hình đăng ký có sẵn.

**Ví dụ**
```swift
@MainActor @Observable
final class Store {
    private(set) var isPro = false

    func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }

    func refreshEntitlements() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == "pro.monthly", t.revocationDate == nil { pro = true }
        }
        isPro = pro
    }
}
```

**Bài tập:** Thêm gói "Pro" theo tháng/năm cho dự án bằng `SubscriptionStoreView` và StoreKit Configuration file. Thử các trường hợp: mua thành công, huỷ, hết hạn, hoàn tiền (Transaction Manager trong Xcode), khôi phục giao dịch trên máy khác.

### Ngày 15 — Thực hành tuần 3

**Bài tập:** Gói "trải nghiệm hệ thống" cho dự án: Liquid Glass đúng chuẩn, co giãn tự do, push có deep link, Live Activity cho buổi tập, gói Pro. Quay video demo 3 phút đi qua toàn bộ.

---

## Tuần 4 · Quyền riêng tư, liên kết và hoàn thiện

### Ngày 16 — Quyền truy cập và quyền riêng tư

**Kiến thức**
- Chỉ xin quyền khi cần, ngay trước tính năng dùng nó; giải thích lợi ích trước khi hệ thống hiện hộp thoại.
- Ưu tiên API không cần quyền: `PhotosPicker` (không cần quyền thư viện ảnh), vị trí gần đúng, chọn danh bạ bằng picker.
- Người dùng từ chối: app vẫn dùng được, có nút mở Cài đặt khi họ đổi ý.

**Ví dụ**
```swift
@State private var selection: [PhotosPickerItem] = []

PhotosPicker(selection: $selection, maxSelectionCount: 4, matching: .images) {
    Label("Thêm ảnh tiến độ", systemImage: "photo.on.rectangle")
}
// Không cần NSPhotoLibraryUsageDescription cho picker này
```

**Bài tập:** Rà mọi quyền dự án đang xin. Bỏ những quyền có thể thay bằng picker. Với mỗi quyền còn lại, thêm màn giải thích trước khi xin và xử lý đầy đủ trạng thái từ chối/hạn chế.

### Ngày 17 — Universal Link

**Kiến thức**
- Universal Link: link `https://` mở thẳng app nếu đã cài, mở web nếu chưa. Cần file `apple-app-site-association` trên domain và entitlement *Associated Domains*.
- Xử lý trong `.onOpenURL` (SwiftUI) hoặc `scene(_:continue:)`; dùng chung bộ phân tích route với custom scheme (Tháng 3, Ngày 11).
- Kiểm tra bằng cách dán link vào Notes và nhấn giữ; không gõ trực tiếp vào Safari.

**Ví dụ (`apple-app-site-association`)**
```json
{
  "applinks": {
    "details": [{
      "appIDs": ["TEAMID.com.example.fit"],
      "components": [
        { "/": "/workout/*", "comment": "Mở chi tiết buổi tập" },
        { "/": "/invite/*" }
      ]
    }]
  }
}
```

**Bài tập:** Cấu hình Universal Link cho `/workout/<id>` và `/invite/<code>` (dùng domain thử như GitHub Pages nếu chưa có). Viết test cho bộ phân tích URL. Xử lý link tới buổi tập đã bị xoá.

### Ngày 18 — Đồng bộ nền và dữ liệu sức khoẻ

**Kiến thức**
- Với app tập luyện: HealthKit đọc/ghi dữ liệu sức khoẻ (cần quyền chi tiết theo từng loại dữ liệu), `HKObserverQuery` + background delivery để nhận cập nhật.
- Dữ liệu sức khoẻ là dữ liệu nhạy cảm: không gửi lên server nếu không cần, nêu rõ trong privacy manifest và nhãn quyền riêng tư.
- Kết hợp với background task (Tháng 8, Ngày 17) để đồng bộ.

**Ví dụ**
```swift
import HealthKit

let store = HKHealthStore()
let workoutType = HKObjectType.workoutType()
try await store.requestAuthorization(toShare: [workoutType], read: [workoutType])
```

**Bài tập:** Ghi buổi tập của dự án vào HealthKit sau khi hoàn thành và đọc số bước chân hôm nay để hiển thị. Xử lý máy không có HealthKit (iPad cũ) và người dùng chỉ cấp một phần quyền. Nếu app của bạn không phải app sức khoẻ, thay bằng tích hợp Calendar (EventKit) theo cùng yêu cầu.

### Ngày 19 — Accessibility nâng cao

**Kiến thức**
- Rotor tuỳ biến (`.accessibilityRotor`) để VoiceOver nhảy nhanh giữa các mục quan trọng.
- `.accessibilityRepresentation` cho control tuỳ biến (thanh trượt tự vẽ) hành xử như control chuẩn.
- Audio Graph cho biểu đồ (`AXChartDescriptor`), Voice Control (nhãn đọc được bằng giọng nói), chế độ Assistive Access.

**Ví dụ**
```swift
ScrollView {
    LazyVStack { ForEach(workouts) { WorkoutRow(workout: $0) } }
}
.accessibilityRotor("Buổi tập đã hoàn thành") {
    ForEach(workouts.filter(\.isCompleted)) { workout in
        AccessibilityRotorEntry(workout.title, id: workout.id)
    }
}
```

**Bài tập:** Thêm rotor "Kỷ lục cá nhân" và Audio Graph cho biểu đồ tiến độ tuần. Làm cho thanh chọn cường độ tự vẽ hoạt động như `Slider` với VoiceOver. Kiểm tra lại bằng Voice Control: mọi nút gọi được bằng tên.

### Ngày 20 — Ôn tập và kiểm tra tháng 10

**Bài tập:** Viết trang "Tích hợp hệ thống" trong README dự án: mỗi tích hợp (Intent, Widget, Live Activity, AI, Push, StoreKit, Universal Link) một đoạn mô tả, ảnh chụp, và giới hạn đã biết. Đánh dấu hoàn thành phần đầu Mốc M4.

**Tự đánh giá:** giải thích không nhìn tài liệu: vì sao App Intents quan trọng với Siri; widget chạy code thế nào khi app không mở; 3 việc phải làm khi dùng mô hình AI trên máy (kiểm tra khả dụng, eval, đường lui); quy tắc dùng Liquid Glass.
