# Tháng 5 — Kiến trúc và modularization

**Mục tiêu:** chọn kiến trúc có lý do, tổ chức codebase để người khác mở rộng được, tách module bằng Swift Package.
**Đầu ra cuối tháng:** dự án xuyên suốt được tách thành ít nhất 3 package (Core, DesignSystem, một Feature), có 1 ADR giải thích kiến trúc.

[← Tháng 4](thang-04.md) · [Mục lục](../../README.md) · [Tháng 6 →](thang-06.md)

---

## Tuần 1 · Nguyên lý và các mẫu cơ bản

### Ngày 1 — SOLID trong iOS

**Kiến thức**
- **S**ingle responsibility: Massive View Controller là vi phạm kinh điển (UI + mạng + parse + điều hướng).
- **O**pen/closed và **L**iskov: mở rộng bằng protocol mới thay vì sửa `switch` khắp nơi.
- **I**nterface segregation: protocol nhỏ (`ProductFetching`) thay vì một `APIService` 40 hàm.
- **D**ependency inversion: ViewModel phụ thuộc protocol, không phụ thuộc `URLSession`.

**Ví dụ**
```swift
// Thay vì một protocol khổng lồ
protocol ProductFetching: Sendable { func products(page: Int) async throws -> [Product] }
protocol CartWriting: Sendable { func add(_ id: Product.ID, quantity: Int) async throws }

@MainActor @Observable
final class ProductListViewModel {
    private let fetcher: any ProductFetching
    private let cart: any CartWriting
    init(fetcher: any ProductFetching, cart: any CartWriting) {
        self.fetcher = fetcher; self.cart = cart
    }
}
```

**Bài tập:** Chọn ViewController dài nhất trong dự án của bạn. Liệt kê mọi trách nhiệm của nó (mỗi trách nhiệm một dòng), nhóm lại, và vẽ sơ đồ các type mới sau khi tách. Chưa cần viết code.

### Ngày 2 — MVC, MVVM, và khi nào dùng cái nào

**Kiến thức**
- MVC của Apple: Controller dễ phình to. Vẫn hợp với màn hình đơn giản.
- MVVM: ViewModel giữ state + logic trình bày, không import UIKit/SwiftUI, test được không cần UI.
- ViewModel tốt: state là dữ liệu đã sẵn để hiển thị (chuỗi đã format), nhận *ý định* người dùng (`didTapBuy()`), không nhận `UIButton`.

**Ví dụ**
```swift
@MainActor @Observable
final class OrderSummaryViewModel {
    private(set) var totalText = ""
    private(set) var canCheckout = false

    func update(items: [CartItem]) {
        let total = items.reduce(Decimal(0)) { $0 + $1.price * Decimal($1.quantity) }
        totalText = total.formatted(.currency(code: "VND"))
        canCheckout = !items.isEmpty && total >= 50_000   // đơn tối thiểu
    }
}
```

**Bài tập:** Viết `OrderSummaryViewModel` đầy đủ: phí giao hàng theo khoảng cách, mã giảm giá phần trăm và cố định, đơn tối thiểu. Viết 10 test cho ViewModel mà không tạo view nào.

### Ngày 3 — Dependency injection không cần framework

**Kiến thức**
- Initializer injection là mặc định: dependency rõ ràng, không thể quên.
- Tránh singleton gọi thẳng (`APIClient.shared`) trong ViewModel; nếu phải dùng thì inject vào với giá trị mặc định.
- Dùng closure làm dependency nhỏ: `now: () -> Date`, `uuid: () -> UUID` để test kiểm soát được thời gian và id.

**Ví dụ**
```swift
struct OrderFactory {
    var now: @Sendable () -> Date = { .now }
    var makeID: @Sendable () -> UUID = { UUID() }

    func makeOrder(items: [CartItem]) -> Order {
        Order(id: makeID(), createdAt: now(), items: items)
    }
}

// Trong test
let factory = OrderFactory(now: { Date(timeIntervalSince1970: 0) },
                           makeID: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })
```

**Bài tập:** Tìm 5 chỗ dùng `Date()`, `UUID()`, `UserDefaults.standard` hoặc `.shared` trực tiếp trong logic nghiệp vụ. Inject chúng và viết test cho một logic phụ thuộc thời gian (ví dụ: "khuyến mãi giờ vàng 11h–13h").

### Ngày 4 — Composition root và DI trong SwiftUI

**Kiến thức**
- Composition root: một chỗ duy nhất (thường là `App` hoặc `SceneDelegate`) tạo mọi dependency thật và nối chúng lại.
- SwiftUI: truyền dependency qua init cho màn hình chính; dùng `@Environment` với `EnvironmentValues` tuỳ chỉnh (`@Entry`, iOS 18) cho dependency dùng chung nhiều tầng.
- Tạo bản "Preview" và "Test" của container để preview không gọi mạng.

**Ví dụ**
```swift
struct AppDependencies: Sendable {
    var products: any ProductFetching
    var cart: any CartWriting

    static let live = AppDependencies(products: LiveProductAPI(), cart: LiveCartAPI())
    static let preview = AppDependencies(products: StubProducts(), cart: NoopCart())
}

extension EnvironmentValues {
    @Entry var dependencies: AppDependencies = .live
}

@main
struct ShopApp: App {
    var body: some Scene {
        WindowGroup { RootView().environment(\.dependencies, .live) }
    }
}
```

**Bài tập:** Tạo `AppDependencies` cho dự án xuyên suốt với 3 bản: live, preview, test. Mọi `#Preview` phải chạy được khi tắt mạng. Ghi lại dependency nào cần thread-safe (`Sendable`) và vì sao.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Refactor Massive View Controller đã phân tích ở Ngày 1 theo MVVM + DI. Yêu cầu: VC dưới 150 dòng, ViewModel không import UIKit, có ít nhất 8 test cho ViewModel, hành vi người dùng thấy không đổi (so sánh video trước/sau).

---

## Tuần 2 · Điều hướng, luồng dữ liệu một chiều và Clean Architecture

### Ngày 6 — Router/Coordinator trong SwiftUI

**Kiến thức**
- Gom logic điều hướng vào một `Router` giữ `path`; màn hình chỉ gọi `router.show(.detail(id))`.
- Mỗi tab có router riêng; deep link đi qua router.
- Router là `@Observable @MainActor`, test được: "bấm Mua khi chưa đăng nhập → path chứa `.login`".

**Ví dụ**
```swift
@MainActor @Observable
final class ShopRouter {
    enum Route: Hashable { case product(Product.ID), cart, login, checkout }
    var path: [Route] = []
    var isLoggedIn = false

    func show(_ route: Route) { path.append(route) }
    func checkout() { path.append(isLoggedIn ? .checkout : .login) }
    func popToRoot() { path.removeAll() }
}
```

**Bài tập:** Viết `ShopRouter` cho 3 tab (Trang chủ, Tìm kiếm, Tài khoản), mỗi tab một stack. Deep link `shop://product/42` mở đúng tab Trang chủ và push sản phẩm. Viết 6 test cho router.

### Ngày 7 — Luồng dữ liệu một chiều (reducer)

**Kiến thức**
- State duy nhất + Action + Reducer thuần `(inout State, Action) -> Effect`. Ý tưởng cốt lõi của TCA, Redux.
- Ưu điểm: dễ test, dễ debug (log mọi action), dễ tái hiện bug. Nhược điểm: nhiều code mẫu.
- Side effect (gọi mạng) tách khỏi reducer, trả về như một giá trị mô tả việc cần làm.

**Ví dụ**
```swift
struct CounterState: Equatable { var count = 0; var isLoadingFact = false; var fact: String? }
enum CounterAction { case increment, decrement, factTapped, factLoaded(String) }
enum Effect { case none, loadFact(Int) }

func reduce(_ state: inout CounterState, _ action: CounterAction) -> Effect {
    switch action {
    case .increment: state.count += 1; return .none
    case .decrement: state.count -= 1; return .none
    case .factTapped: state.isLoadingFact = true; return .loadFact(state.count)
    case .factLoaded(let fact): state.isLoadingFact = false; state.fact = fact; return .none
    }
}
```

**Bài tập:** Viết `Store<State, Action>` nhỏ (`@Observable @MainActor`) chạy reducer và thực thi effect bằng `Task`. Áp dụng cho màn hình giỏ hàng. Viết test chỉ gọi `reduce` cho 8 tình huống, không cần store.

### Ngày 8 — Clean Architecture: tầng và use case

**Kiến thức**
- Tầng: **Presentation** (View, ViewModel) → **Domain** (Entity, Use case, protocol Repository) → **Data** (API, cache, DTO). Phụ thuộc chỉ hướng vào Domain.
- Use case gói một hành động nghiệp vụ (`PlaceOrder`), tái sử dụng giữa nhiều màn hình.
- Không áp dụng máy móc: app nhỏ dùng đủ 3 tầng sẽ thừa. Use case chỉ đáng tạo khi có logic thật.

**Ví dụ**
```swift
// Domain
protocol OrderRepository: Sendable { func place(_ order: Order) async throws -> Order.ID }

struct PlaceOrderUseCase: Sendable {
    let repository: any OrderRepository
    let now: @Sendable () -> Date

    func callAsFunction(_ cart: Cart) async throws -> Order.ID {
        guard !cart.items.isEmpty else { throw OrderError.emptyCart }
        guard cart.subtotal >= 50_000 else { throw OrderError.belowMinimum }
        return try await repository.place(Order(cart: cart, placedAt: now()))
    }
}
```

**Bài tập:** Vẽ sơ đồ tầng cho tính năng Đặt hàng của dự án bạn. Viết `PlaceOrderUseCase` có quy tắc: giờ mở cửa, đơn tối thiểu, món hết hàng. DTO từ API (`OrderDTO`) phải được chuyển sang Entity ở tầng Data, không lọt lên View.

### Ngày 9 — Mô hình hoá lỗi xuyên tầng

**Kiến thức**
- Mỗi tầng có lỗi của riêng nó: Data (`URLError`, decode), Domain (`OrderError.belowMinimum`), Presentation (thông báo cho người dùng).
- Ánh xạ lỗi ở ranh giới tầng, không để `URLError` lên tới View.
- Phân biệt lỗi người dùng sửa được (nhập sai), lỗi thử lại được (mạng), lỗi phải báo hỗ trợ (5xx lạ).

**Ví dụ**
```swift
enum UserFacingError: Equatable {
    case fixable(message: String)
    case retryable(message: String)
    case contactSupport(code: String)
}

extension UserFacingError {
    init(_ error: any Error) {
        switch error {
        case OrderError.belowMinimum: self = .fixable(message: "Đơn tối thiểu 50.000đ")
        case let e as URLError where e.code == .notConnectedToInternet:
            self = .retryable(message: "Không có kết nối mạng")
        default: self = .contactSupport(code: String(describing: type(of: error)))
        }
    }
}
```

**Bài tập:** Viết bảng ánh xạ cho mọi lỗi có thể xảy ra trong luồng đặt hàng sang 3 loại trên, kèm thông báo tiếng Việt và hành động UI (nút Thử lại, nút Gọi hỗ trợ). Cài đặt và test.

### Ngày 10 — Thực hành tuần 2: viết ADR

**Bài tập:** Viết một ADR (Architecture Decision Record) cho dự án xuyên suốt, dài 1–2 trang, theo mẫu: *Bối cảnh → Các lựa chọn đã xem xét (ít nhất 3: MVVM, MVVM + Router, reducer) → Quyết định → Hệ quả (tốt và xấu) → Khi nào xem lại*. Nhờ một người đọc và hỏi lại 3 câu; cập nhật ADR theo câu hỏi.

---

## Tuần 3 · Swift Package và modularization

### Ngày 11 — Swift Package cơ bản

**Kiến thức**
- `Package.swift`: products (thư viện xuất ra), targets (module), dependencies.
- Package local: kéo thư mục package vào dự án Xcode, thêm vào target app.
- Mỗi target là một module, có namespace và access control riêng.

**Ví dụ**
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShopKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ShopCore", targets: ["ShopCore"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(name: "ShopCore"),
        .target(name: "DesignSystem"),
        .testTarget(name: "ShopCoreTests", dependencies: ["ShopCore"]),
    ]
)
```

**Bài tập:** Tạo package local `ShopKit` với target `ShopCore`, chuyển model và logic thuần (không UI) của dự án xuyên suốt vào đó. Chạy test bằng `swift test` từ terminal, không cần simulator.

### Ngày 12 — Chiến lược chia module

**Kiến thức**
- Chia theo **tầng** (Networking, Persistence) và theo **tính năng** (FeatureCart, FeatureProfile). Feature không phụ thuộc feature khác.
- Feature giao tiếp qua protocol trong module "Interface" nhỏ hoặc qua closure do app nối lại.
- Đồ thị phụ thuộc phải không có vòng. App là nơi duy nhất biết mọi module.

**Ví dụ**
```
App
├── FeatureHome ──┐
├── FeatureCart ──┼──▶ ShopCore (model, use case, protocol)
├── FeatureProfile┘        ▲
├── Networking ────────────┤ (cài đặt protocol của ShopCore)
└── DesignSystem ◀── mọi Feature
```

**Bài tập:** Vẽ đồ thị module mục tiêu cho dự án của bạn. Liệt kê mọi chỗ Feature A đang gọi thẳng Feature B (ví dụ Home mở màn Cart) và thiết kế lại bằng closure hoặc Router để bỏ phụ thuộc.

### Ngày 13 — Access control và thiết kế API module

**Kiến thức**
- `public`: dùng được ngoài module. `package` (Swift 5.9): dùng được trong cùng package nhưng không lộ ra app. `internal` mặc định. `private`/`fileprivate`.
- `public` init của struct không tự sinh: phải viết tay.
- Giữ API công khai nhỏ: càng ít `public`, càng dễ thay đổi bên trong.

**Ví dụ**
```swift
public struct Money: Sendable, Hashable {
    public let amount: Decimal
    public let currency: String
    public init(_ amount: Decimal, currency: String = "VND") {
        self.amount = amount; self.currency = currency
    }
    package static func parse(_ raw: String) -> Money? { /* chỉ Networking trong package dùng */ nil }
}
```

**Bài tập:** Rà lại mọi `public` trong `ShopCore`. Giảm ít nhất 30% số khai báo `public`. Dùng `package` cho thứ chỉ module anh em cần. Viết README ngắn cho module mô tả API công khai.

### Ngày 14 — Resource, build time và test theo module

**Kiến thức**
- Resource trong package: `resources: [.process("Resources")]`, truy cập bằng `Bundle.module`.
- Module nhỏ build song song và cache tốt hơn; sửa một feature không build lại cả app.
- Đo build time: Xcode → Product → Perform Action → Build With Timing Summary.

**Ví dụ**
```swift
.target(
    name: "DesignSystem",
    resources: [.process("Resources")]   // Colors.xcassets, fonts
)

// Trong DesignSystem
public extension Color {
    static let brand = Color("Brand", bundle: .module)
}
```

**Bài tập:** Đo build time sạch và build tăng dần (sửa 1 dòng trong một feature) trước và sau khi tách module. Ghi số liệu vào ADR.

### Ngày 15 — Thực hành tuần 3: tách 3 package

**Bài tập (Mốc M2 phần 1):** Tách dự án xuyên suốt thành `ShopCore`, `DesignSystem`, `FeatureX` (một tính năng chính). Yêu cầu: mỗi module build và test độc lập; Feature không import Feature khác; app chỉ còn composition root và điều hướng cấp cao.

---

## Tuần 4 · Hạ tầng dùng chung

### Ngày 16 — Design system module

**Kiến thức**
- Token (màu, khoảng cách, cỡ chữ, bo góc) trước, component sau.
- Component nhận dữ liệu và closure, không biết gì về nghiệp vụ.
- Hỗ trợ dark mode, Dynamic Type, Liquid Glass ngay trong component để mọi màn hình được hưởng.

**Ví dụ**
```swift
public enum Spacing { public static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 16, l: CGFloat = 24 }

public struct PrimaryButton: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let action: () -> Void
    public init(_ title: LocalizedStringKey, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.isLoading = isLoading; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            if isLoading { ProgressView() } else { Text(title).frame(maxWidth: .infinity) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
}
```

**Bài tập:** Xây `DesignSystem` với token và 6 component: nút chính/phụ, ô nhập có thông báo lỗi, thẻ sản phẩm, trạng thái rỗng, banner lỗi có nút thử lại. Mỗi component có `#Preview` cho sáng/tối/chữ lớn.

### Ngày 17 — Cấu hình môi trường và feature flag

**Kiến thức**
- Môi trường Dev/Staging/Prod bằng build configuration + `.xcconfig` (URL API, bundle id, tên app).
- Đọc giá trị qua `Info.plist` → `Bundle.main.object(forInfoDictionaryKey:)`. Không commit secret vào repo.
- Feature flag: bật/tắt tính năng mà không cần phát hành lại; mặc định an toàn là "tắt".

**Ví dụ**
```
// Config/Staging.xcconfig
API_BASE_URL = https:/$()/staging-api.example.com
PRODUCT_BUNDLE_IDENTIFIER = com.example.shop.staging
```
```swift
enum AppConfig {
    static let apiBaseURL: URL = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: raw) else { fatalError("Thiếu API_BASE_URL trong Info.plist") }
        return url
    }()
}
```

**Bài tập:** Tạo 3 cấu hình Dev/Staging/Prod cho dự án, mỗi cấu hình một icon và tên app khác nhau để cài song song trên máy. Viết `protocol FeatureFlags` với bản cục bộ (đọc từ plist) và bản test.

### Ngày 18 — Logging có cấu trúc với `os.Logger`

**Kiến thức**
- `Logger(subsystem:category:)` ghi vào Unified Logging, xem bằng Console.app, lọc theo category.
- Mức: `debug`, `info`, `notice`, `error`, `fault`.
- Quyền riêng tư: biến nội suy mặc định bị ẩn (`<private>`) trên máy thật. Đánh dấu `privacy: .public` chỉ cho dữ liệu không nhạy cảm.

**Ví dụ**
```swift
import os

extension Logger {
    static let network = Logger(subsystem: "com.example.shop", category: "network")
}

Logger.network.info("GET \(path, privacy: .public) → \(status)")
Logger.network.error("Decode lỗi cho user \(userID, privacy: .private): \(error.localizedDescription)")
```

**Bài tập:** Thay mọi `print` trong dự án bằng `Logger` theo category (network, auth, ui, persistence). Dùng Console.app trên máy thật lọc log của một luồng đặt hàng; kiểm tra không có token hay email nào hiện rõ.

### Ngày 19 — Checklist code review

**Kiến thức**
- Review theo thứ tự: đúng chưa → an toàn chưa (concurrency, memory, bảo mật) → dễ hiểu chưa → nhất quán chưa → hiệu năng.
- Bình luận cụ thể, kèm lý do và gợi ý; phân biệt "bắt buộc sửa" với "gợi ý".
- PR nhỏ (dưới 400 dòng) được review kỹ hơn nhiều so với PR lớn.

**Ví dụ (một bình luận review tốt)**
```
[Bắt buộc] `Task { self.items = await load() }` giữ self mạnh tới khi load xong
và không bị huỷ khi màn hình đóng. Đề xuất: lưu handle và huỷ trong onDisappear,
hoặc dùng .task trong SwiftUI. Tham khảo Bài 5 ConcurrencyLab.
```

**Bài tập:** Viết checklist review 15 mục cho team iOS của bạn (chia nhóm: Concurrency, Memory, UI/Accessibility, Kiến trúc, Bảo mật, Test). Áp dụng review 2 PR cũ trong repo, ghi lại các phát hiện.

### Ngày 20 — Ôn tập và kiểm tra tháng 5

**Bài tập:** Hoàn thiện ADR với số liệu build time thực tế. Trình bày kiến trúc dự án xuyên suốt cho một người khác trong 10 phút bằng sơ đồ module và sơ đồ tầng; ghi lại câu hỏi bạn không trả lời được.

**Tự đánh giá:** giải thích không nhìn tài liệu: khi nào MVVM là đủ, khi nào cần reducer; composition root là gì; vì sao Feature không được import Feature; `package` khác `internal` và `public` thế nào; làm lại câu 13 của bài trắc nghiệm.
