# Tháng 1 — Swift nâng cao

**Mục tiêu:** hiểu *vì sao* Swift hoạt động như vậy, không chỉ viết được code chạy.
**Đầu ra cuối tháng:** một module `Cache<Key, Value>` generic có test, và trả lời được các câu hỏi về value semantics, generics, `some`/`any`.

Mỗi buổi khoảng 2 giờ: 30 phút đọc phần kiến thức, 30 phút gõ lại và chỉnh ví dụ trong Playground, 60 phút làm bài tập.

[← Mục lục](../../README.md) · [Tháng 2 →](thang-02.md)

---

## Tuần 1 · Value semantics và kiểu dữ liệu

### Ngày 1 — struct và class

**Kiến thức**
- `struct` là value type: gán hoặc truyền vào hàm thì tạo bản sao độc lập. `class` là reference type: nhiều biến cùng trỏ một object.
- Mặc định chọn `struct`. Chỉ dùng `class` khi cần identity (cùng một đối tượng được chia sẻ), kế thừa, `deinit` hoặc interop với Objective-C.
- `let` với struct khoá toàn bộ giá trị. `let` với class chỉ khoá tham chiếu; property `var` bên trong vẫn sửa được.

**Ví dụ**
```swift
struct PointS { var x = 0 }
final class PointC { var x = 0 }

var a = PointS(); var b = a; b.x = 10
print(a.x, b.x)          // 0 10  — hai bản độc lập

let c = PointC(); let d = c; d.x = 10
print(c.x, d.x)          // 10 10 — cùng một object
```

**Bài tập:** Viết model `CartItem` và `Cart` cho giỏ hàng. Chứng minh bằng code rằng sửa giỏ hàng ở màn hình Checkout không làm thay đổi giỏ hàng đang hiển thị ở màn hình Home nếu dùng struct. Sau đó đổi `Cart` thành class và mô tả lỗi UI sẽ xảy ra.

### Ngày 2 — Copy-on-write

**Kiến thức**
- `Array`, `Dictionary`, `String` là struct nhưng không sao chép ngay khi gán. Chúng chia sẻ bộ nhớ đệm và chỉ sao chép khi một bản bị sửa (copy-on-write).
- `isKnownUniquelyReferenced(&ref)` cho biết bộ nhớ đệm có đang bị chia sẻ không. Đây là công cụ để tự cài CoW cho kiểu của bạn.
- Struct tự viết chứa một class bên trong **không** tự có CoW; bạn phải cài.

**Ví dụ**
```swift
final class Storage { var items: [Int]; init(_ i: [Int]) { items = i } }

struct IntBag {
    private var storage = Storage([])
    var items: [Int] { storage.items }

    mutating func append(_ v: Int) {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(storage.items)   // sao chép trước khi sửa
        }
        storage.items.append(v)
    }
}
```

**Bài tập:** Viết struct `Matrix` lưu `[Double]` trong một class `Buffer` và cài copy-on-write. Viết 3 test chứng minh: gán không sao chép, sửa bản sao không ảnh hưởng bản gốc, sửa khi duy nhất không sao chép (đếm số lần khởi tạo `Buffer`).

### Ngày 3 — `mutating`, `inout` và exclusivity

**Kiến thức**
- Method sửa struct phải đánh dấu `mutating`, vì nó thay `self` bằng giá trị mới.
- `inout` truyền giá trị vào, cho hàm sửa, rồi ghi lại khi hàm kết thúc (copy-in copy-out), không phải truyền con trỏ.
- Luật exclusivity: không được có hai truy cập ghi chồng nhau vào cùng một biến. Vi phạm sẽ bị báo lỗi lúc biên dịch hoặc crash lúc chạy.

**Ví dụ**
```swift
func increment(_ value: inout Int, by step: Int) { value += step }

var count = 1
increment(&count, by: 2)          // OK
// increment(&count, by: count)   // OK: đọc count trước khi bắt đầu ghi
var numbers = [1, 2]
// swap(&numbers[0], &numbers[1]) // Lỗi exclusivity: dùng numbers.swapAt(0, 1)
numbers.swapAt(0, 1)
```

**Bài tập:** Viết hàm `normalize(_ scores: inout [Double])` đưa điểm về khoảng 0...1. Tìm và giải thích một ví dụ vi phạm exclusivity khi gọi method `mutating` trên một property của chính `self` trong closure.

### Ngày 4 — Enum có associated value và pattern matching

**Kiến thức**
- Enum biểu diễn "một trong các trạng thái", mỗi trạng thái mang dữ liệu riêng. Nó loại bỏ các tổ hợp không hợp lệ (ví dụ `isLoading == true` mà `error != nil`).
- `switch` phải xử lý đủ mọi case. Đây là lý do nên tránh `default` khi có thể: thêm case mới thì compiler nhắc bạn sửa mọi chỗ.
- Pattern: `case .loaded(let items) where items.isEmpty`, `if case`, `guard case`.

**Ví dụ**
```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(any Error)
}

func render(_ state: LoadState<[String]>) -> String {
    switch state {
    case .idle: "Kéo để tải"
    case .loading: "Đang tải…"
    case .loaded(let items) where items.isEmpty: "Chưa có dữ liệu"
    case .loaded(let items): "\(items.count) mục"
    case .failed(let error): "Lỗi: \(error.localizedDescription)"
    }
}
```

**Bài tập:** Một màn hình đang có 4 biến `isLoading`, `items`, `errorMessage`, `isEmpty`. Liệt kê các tổ hợp vô nghĩa có thể xảy ra, rồi thay bằng một enum `ScreenState`. Viết hàm chuyển trạng thái `reduce(state:event:)` cho các sự kiện `refresh`, `succeeded`, `failed`.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Mô hình hoá domain đặt đồ ăn: `Restaurant`, `MenuItem` (có tuỳ chọn size, topping), `Order` với trạng thái `draft → placed → preparing → delivering → delivered | cancelled(reason)`. Yêu cầu:
- Không thể tạo một `Order` ở trạng thái không hợp lệ (ví dụ `delivered` mà chưa có tài xế).
- Tính tổng tiền đúng khi có topping và mã giảm giá.
- Viết ít nhất 8 test cho các chuyển trạng thái hợp lệ và không hợp lệ.

---

## Tuần 2 · Protocol và generics

### Ngày 6 — Protocol, extension, dispatch

**Kiến thức**
- Protocol mô tả khả năng. Protocol extension cung cấp cài đặt mặc định.
- **Bẫy dispatch:** method có trong khai báo protocol được dispatch động (theo kiểu thật). Method *chỉ* có trong extension được dispatch tĩnh (theo kiểu khai báo của biến).
- Ưu tiên composition (`Codable = Encodable & Decodable`) thay vì kế thừa class.

**Ví dụ**
```swift
protocol Greeter { func hello() -> String }
extension Greeter {
    func hello() -> String { "Xin chào" }
    func bye() -> String { "Tạm biệt" }      // không có trong protocol
}
struct Vietnamese: Greeter {
    func hello() -> String { "Chào bạn" }
    func bye() -> String { "Hẹn gặp lại" }
}
let g: any Greeter = Vietnamese()
print(g.hello())   // "Chào bạn"   — dynamic dispatch
print(g.bye())     // "Tạm biệt"   — static dispatch theo `any Greeter`
```

**Bài tập:** Viết protocol `Analytics` với `track(_:)`, và 2 cài đặt: `ConsoleAnalytics`, `FirebaseAnalyticsStub`. Thêm `trackScreen(_:)` trong extension và tạo một tình huống bug do static dispatch. Sửa bằng cách đưa method vào khai báo protocol.

### Ngày 7 — Generics và ràng buộc `where`

**Kiến thức**
- Generic giúp viết một lần cho nhiều kiểu mà vẫn giữ kiểm tra kiểu lúc biên dịch.
- Ràng buộc: `<T: Comparable>`, `where T.Element == String`, conditional conformance (`extension Array: MyProtocol where Element: MyProtocol`).
- Compiler có thể *specialize* code generic cho từng kiểu cụ thể, nên thường nhanh như code viết tay.

**Ví dụ**
```swift
func topN<C: Collection>(_ items: C, _ n: Int) -> [C.Element]
where C.Element: Comparable {
    Array(items.sorted(by: >).prefix(n))
}

extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}

topN([3, 9, 1, 7], 2)          // [9, 7]
let tags: [String]? = []
tags.isNilOrEmpty               // true
```

**Bài tập:** Viết `func groupBy<T, Key: Hashable>(_ items: [T], key: (T) -> Key) -> [Key: [T]]` và `func uniqued<T: Hashable>(_ items: [T]) -> [T]` giữ nguyên thứ tự. Thêm conditional conformance: `Pair<A, B>` là `Equatable` khi cả `A` và `B` là `Equatable`.

### Ngày 8 — `associatedtype` và primary associated type

**Kiến thức**
- `associatedtype` là "kiểu do người cài đặt quyết định", ví dụ `Collection.Element`.
- Primary associated type (`protocol Repository<Model>`) cho phép viết `any Repository<User>` hoặc `some Repository<User>`.
- Protocol có `Self` hoặc associated type thì trước đây không dùng làm kiểu được; Swift 5.7+ cho phép với `any`, kèm giới hạn.

**Ví dụ**
```swift
protocol Repository<Model> {
    associatedtype Model: Identifiable
    func fetchAll() async throws -> [Model]
    func save(_ model: Model) async throws
}

struct User: Identifiable { let id: UUID; var name: String }

struct InMemoryUserRepository: Repository {
    private(set) var store: [User] = []
    func fetchAll() async throws -> [User] { store }
    func save(_ model: User) async throws { /* ... */ }
}

func countUsers(in repo: some Repository<User>) async throws -> Int {
    try await repo.fetchAll().count
}
```

**Bài tập:** Định nghĩa `protocol DataSource<Item>` cho một màn hình danh sách có `items`, `loadMore()`. Viết hai cài đặt: một từ mạng (giả lập), một từ mảng tĩnh. Viết một `ListViewModel` nhận `any DataSource<Product>`.

### Ngày 9 — `some` và `any`, type erasure

**Kiến thức**
- `some P` (opaque type): một kiểu cụ thể duy nhất, ẩn với người gọi, compiler biết rõ nên tối ưu được.
- `any P` (existential): hộp chứa được nhiều kiểu khác nhau lúc chạy, có chi phí cấp phát và dispatch động.
- Quy tắc thực tế: tham số hàm dùng `some` khi có thể; dùng `any` khi cần lưu một tập hỗn hợp (`[any Shape]`).
- Type erasure thủ công (`AnyPublisher`, `AnyView`) là cách cũ trước khi có `any`.

**Ví dụ**
```swift
protocol Shape { func area() -> Double }
struct Square: Shape { var s: Double; func area() -> Double { s * s } }
struct Circle: Shape { var r: Double; func area() -> Double { .pi * r * r } }

func makeShape() -> some Shape { Square(s: 2) }   // luôn là Square
let mixed: [any Shape] = [Square(s: 1), Circle(r: 1)]
let total = mixed.reduce(0) { $0 + $1.area() }
```

**Bài tập:** Giải thích bằng lời vì sao `func make(flag: Bool) -> some Shape { flag ? Square(s: 1) : Circle(r: 1) }` không biên dịch. Đưa ra 2 cách sửa và nêu đánh đổi của mỗi cách.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Viết `Cache<Key: Hashable, Value>` generic với `subscript`, `removeAll()`, giới hạn số phần tử (`countLimit`), loại phần tử cũ nhất khi đầy. Thêm `protocol Caching<Key, Value>` để màn hình chỉ phụ thuộc protocol. Viết test cho: thêm, đọc, loại khi đầy, `countLimit = 0`.

---

## Tuần 3 · Closures, lỗi và optional

### Ngày 11 — Closure và capture

**Kiến thức**
- Closure bắt biến theo *tham chiếu*: đọc giá trị lúc closure chạy, không phải lúc tạo. Capture list `[value]` chụp giá trị lúc tạo.
- `@escaping`: closure sống lâu hơn hàm nhận nó (lưu lại, chạy bất đồng bộ). Closure escaping bắt `self` của class thì có thể gây retain cycle (học kỹ ở Tháng 2).
- `@Sendable`: closure có thể chạy trên luồng khác, không được bắt biến `var` có thể thay đổi.

**Ví dụ**
```swift
var counter = 0
let byReference = { print(counter) }
let byValue = { [counter] in print(counter) }
counter = 5
byReference()   // 5
byValue()       // 0
```

**Bài tập:** Viết `func makeCounter() -> () -> Int` trả về closure đếm tăng dần. Tạo hai counter và chứng minh chúng độc lập. Giải thích vì sao trong vòng lặp `for i in 0..<3 { handlers.append { print(i) } }` Swift in ra 0, 1, 2 (khác JavaScript với `var`).

### Ngày 12 — Hàm bậc cao và `lazy`

**Kiến thức**
- `map`, `compactMap`, `flatMap`, `filter`, `reduce(into:)`, `first(where:)`, `contains(where:)`, `allSatisfy`.
- `reduce(into:)` nhanh hơn `reduce` khi gom vào Dictionary hoặc Array vì không sao chép mỗi bước.
- `.lazy` trì hoãn tính toán tới khi cần, hợp với chuỗi dài nhưng chỉ lấy vài phần tử.

**Ví dụ**
```swift
let orders = [("pho", 45_000), ("bun", 40_000), ("pho", 50_000)]
let revenue = orders.reduce(into: [String: Int]()) { totals, order in
    totals[order.0, default: 0] += order.1
}
// ["pho": 95000, "bun": 40000]

let firstBigSquare = (1...1_000_000).lazy.map { $0 * $0 }.first { $0 > 10_000 }
// chỉ tính 101 phần tử
```

**Bài tập:** Cho danh sách đơn hàng có ngày, món, số tiền. Không dùng vòng lặp `for`, tính: doanh thu theo ngày, món bán chạy nhất, các ngày doanh thu vượt 5 triệu. Đo thời gian với và không có `.lazy` cho câu "tìm đơn đầu tiên vượt 1 triệu" trên 1 triệu phần tử.

### Ngày 13 — Xử lý lỗi: `throws`, typed throws, `Result`

**Kiến thức**
- `throws` cho lỗi có thể phục hồi; `fatalError`/`precondition` cho lỗi lập trình.
- Swift 6 có typed throws: `func load() throws(NetworkError)`, người gọi biết chính xác loại lỗi. Dùng cho module nội bộ; API công khai thường vẫn để `throws` để dễ mở rộng.
- `Result` hữu ích khi lưu kết quả lại hoặc truyền qua callback; với `async` thì dùng `throws` trực tiếp.

**Ví dụ**
```swift
enum ValidationError: Error { case empty, tooShort(min: Int) }

func validate(password: String) throws(ValidationError) {
    if password.isEmpty { throw .empty }
    if password.count < 8 { throw .tooShort(min: 8) }
}

do {
    try validate(password: "123")
} catch {
    // `error` có kiểu ValidationError, switch đủ case không cần default
    switch error {
    case .empty: print("Nhập mật khẩu")
    case .tooShort(let min): print("Tối thiểu \(min) ký tự")
    }
}
```

**Bài tập:** Thiết kế `enum APIError` phân biệt: mất mạng, timeout, 401, 4xx khác, 5xx, lỗi decode. Viết hàm ánh xạ từ `URLError` và `HTTPURLResponse` sang `APIError`, và hàm chọn thông báo tiếng Việt cho người dùng. Lỗi nào nên cho phép "Thử lại"?

### Ngày 14 — Optional chuyên sâu

**Kiến thức**
- `Optional` là enum `.none` / `.some(Wrapped)`. Mọi cú pháp (`?`, `!`, `??`) chỉ là đường tắt.
- `if let name { }` (Swift 5.7), `guard let ... else { return }` để thoát sớm.
- `map`/`flatMap` trên Optional thay cho `if let` lồng nhau.
- Tránh `!` trừ khi chứng minh được không bao giờ nil (ví dụ `URL(string: "hằng số đúng")!`).

**Ví dụ**
```swift
struct Profile { var nickname: String?; var fullName: String }

func displayName(_ p: Profile?) -> String {
    guard let p else { return "Khách" }
    return p.nickname.map { "@\($0)" } ?? p.fullName
}

let age = Int("abc")          // nil, không crash
let doubled = age.map { $0 * 2 } ?? 0
```

**Bài tập:** Refactor một đoạn code có 4 cấp `if let` lồng nhau (đọc user → address → city → tên tỉnh) thành một dòng optional chaining và một phiên bản `guard`. Liệt kê 3 chỗ trong dự án của bạn đang dùng `!` và đề xuất cách bỏ.

### Ngày 15 — Thực hành tuần 3

**Bài tập:** Viết parser cho file JSON danh sách sản phẩm (tự soạn 20 mục) có trường thiếu, sai kiểu, giá dạng chuỗi `"45.000đ"`. Yêu cầu: sản phẩm lỗi không làm hỏng cả danh sách; trả về `(products: [Product], errors: [ParseError])` với thông tin mục nào lỗi vì sao. Viết test cho từng loại lỗi.

---

## Tuần 4 · Codable và tính năng ngôn ngữ nâng cao

### Ngày 16 — Codable nâng cao

**Kiến thức**
- `CodingKeys` đổi tên trường; `keyDecodingStrategy = .convertFromSnakeCase`.
- `init(from:)` tuỳ chỉnh khi JSON không khớp model: trường lồng nhau, kiểu thay đổi, giá trị mặc định.
- `dateDecodingStrategy`: `.iso8601`, `.secondsSince1970`, hoặc `.custom`.

**Ví dụ**
```swift
struct Product: Decodable {
    let id: Int
    let name: String
    let price: Decimal
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey { case id, name, price, stock }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        price = try c.decodeIfPresent(Decimal.self, forKey: .price) ?? 0
        isAvailable = (try c.decodeIfPresent(Int.self, forKey: .stock) ?? 0) > 0
    }
}
```

**Bài tập:** API trả `{"data": {"items": [...], "next_cursor": "abc"}, "meta": {...}}`. Viết `struct Page<Item: Decodable>: Decodable` giải mã thẳng `items` và `nextCursor`, bỏ qua `meta`. Viết `@propertyWrapper DefaultEmpty` để mảng thiếu trường thì thành `[]` (gợi ý cho ngày 17).

### Ngày 17 — Property wrapper

**Kiến thức**
- Property wrapper đóng gói logic lặp lại quanh một property: `wrappedValue`, `projectedValue` (truy cập bằng `$`).
- SwiftUI dùng rất nhiều: `@State`, `@Binding`, `@Environment`. Hiểu cách chúng hoạt động giúp tránh dùng sai.
- Không lạm dụng: wrapper che logic, đọc code khó hơn.

**Ví dụ**
```swift
@propertyWrapper
struct Clamped<Value: Comparable> {
    private var value: Value
    let range: ClosedRange<Value>
    init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }
    var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

struct Player { @Clamped(0...100) var volume = 50 }
var p = Player(); p.volume = 140   // 100
```

**Bài tập:** Viết `@UserDefault("key", default: false) var hasSeenOnboarding: Bool` lưu vào `UserDefaults`, có `projectedValue` trả về hàm `reset()`. Viết test dùng `UserDefaults(suiteName:)` riêng để không đụng dữ liệu thật.

### Ngày 18 — Result builder

**Kiến thức**
- Result builder biến một khối câu lệnh thành một giá trị: đây là cách `ViewBuilder` của SwiftUI hoạt động.
- Các hàm chính: `buildBlock`, `buildOptional` (cho `if`), `buildEither` (cho `if/else`), `buildArray` (cho `for`).

**Ví dụ**
```swift
@resultBuilder
enum QueryBuilder {
    // Mọi thành phần đều là [String] để if/else ghép lại dễ dàng.
    static func buildExpression(_ part: String) -> [String] { [part] }
    static func buildBlock(_ parts: [String]...) -> [String] { parts.flatMap { $0 } }
    static func buildOptional(_ part: [String]?) -> [String] { part ?? [] }
    static func buildEither(first part: [String]) -> [String] { part }
    static func buildEither(second part: [String]) -> [String] { part }
}

func query(@QueryBuilder _ build: () -> [String]) -> String {
    build().joined(separator: "&")
}

let onlyAvailable = true
let q = query {
    "q=pho"
    "page=1"
    if onlyAvailable { "available=1" }
}
// "q=pho&page=1&available=1"
```

**Bài tập:** Viết một `@resultBuilder` tên `AttributedTextBuilder` cho phép viết:
```swift
let text = attributed {
    Bold("Giá: ")
    Plain("45.000đ")
    if onSale { Colored("-20%", .red) }
}
```
và trả về `AttributedString`.

### Ngày 19 — Macro: dùng và hiểu

**Kiến thức**
- Macro sinh code lúc biên dịch: `@Observable`, `#Preview`, `#expect`, `@Model`. Bấm chuột phải → *Expand Macro* để xem code được sinh.
- Hai loại: freestanding (`#stringify(x)`) và attached (`@Observable` gắn vào khai báo).
- Viết macro cần package riêng dùng SwiftSyntax. Với 1–2 năm kinh nghiệm, ưu tiên *đọc hiểu* code macro sinh ra.

**Ví dụ**
```swift
import Observation

@Observable
final class Counter {
    var value = 0
}
// Expand Macro sẽ thấy: biến `value` được bọc bằng access/withMutation
// của ObservationRegistrar để SwiftUI biết view nào đọc property nào.
```

**Bài tập:** Mở *Expand Macro* cho một class `@Observable` có 2 property và một `@ObservationIgnored`. Viết lại bằng tay (không dùng macro) phiên bản tương đương ở mức ý tưởng, và giải thích vì sao view chỉ cập nhật khi property mà nó đọc thay đổi.

### Ngày 20 — Thực hành và kiểm tra tháng 1

**Bài tập:** Hoàn thiện `Cache<Key, Value>` của Ngày 10: thêm giới hạn theo "chi phí" (ví dụ số byte), loại phần tử ít dùng gần đây nhất (LRU), `subscript` đọc không làm đổi thứ tự (`peek`). Viết README ngắn giải thích thiết kế. Tự làm lại phần trắc nghiệm của bài kiểm tra năng lực (câu 1–3) và ghi điểm.

**Tự đánh giá:** giải thích được cho người khác, không nhìn tài liệu:
- Khi nào chọn `struct`, khi nào chọn `class`.
- Copy-on-write hoạt động thế nào.
- `some` khác `any` ở đâu, chi phí của `any`.
- Bẫy static dispatch trong protocol extension.
