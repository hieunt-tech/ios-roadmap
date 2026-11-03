# Tháng 7 — Testing

**Mục tiêu:** viết test có chủ đích, tất định (không flaky), cho cả code đồng bộ, async, ViewModel, persistence và UI.
**Đầu ra cuối tháng:** module lõi của dự án xuyên suốt đạt coverage ≥ 70%, có snapshot test cho component và UI test cho luồng quan trọng nhất.

[← Tháng 6](thang-06.md) · [Mục lục](../../README.md) · [Tháng 8 →](thang-08.md)

---

## Tuần 1 · Nền tảng

### Ngày 1 — Vì sao test, test cái gì

**Kiến thức**
- Kim tự tháp test: nhiều unit test (nhanh, rẻ), ít integration test, rất ít UI test (chậm, dễ vỡ).
- Test **hành vi**, không test chi tiết cài đặt: "thêm món đã có thì tăng số lượng", không phải "gọi `items.append` 1 lần".
- Ưu tiên test chỗ có logic, chỗ đã từng có bug, chỗ nhiều người sửa. Không cố đạt 100% coverage.

**Ví dụ**
```swift
// Test hành vi: đọc tên test là hiểu yêu cầu
@Test("Thêm món đã có trong giỏ thì tăng số lượng, không thêm dòng mới")
func addingExistingItemIncreasesQuantity() {
    var cart = Cart()
    cart.add(.pho, quantity: 1)
    cart.add(.pho, quantity: 2)
    #expect(cart.lines.count == 1)
    #expect(cart.lines.first?.quantity == 3)
}
```

**Bài tập:** Liệt kê 20 hành vi của tính năng Giỏ hàng trong dự án xuyên suốt dưới dạng câu "Khi ... thì ...". Đánh dấu 5 hành vi rủi ro nhất (tiền, trạng thái đơn) để viết test trước.

### Ngày 2 — Swift Testing cơ bản

**Kiến thức**
- `import Testing`, `@Test`, `@Suite`; `#expect(điều kiện)` ghi nhận lỗi và chạy tiếp, `#require` dừng test (và unwrap optional).
- Test là hàm bình thường, có thể `async throws`; suite là struct, mỗi test có instance riêng (khởi tạo trong `init`).
- `#expect(throws: SomeError.self) { ... }` kiểm tra lỗi.

**Ví dụ**
```swift
import Testing
@testable import ShopCore

@Suite("Mã giảm giá")
struct CouponTests {
    let cart: Cart
    init() { cart = Cart(lines: [.init(item: .pho, quantity: 2)]) }   // 90.000đ

    @Test func percentCoupon() throws {
        let total = try #require(cart.total(applying: .percent(10)))
        #expect(total == 81_000)
    }

    @Test func expiredCouponIsRejected() {
        #expect(throws: CouponError.expired) {
            try cart.total(applying: .expired)
        }
    }
}
```

**Bài tập:** Viết test cho 5 hành vi rủi ro nhất đã chọn ở Ngày 1. Mỗi test một hành vi, tên test là câu tiếng Việt mô tả yêu cầu.

### Ngày 3 — Tham số hoá, trait, tag

**Kiến thức**
- `@Test(arguments: [...])` chạy một test với nhiều đầu vào; `arguments: zip(inputs, expected)` cho cặp đầu vào – kết quả.
- Trait: `.disabled("lý do")`, `.enabled(if:)`, `.timeLimit(.minutes(1))`, `.bug("URL")`, `.serialized`.
- Tag (`@Tag`) nhóm test để chạy riêng (`swift test --filter`), ví dụ `.money`, `.slow`.

**Ví dụ**
```swift
extension Tag { @Tag static var money: Self }

@Test("Phí giao hàng theo khoảng cách", .tags(.money),
      arguments: zip([0.5, 2.9, 3.0, 7.5, 15.0], [15_000, 15_000, 20_000, 35_000, 0]))
func shippingFee(distanceKm: Double, expected: Decimal) {
    #expect(ShippingPolicy.fee(forDistanceKm: distanceKm) == expected)
}
```

**Bài tập:** Viết bảng 15 trường hợp biên cho phí giao hàng (0 km, đúng mốc, quá xa thì không giao, giá trị âm, NaN) và chuyển thành một test tham số hoá. Gắn tag `.money` cho mọi test liên quan tới tiền.

### Ngày 4 — XCTest và chuyển sang Swift Testing

**Kiến thức**
- XCTest vẫn cần cho UI test (`XCUIApplication`) và performance test (`measure`).
- Hai framework chạy chung một target được. Chuyển dần: test mới viết bằng Swift Testing, test cũ chuyển khi sửa.
- Tương ứng: `XCTAssertEqual` → `#expect(a == b)`, `XCTUnwrap` → `#require`, `setUp` → `init`, `tearDown` → `deinit` (suite là class) hoặc trait.

**Ví dụ**
```swift
// Trước
final class PriceFormatterTests: XCTestCase {
    func testFormatsVND() { XCTAssertEqual(PriceFormatter.vnd(45_000), "45.000 ₫") }
}

// Sau
@Test func formatsVND() { #expect(PriceFormatter.vnd(45_000) == "45.000 ₫") }
```

**Bài tập:** Chuyển 10 test XCTest trong dự án của bạn sang Swift Testing. Ghi lại 3 chỗ khó chuyển và cách giải quyết. Giữ lại một performance test bằng XCTest.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Viết đầy đủ test cho `Cache<Key, Value>` (Tháng 1) và `Money` (Tháng 5): tham số hoá các trường hợp biên, test thuộc tính "thêm rồi xoá thì như chưa thêm", test hiệu năng `LRU` với 10.000 phần tử. Đạt coverage 100% cho hai type này.

---

## Tuần 2 · Test double và code bất đồng bộ

### Ngày 6 — Stub, mock, fake, spy

**Kiến thức**
- **Stub**: trả kết quả cố định. **Spy**: ghi lại lời gọi để kiểm tra sau. **Mock**: spy có kỳ vọng sẵn. **Fake**: cài đặt đơn giản nhưng hoạt động thật (repository trong bộ nhớ).
- Ưu tiên fake và stub; mock chặt chẽ làm test vỡ khi refactor dù hành vi không đổi.
- Test double cho protocol nhỏ dễ viết hơn nhiều so với protocol 30 hàm (nhắc lại Interface Segregation).

**Ví dụ**
```swift
final class SpyAnalytics: AnalyticsTracking, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [String] = []
    var events: [String] { lock.withLock { _events } }
    func track(_ name: String) { lock.withLock { _events.append(name) } }
}

struct InMemoryOrderRepository: OrderRepository {
    let store = OrderStore()            // actor giữ đơn hàng
    func place(_ order: Order) async throws -> Order.ID { await store.insert(order) }
}
```

**Bài tập:** Viết fake `InMemoryOrderRepository`, stub `FixedClock`, spy `SpyAnalytics` và dùng để test `PlaceOrderUseCase` (Tháng 5): đặt thành công thì gửi sự kiện `order_placed`; ngoài giờ mở cửa thì không gọi repository.

### Ngày 7 — Test code async

**Kiến thức**
- Test `async` gọi thẳng `await`, không cần `XCTestExpectation`.
- Sự kiện xảy ra qua callback/stream: `await confirmation("mô tả", expectedCount: n) { confirm in ... }`.
- Không bao giờ dùng `Task.sleep(1s)` rồi kiểm tra: chậm và vẫn flaky.

**Ví dụ**
```swift
@Test func publishesTwoProgressEvents() async {
    let uploader = Uploader()
    await confirmation("nhận tiến độ", expectedCount: 2) { progress in
        uploader.onProgress = { _ in progress() }
        await uploader.upload(Data(count: 2_000), chunkSize: 1_000)
    }
}
```

**Bài tập:** Viết test cho `downloadAll` (Tháng 4, Ngày 3): kết quả đủ, không quá 4 request đồng thời, một URL lỗi thì cả nhóm ném lỗi và các request còn lại bị huỷ. Không được dùng `sleep` để chờ.

### Ngày 8 — Test race condition một cách tất định

**Kiến thức**
- Để test race, *test phải điều khiển thứ tự*: fake giữ request lại, test quyết định cái nào xong trước (kỹ thuật `ControlledCalls` trong ConcurrencyLab).
- Chờ điều kiện bằng continuation (`Metric.wait(atLeast:)`), không bằng polling.
- Mọi điểm chờ trong test phải có timeout và phải huỷ được.

**Ví dụ**
```swift
@Test func lateResponseIsIgnored() async throws {
    let api = FakeSearchAPI()                       // giữ mọi request
    let vm = SearchViewModel(api: api, sleeper: ImmediateSleeper())
    vm.queryChanged("ph");  let old = vm.searchTask
    vm.queryChanged("pho")
    try await withTimeout { try await api.calls.pendingCount.wait(atLeast: 2) }
    api.calls.resolve(first: { $0 == "pho" }, with: .success(["Phở bò"]))
    try await finish(vm.searchTask)
    api.calls.resolve(first: { $0 == "ph" }, with: .success(["Phở cuốn"]))   // về sau
    try await finish(old)
    #expect(vm.results == ["Phở bò"])
}
```

**Bài tập:** Copy `ControlledCalls`, `Metric`, `withTimeout` từ ConcurrencyLab vào module test của dự án xuyên suốt. Viết 3 test race cho code thật của bạn: refresh token đồng thời, tải trang tiếp theo khi đang tải, bấm nút đặt hàng 2 lần liên tiếp.

### Ngày 9 — Test ViewModel `@MainActor`

**Kiến thức**
- Gắn `@MainActor` cho suite hoặc test để gọi ViewModel trực tiếp.
- Test trạng thái *quan sát được* (`isLoading`, `items`, `errorMessage`) qua từng bước, không chỉ kết quả cuối.
- Giữ handle task (`searchTask`) trong ViewModel giúp test chờ được việc bất đồng bộ.

**Ví dụ**
```swift
@MainActor
@Suite struct CheckoutViewModelTests {
    @Test func showsLoadingThenSuccess() async throws {
        let repo = ControlledOrderRepository()
        let vm = CheckoutViewModel(placeOrder: PlaceOrderUseCase(repository: repo, now: { .noon }))
        vm.placeOrderTapped()
        #expect(vm.state == .submitting)
        try await withTimeout { try await repo.calls.pendingCount.wait(atLeast: 1) }
        repo.calls.resolveAll(with: .success(Order.ID()))
        try await finish(vm.submitTask)
        #expect(vm.state == .placed)
    }
}
```

**Bài tập:** Viết test cho màn hình Checkout: trạng thái submitting/placed/failed, bấm 2 lần chỉ đặt 1 đơn, lỗi mạng cho phép thử lại, lỗi "hết món" không cho thử lại mà quay về giỏ hàng.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Đưa coverage module `Networking` (Tháng 6) lên ≥ 80%. Bật coverage trong scheme (Edit Scheme → Test → Options → Code Coverage), xem báo cáo, viết test cho các nhánh chưa được chạy. Ghi lại 2 bug tìm ra nhờ viết test.

---

## Tuần 3 · Test giao diện

### Ngày 11 — Snapshot test

**Kiến thức**
- Snapshot test chụp ảnh view và so với ảnh tham chiếu; phát hiện lỗi giao diện không ai để ý (khoảng cách lệch, chữ bị cắt).
- Thư viện phổ biến: `swift-snapshot-testing` của Point-Free. Ghi ảnh lần đầu, so ở lần sau.
- Chụp nhiều cấu hình: sáng/tối, Dynamic Type lớn, ngôn ngữ dài, iPhone SE và iPad. Cố định thiết bị simulator trên CI để ảnh không lệch.

**Ví dụ**
```swift
import SnapshotTesting
import XCTest

final class ProductCardSnapshotTests: XCTestCase {
    func testProductCard() {
        let view = ProductCard(product: .sampleLongName)
            .frame(width: 180)
            .environment(\.dynamicTypeSize, .accessibility2)
        assertSnapshot(of: UIHostingController(rootView: view), as: .image(on: .iPhone13))
    }
}
```

**Bài tập:** Viết snapshot test cho 6 component của `DesignSystem` (Tháng 5), mỗi cái 4 cấu hình (sáng, tối, chữ lớn, tiếng Anh dài). Cố tình đổi padding 2pt và xem test bắt được.

### Ngày 12 — UI test với XCUITest

**Kiến thức**
- UI test chạy app thật trong simulator, bấm như người dùng. Chậm nên chỉ dùng cho luồng quan trọng nhất.
- Gắn `accessibilityIdentifier` cho phần tử cần tìm; không tìm theo chuỗi hiển thị (đổi ngôn ngữ là vỡ).
- Launch argument để app dùng dữ liệu giả: `app.launchArguments = ["-uiTesting"]`.
- Page Object: gói thao tác của từng màn hình thành type riêng để test dễ đọc.

**Ví dụ**
```swift
struct LoginScreen {
    let app: XCUIApplication
    func login(email: String, password: String) -> HomeScreen {
        app.textFields["login.email"].tap()
        app.textFields["login.email"].typeText(email)
        app.secureTextFields["login.password"].tap()
        app.secureTextFields["login.password"].typeText(password)
        app.buttons["login.submit"].tap()
        return HomeScreen(app: app)
    }
}

final class CheckoutFlowUITests: XCTestCase {
    func testUserCanPlaceOrder() {
        let app = XCUIApplication(); app.launchArguments = ["-uiTesting"]; app.launch()
        LoginScreen(app: app).login(email: "a@b.vn", password: "12345678")
            .addFirstProductToCart().openCart().checkout()
        XCTAssertTrue(app.staticTexts["order.success"].waitForExistence(timeout: 5))
    }
}
```

**Bài tập:** Viết UI test cho luồng đăng nhập → thêm món → đặt hàng → thấy màn hình thành công, dùng Page Object và dữ liệu giả qua launch argument. Chạy 10 lần liên tiếp: phải xanh cả 10.

### Ngày 13 — Test plan, coverage và xử lý test flaky

**Kiến thức**
- Test Plan (`.xctestplan`): nhiều cấu hình (ngôn ngữ, vùng, sanitizer), chạy song song, lặp lại test để tìm flaky (*Test Repetition*).
- Test flaky thường do: chờ bằng thời gian, phụ thuộc thứ tự chạy, dùng chung state (singleton, `UserDefaults.standard`), mạng thật.
- Cách xử lý: tìm nguyên nhân gốc; tạm `.disabled("flaky: link ticket")` có thời hạn, không xoá test.

**Ví dụ**
```swift
// Flaky: phụ thuộc thời gian thực
@Test func badgeDisappears() async throws {
    vm.showBadge()
    try await Task.sleep(for: .seconds(3))      // máy CI chậm → vỡ
    #expect(vm.badgeVisible == false)
}

// Ổn định: điều khiển thời gian
@Test func badgeDisappearsAfterDelay() async throws {
    let sleeper = ControlledSleeper()
    let vm = BadgeViewModel(sleeper: sleeper)
    vm.showBadge()
    try await withTimeout { try await sleeper.calls.pendingCount.wait(atLeast: 1) }
    sleeper.calls.resolveAll(with: .success(()))
    try await finish(vm.hideTask)
    #expect(vm.badgeVisible == false)
}
```

**Bài tập:** Tạo Test Plan với 3 cấu hình: tiếng Việt, tiếng Anh + Thread Sanitizer, Address Sanitizer. Bật lặp lại 20 lần cho toàn bộ unit test, tìm và sửa mọi test flaky.

### Ngày 14 — TDD qua bài kata

**Kiến thức**
- Đỏ → Xanh → Refactor: viết test thất bại, viết code tối thiểu để xanh, dọn dẹp.
- TDD hợp với logic nghiệp vụ rõ ràng (tính tiền, validation, parser); ít hợp với UI khám phá.
- Bước nhỏ: mỗi vòng vài phút.

**Ví dụ (3 vòng đầu của kata "định dạng số tiền")**
```swift
@Test func zero() { #expect(formatVND(0) == "0đ") }                  // vòng 1
@Test func thousands() { #expect(formatVND(45_000) == "45.000đ") }   // vòng 2
@Test func millions() { #expect(formatVND(1_250_000) == "1.250.000đ") } // vòng 3
```

**Bài tập:** Làm kata "đọc số tiền bằng chữ tiếng Việt" theo TDD trong 90 phút: `125_000` → "một trăm hai mươi lăm nghìn đồng", xử lý "lẻ", "mốt", "lăm", "tư", "mươi". Commit sau mỗi vòng xanh để xem lại quá trình.

### Ngày 15 — Thực hành tuần 3

**Bài tập:** Viết UI test cho luồng quan trọng nhất của dự án xuyên suốt (Mốc M3 phần 1), snapshot test cho 3 màn hình chính ở 4 cấu hình, và chạy toàn bộ trong Test Plan không flaky sau 20 lần lặp.

---

## Tuần 4 · Test tầng dữ liệu và kiến trúc test

### Ngày 16 — Test persistence với SwiftData

**Kiến thức**
- Dùng `ModelContainer` với `ModelConfiguration(isStoredInMemoryOnly: true)`: nhanh, mỗi test một kho mới.
- Test migration: tạo store V1 trên file tạm, ghi dữ liệu, mở lại bằng schema V2 + migration plan, kiểm tra dữ liệu.
- Không dùng chung container giữa các test chạy song song.

**Ví dụ**
```swift
@MainActor
@Test func pinnedNotesComeFirst() throws {
    let container = try ModelContainer(for: Note.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    context.insert(Note(title: "B")); context.insert(Note(title: "A", isPinned: true))
    let notes = try context.fetch(NoteQueries.home)
    #expect(notes.map(\.title) == ["A", "B"])
}
```

**Bài tập:** Viết test cho mọi truy vấn của app ghi chú (Tháng 6) và test migration V1 → V2 với 100 ghi chú. Đảm bảo test chạy song song không ảnh hưởng nhau.

### Ngày 17 — Contract test và JSON fixture

**Kiến thức**
- Lưu response thật của API vào file fixture; test decode từ fixture để phát hiện khi backend đổi định dạng.
- Fixture cho trường hợp xấu: trường thiếu, `null`, kiểu sai, mảng rỗng, chuỗi Unicode.
- Khi backend có OpenAPI spec, có thể sinh model (Swift OpenAPI Generator) để giảm sai lệch.

**Ví dụ**
```swift
@Test(arguments: ["products_ok", "products_missing_price", "products_empty"])
func decodesFixture(name: String) throws {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    let data = try Data(contentsOf: url)
    let page = try JSONDecoder().decode(Page<ProductDTO>.self, from: data)
    #expect(page.items.allSatisfy { !$0.name.isEmpty })
}
```

**Bài tập:** Thu thập 10 response thật (bằng Proxyman) làm fixture, thêm 5 fixture xấu tự tạo. Viết test decode cho tất cả. Đề xuất với backend một quy ước versioning API dựa trên những gì bạn thấy.

### Ngày 18 — Kiến trúc test cho dự án nhiều module

**Kiến thức**
- Mỗi module có test target riêng, chạy được bằng `swift test` không cần simulator khi không phụ thuộc UIKit.
- Module `TestSupport` dùng chung: fake, fixture builder, `ControlledCalls`. Không để code test lọt vào app.
- Builder cho dữ liệu test: `Product.make(price: 10_000)` với giá trị mặc định hợp lý.

**Ví dụ**
```swift
extension Product {
    static func make(id: Product.ID = .init(), name: String = "Phở bò",
                     price: Decimal = 45_000, inStock: Bool = true) -> Product {
        Product(id: id, name: name, price: price, inStock: inStock)
    }
}

// Test chỉ nêu điều nó quan tâm
let outOfStock = Product.make(inStock: false)
```

**Bài tập:** Tạo module `ShopTestSupport` chứa builder cho mọi entity, fake cho mọi protocol repository/service, và tiện ích async. Refactor test hiện có dùng module này; đếm số dòng test giảm được.

### Ngày 19 — Review test

**Kiến thức**
- Test tốt: tên mô tả yêu cầu, một lý do để thất bại, thông báo lỗi giúp sửa nhanh, chạy nhanh, độc lập.
- "Mutation thinking": nếu cố tình làm sai code (đổi `>=` thành `>`), có test nào đỏ không? Không có thì test chưa đủ.
- Đọc test như tài liệu: người mới đọc test có hiểu tính năng không?

**Ví dụ**
```swift
// Thông báo lỗi giúp sửa nhanh
#expect(fee == 20_000, "Đúng mốc 3 km phải tính bậc 2 (20.000đ), nhận \(fee)")
```

**Bài tập:** Chọn 5 chỗ logic quan trọng, tự đột biến code (mỗi chỗ 3 kiểu: đổi toán tử so sánh, bỏ một nhánh `if`, đổi hằng số). Ghi lại đột biến nào không bị test nào bắt và viết thêm test cho chúng.

### Ngày 20 — Ôn tập và kiểm tra tháng 7

**Bài tập:** Báo cáo chất lượng test của dự án xuyên suốt: coverage từng module, số test mỗi loại (unit/integration/snapshot/UI), thời gian chạy toàn bộ, số test flaky đã sửa. Mục tiêu: module lõi ≥ 70%, toàn bộ unit test chạy dưới 30 giây.

**Tự đánh giá:** làm lại câu 14 của bài trắc nghiệm; giải thích không nhìn tài liệu: stub/mock/fake/spy khác nhau thế nào; vì sao không dùng `sleep` trong test; cách test một race condition; khi nào chọn snapshot test thay vì UI test.
