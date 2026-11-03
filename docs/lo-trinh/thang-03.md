# Tháng 3 — SwiftUI vững

**Mục tiêu:** hiểu SwiftUI ở mức "vì sao view này render lại", làm chủ data flow, layout và điều hướng; kết hợp được với UIKit.
**Đầu ra cuối tháng:** Mốc dự án **M1** (danh sách + chi tiết bằng SwiftUI, model generic, không leak) và bài kiểm tra năng lực **lần 1**.

[← Tháng 2](thang-02.md) · [Mục lục](../../README.md) · [Tháng 4 →](thang-04.md)

---

## Tuần 1 · Bản chất của View

### Ngày 1 — View là giá trị, modifier là lớp bọc

**Kiến thức**
- `View` là struct nhẹ, mô tả giao diện. SwiftUI tạo lại struct thường xuyên; tạo lại struct **không** có nghĩa là vẽ lại màn hình.
- Mỗi modifier bọc view trong một view mới, nên **thứ tự modifier quan trọng**.
- `body` phải rẻ: không gọi mạng, không tính toán nặng, không tạo object trong `body`.

**Ví dụ**
```swift
Text("Phở bò")
    .padding()
    .background(.yellow)     // nền phủ cả phần padding

Text("Phở bò")
    .background(.yellow)     // nền chỉ ôm chữ
    .padding()
```

**Bài tập:** Viết 5 cặp modifier mà đổi thứ tự cho kết quả khác nhau (`padding`/`background`, `frame`/`border`, `offset`/`background`, `clipShape`/`shadow`, `font` trên `VStack` và trên `Text`). Chụp ảnh từng cặp và giải thích bằng mô hình "lớp bọc".

### Ngày 2 — Identity và lifetime

**Kiến thức**
- Mỗi view có identity. **Structural identity**: vị trí trong cây (nhánh `if` này khác nhánh `else`). **Explicit identity**: `.id(...)`, `ForEach` theo `id`.
- State (`@State`) sống theo identity. Đổi identity = view mới = state bị reset, animation chuyển tiếp mất.
- `if/else` tạo hai view khác identity. Muốn cùng view chỉ đổi thuộc tính thì dùng modifier có điều kiện giá trị (`.opacity(isOn ? 1 : 0)`).

**Ví dụ**
```swift
// Hai identity khác nhau: chuyển trạng thái là huỷ view cũ, tạo view mới
if isFavorite { HeartView(filled: true) } else { HeartView(filled: false) }

// Một identity: animate mượt, state bên trong HeartView được giữ
HeartView(filled: isFavorite)
```

**Bài tập:** Tạo một `CounterView` có `@State var count`. Đặt nó trong 3 tình huống: trong `if/else`, gắn `.id(UUID())`, gắn `.id(selectedTab)`. Ghi lại khi nào `count` bị reset. Dùng `let _ = Self._printChanges()` trong `body` để quan sát.

### Ngày 3 — `@State` và `@Binding`

**Kiến thức**
- `@State`: view *sở hữu* dữ liệu, chỉ dùng cho state cục bộ, luôn `private`.
- `@Binding`: view *mượn* quyền đọc/ghi state của view cha.
- Không khởi tạo `@State` từ tham số rồi mong nó cập nhật theo cha: `@State` chỉ lấy giá trị đầu tiên.

**Ví dụ**
```swift
struct QuantityStepper: View {
    @Binding var quantity: Int
    var body: some View {
        HStack {
            Button("−") { quantity = max(1, quantity - 1) }
            Text("\(quantity)").monospacedDigit()
            Button("+") { quantity += 1 }
        }
    }
}

struct CartRow: View {
    @State private var quantity = 1
    var body: some View { QuantityStepper(quantity: $quantity) }
}
```

**Bài tập:** Viết form chọn món có size (S/M/L), số lượng, ghi chú. Mỗi phần là một view con nhận `@Binding`. Tổng tiền ở view cha cập nhật tức thì. Cố tình viết lỗi "`@State` khởi tạo từ tham số" và mô tả triệu chứng.

### Ngày 4 — `@Observable`, `@Bindable`, `@Environment`

**Kiến thức**
- `@Observable` (iOS 17): view chỉ cập nhật khi property **mà body đọc** thay đổi. Thay thế `ObservableObject` + `@Published`.
- Sở hữu model `@Observable` trong view: `@State private var model = Model()`. Nhận từ ngoài: `let model` hoặc `@Bindable var model` khi cần `$model.name`.
- `@Environment(Model.self)` để truyền model xuống nhiều tầng mà không truyền tay.

**Ví dụ**
```swift
@Observable
final class CartModel {
    var items: [CartItem] = []
    var coupon = ""
    var total: Decimal { items.reduce(0) { $0 + $1.price * Decimal($1.quantity) } }
}

struct CouponField: View {
    @Bindable var cart: CartModel
    var body: some View { TextField("Mã giảm giá", text: $cart.coupon) }
}

struct CartBadge: View {
    @Environment(CartModel.self) private var cart
    var body: some View { Text("\(cart.items.count)") }   // không render lại khi coupon đổi
}
```

**Bài tập:** Chuyển một màn hình dùng `ObservableObject` + `@Published` sang `@Observable`. Dùng `Self._printChanges()` đếm số lần render của 3 view con trước và sau khi chuyển khi người dùng gõ vào ô mã giảm giá.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Form đăng ký tài khoản: họ tên, email, mật khẩu (hiện độ mạnh), xác nhận mật khẩu, ngày sinh, đồng ý điều khoản. Kiểm tra hợp lệ theo thời gian thực, nút Đăng ký chỉ bật khi hợp lệ, lỗi hiện dưới từng ô sau khi người dùng rời ô. Model là một class `@Observable`, validation là hàm thuần có test.

---

## Tuần 2 · Layout

### Ngày 6 — Quy trình layout của SwiftUI

**Kiến thức**
- Ba bước: cha *đề xuất* kích thước → con *chọn* kích thước của mình → cha *đặt* con vào vị trí.
- `frame(width:height:)` tạo khung đề xuất cố định; `frame(maxWidth: .infinity)` cho phép giãn.
- `fixedSize()` bỏ qua đề xuất, dùng kích thước lý tưởng. `layoutPriority` quyết định ai được chỗ trước.

**Ví dụ**
```swift
HStack {
    Text("Bún bò Huế đặc biệt nhiều chả").lineLimit(1)
    Spacer()
    Text("65.000đ").layoutPriority(1)   // giá không bao giờ bị cắt
}
```

**Bài tập:** Thêm `.border(.red)` vào mọi view để thấy kích thước thật. Giải thích bằng 3 bước layout vì sao `Text` trong `HStack` bị cắt, vì sao `Image` không resize khi thiếu `.resizable()`, và `Color.red` chiếm hết chỗ.

### Ngày 7 — Stack, Grid, ViewThatFits

**Kiến thức**
- `LazyVStack`/`LazyVGrid` chỉ tạo view khi sắp hiện, dùng cho danh sách dài trong `ScrollView`.
- `Grid` + `GridRow` cho bảng căn cột (không lazy).
- `ViewThatFits` chọn view đầu tiên vừa chỗ: ngang trên iPad, dọc trên iPhone nhỏ.

**Ví dụ**
```swift
ViewThatFits(in: .horizontal) {
    HStack { actionButtons }
    VStack { actionButtons }
}

LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
    ForEach(products) { ProductCard(product: $0) }
}
```

**Bài tập:** Dựng lưới sản phẩm tự đổi số cột theo chiều rộng (iPhone dọc 2 cột, ngang 3, iPad 4–5) chỉ bằng `.adaptive`. Thêm bảng thông số kỹ thuật dùng `Grid` căn thẳng cột nhãn và giá trị.

### Ngày 8 — Tự viết `Layout`

**Kiến thức**
- Protocol `Layout` (iOS 16) cho layout tuỳ biến: `sizeThatFits(proposal:subviews:cache:)` và `placeSubviews(in:proposal:subviews:cache:)`.
- Dùng khi stack và grid không đủ: tag xuống dòng, layout xoay vòng, masonry.

**Ví dụ**
```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
```

**Bài tập:** Dùng `FlowLayout` làm bộ chọn sở thích (tag bấm được). Viết thêm `RadialLayout` xếp các nút quanh một vòng tròn, có animation khi thêm/bớt nút.

### Ngày 9 — GeometryReader, containerRelativeFrame và Liquid Glass

**Kiến thức**
- `GeometryReader` chiếm hết chỗ được đề xuất, dễ phá layout. Ưu tiên `containerRelativeFrame` (iOS 17), `onGeometryChange` (iOS 18) hoặc `visualEffect`.
- `scrollTargetBehavior(.paging)` / `.viewAligned` cho carousel không cần GeometryReader.
- Liquid Glass (iOS 26+): thanh điều hướng, tab bar, toolbar hệ thống tự dùng. View tuỳ biến dùng `.glassEffect()`, nhóm nhiều phần tử trong `GlassEffectContainer`, nút dùng `.buttonStyle(.glass)`. Đặt glass trên nội dung, không chồng glass lên glass.

**Ví dụ**
```swift
ScrollView(.horizontal) {
    LazyHStack(spacing: 12) {
        ForEach(banners) { banner in
            BannerView(banner: banner)
                .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)

// Nút nổi trên bản đồ
Button("Đặt xe", systemImage: "car.fill") { book() }
    .buttonStyle(.glass)
```

**Bài tập:** Dựng carousel banner phân trang có chấm chỉ vị trí trang, không dùng `GeometryReader`. Thêm thanh công cụ nổi kiểu Liquid Glass ở cuối màn hình bản đồ với 3 nút trong một `GlassEffectContainer`. Kiểm tra độ đọc được khi nền phía sau là ảnh nhiều chi tiết.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Dashboard dạng bento cho app tập gym: ô lớn "Buổi tập hôm nay", 2 ô nhỏ (calo, phút tập), ô rộng biểu đồ tuần, ô danh sách bài tập gợi ý. Layout đổi hợp lý giữa iPhone dọc, iPhone ngang, iPad. Dùng `Grid`, `ViewThatFits` hoặc `Layout` tuỳ chỗ; không dùng `GeometryReader`.

---

## Tuần 3 · Điều hướng và luồng dữ liệu

### Ngày 11 — NavigationStack theo dữ liệu

**Kiến thức**
- `NavigationStack(path:)` với `NavigationPath` hoặc mảng kiểu riêng: điều hướng = sửa mảng.
- `.navigationDestination(for: Type.self)` khai báo màn hình cho từng loại giá trị.
- Deep link: phân tích URL thành mảng route rồi gán vào `path`.

**Ví dụ**
```swift
enum Route: Hashable { case restaurant(Restaurant.ID), dish(Dish.ID), checkout }

struct RootView: View {
    @State private var path: [Route] = []
    var body: some View {
        NavigationStack(path: $path) {
            HomeView(open: { path.append($0) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .restaurant(let id): RestaurantView(id: id)
                    case .dish(let id): DishView(id: id)
                    case .checkout: CheckoutView(onDone: { path.removeAll() })
                    }
                }
        }
        .onOpenURL { url in path = Route.parse(url) }
    }
}
```

**Bài tập:** Cài `Route.parse(_ url: URL) -> [Route]` cho các URL `myapp://restaurant/12/dish/7` và `myapp://checkout`. Viết test cho 5 URL hợp lệ và 3 URL sai. Thêm nút "Về trang chủ" ở màn Checkout xoá toàn bộ path.

### Ngày 12 — Sheet, fullScreenCover, alert, detents

**Kiến thức**
- `.sheet(item:)` an toàn hơn `.sheet(isPresented:)` khi nội dung phụ thuộc dữ liệu được chọn.
- `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)`.
- `.alert` / `.confirmationDialog` cho lựa chọn nguy hiểm (xoá), có `role: .destructive`.

**Ví dụ**
```swift
@State private var editingAddress: Address?

List(addresses) { address in
    Button(address.label) { editingAddress = address }
}
.sheet(item: $editingAddress) { address in
    AddressEditor(address: address)
        .presentationDetents([.medium, .large])
}
```

**Bài tập:** Màn hình Sổ địa chỉ: thêm (sheet `.large`), sửa (sheet theo item), xoá (confirmation dialog), chọn làm mặc định. Giải thích lỗi "sheet hiển thị dữ liệu của mục trước" khi dùng `isPresented` + biến chọn riêng.

### Ngày 13 — List, ForEach và hiệu năng danh sách

**Kiến thức**
- `ForEach` cần id **ổn định và duy nhất**. Dùng `\.self` với mảng có phần tử trùng hoặc dùng chỉ số làm id là nguồn bug khi xoá/sắp xếp.
- `List` tái sử dụng hàng như `UITableView`; `LazyVStack` trong `ScrollView` linh hoạt hơn về giao diện.
- Tránh lọc/sắp xếp trong `body`; tính sẵn trong model.

**Ví dụ**
```swift
// Sai: xoá phần tử giữa làm state của hàng bị lệch
ForEach(items.indices, id: \.self) { i in ItemRow(item: items[i]) }

// Đúng
ForEach(items) { item in ItemRow(item: item) }
    .onDelete { items.remove(atOffsets: $0) }
    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
```

**Bài tập:** Tạo danh sách 10.000 liên hệ có tìm kiếm (`.searchable`) và chia section theo chữ cái đầu. Đo bằng Instruments (SwiftUI template) số lần cập nhật view khi gõ tìm kiếm; tối ưu để chỉ hàng thay đổi mới cập nhật.

### Ngày 14 — `.task`, `.task(id:)`, `onChange`

**Kiến thức**
- `.task { }` chạy khi view xuất hiện, **tự huỷ** khi view biến mất. Thay cho `onAppear { Task { } }`.
- `.task(id: value)` huỷ task cũ và chạy lại khi `value` đổi: rất hợp cho tìm kiếm, chuyển tab.
- `onChange(of:)` cho phản ứng đồng bộ khi giá trị đổi.

**Ví dụ**
```swift
struct SearchView: View {
    @State private var query = ""
    @State private var results: [String] = []
    let api: any SearchAPI

    var body: some View {
        List(results, id: \.self) { Text($0) }
            .searchable(text: $query)
            .task(id: query) {
                guard !query.isEmpty else { results = []; return }
                try? await Task.sleep(for: .milliseconds(300))   // debounce, bị huỷ khi gõ tiếp
                guard !Task.isCancelled else { return }
                results = (try? await api.search(query)) ?? []
            }
    }
}
```

**Bài tập:** Viết màn hình chi tiết nhà hàng tải dữ liệu bằng `.task`, có tab Thực đơn/Đánh giá dùng `.task(id: selectedTab)`. Kiểm tra bằng log: rời màn hình giữa lúc tải thì request bị huỷ. Đọc trước Bài 3 trong `BAI_KIEM_TRA.md` và liệt kê những gì `.task(id:)` chưa giải quyết.

### Ngày 15 — Thực hành tuần 3

**Bài tập:** App đọc tin tức: danh sách bài theo chuyên mục (tab ngang), chi tiết bài, lưu bài để đọc sau, chia sẻ, deep link `news://article/123`. Có trạng thái loading / rỗng / lỗi có nút thử lại, kéo để làm mới (`.refreshable`). Dữ liệu từ một JSON tĩnh trong bundle qua một `protocol NewsService`.

---

## Tuần 4 · Animation, interop và hoàn thiện

### Ngày 16 — Animation và transition

**Kiến thức**
- Animation ngầm `.animation(.spring, value: x)` gắn với một giá trị; animation tường minh `withAnimation { }`.
- `.transition(.move(edge:).combined(with: .opacity))` cho view xuất hiện/biến mất.
- `matchedGeometryEffect` chuyển mượt một phần tử giữa hai vị trí; `PhaseAnimator`, `KeyframeAnimator` cho animation nhiều bước.

**Ví dụ**
```swift
@Namespace private var ns
@State private var expanded = false

VStack {
    if expanded {
        Image("dish").resizable().matchedGeometryEffect(id: "photo", in: ns).frame(height: 300)
    } else {
        Image("dish").resizable().matchedGeometryEffect(id: "photo", in: ns).frame(width: 80, height: 80)
    }
}
.onTapGesture { withAnimation(.spring(duration: 0.4)) { expanded.toggle() } }
```

**Bài tập:** Làm hiệu ứng "thêm vào giỏ": ảnh món bay từ thẻ sản phẩm vào biểu tượng giỏ hàng, số trên giỏ nảy lên. Tôn trọng cài đặt Reduce Motion (`@Environment(\.accessibilityReduceMotion)`).

### Ngày 17 — Dùng UIKit trong SwiftUI

**Kiến thức**
- `UIViewRepresentable`: `makeUIView`, `updateUIView` (gọi mỗi khi state SwiftUI đổi), `Coordinator` cho delegate.
- `updateUIView` phải tránh vòng lặp cập nhật: chỉ gán khi giá trị thực sự khác.
- `UIViewControllerRepresentable` cho controller như `PHPickerViewController`.

**Ví dụ**
```swift
struct MapPreview: UIViewRepresentable {
    var coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        guard map.centerCoordinate.latitude != coordinate.latitude
                || map.centerCoordinate.longitude != coordinate.longitude else { return }
        map.setRegion(.init(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500),
                      animated: true)
    }
}
```

**Bài tập:** Bọc `UITextView` thành `RichTextEditor` hỗ trợ `@Binding var text`, đặt placeholder, tự co chiều cao theo nội dung. Bọc `PHPickerViewController` chọn tối đa 4 ảnh. Kiểm tra con trỏ không nhảy về cuối khi gõ ở giữa đoạn.

### Ngày 18 — Dùng SwiftUI trong app UIKit

**Kiến thức**
- `UIHostingController(rootView:)` nhúng màn hình SwiftUI vào app UIKit; dùng làm child controller để nhúng một phần màn hình.
- `UIHostingConfiguration` (iOS 16) viết nội dung cell bằng SwiftUI trong `UICollectionView`.
- Truyền dữ liệu bằng model `@Observable` dùng chung; truyền sự kiện ra ngoài bằng closure.

**Ví dụ**
```swift
cell.contentConfiguration = UIHostingConfiguration {
    HStack {
        AsyncImage(url: product.imageURL) { $0.resizable() } placeholder: { Color.gray.opacity(0.2) }
            .frame(width: 56, height: 56).clipShape(.rect(cornerRadius: 8))
        VStack(alignment: .leading) {
            Text(product.name).font(.headline)
            Text(product.price, format: .currency(code: "VND")).foregroundStyle(.secondary)
        }
    }
}
.margins(.horizontal, 16)
```

**Bài tập:** Lấy app UIKit của Tháng 2, viết lại màn Giỏ hàng bằng SwiftUI và nhúng bằng `UIHostingController`. Coordinator UIKit vẫn điều hướng. Chuyển cell sản phẩm sang `UIHostingConfiguration`. So sánh số dòng code và nêu 2 điểm khó.

### Ngày 19 — Preview, Accessibility trong SwiftUI

**Kiến thức**
- `#Preview` nhiều trạng thái (rỗng, lỗi, dữ liệu dài), kèm `.environment(\.dynamicTypeSize, .accessibility3)` và dark mode.
- `@Previewable @State` (iOS 18) dùng state ngay trong preview.
- Accessibility: `.accessibilityLabel`, `.accessibilityElement(children: .combine)`, `.accessibilityAction`, `.accessibilityValue`.

**Ví dụ**
```swift
#Preview("Giỏ hàng – chữ lớn, tối") {
    @Previewable @State var cart = CartModel.sample
    CartView()
        .environment(cart)
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}

ProductCard(product: p)
    .accessibilityElement(children: .combine)
    .accessibilityAction(named: "Thêm vào giỏ") { cart.add(p) }
```

**Bài tập:** Viết preview cho 6 trạng thái của màn hình chính trong dự án của bạn. Chạy Accessibility Inspector → Audit trên màn hình đó, sửa hết cảnh báo.

### Ngày 20 — Mốc M1 và kiểm tra lần 1

**Bài tập (Mốc M1 của dự án xuyên suốt):** Chọn một app cho cả năm (gợi ý: app theo dõi tập luyện hoặc thói quen). Hoàn thành:
- Danh sách + chi tiết bằng SwiftUI, điều hướng theo dữ liệu, deep link.
- Model dùng generic `Cache` của Tháng 1 và `LoadState` enum.
- Ít nhất 1 màn hình UIKit nhúng hoặc được nhúng.
- Memory Graph sạch sau 10 lần mở/đóng màn chi tiết.

**Kiểm tra lần 1:** làm lại Phần A (15 câu trắc nghiệm) của bài kiểm tra năng lực, mục tiêu ≥ 70% phần Swift + Memory + UI. Ghi điểm vào bảng tiến độ trong README.
