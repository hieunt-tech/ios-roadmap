# Tháng 2 — Memory và UIKit vững

**Mục tiêu:** không còn viết retain cycle, dựng được màn hình UIKit phức tạp bằng code mà không cần thử-sai Auto Layout.
**Đầu ra cuối tháng:** một app UIKit 3 màn hình (danh sách, chi tiết, form) dựng hoàn toàn bằng code, không leak (kiểm bằng Memory Graph).

[← Tháng 1](thang-01.md) · [Mục lục](../../README.md) · [Tháng 3 →](thang-03.md)

---

## Tuần 1 · ARC và retain cycle

### Ngày 1 — ARC hoạt động thế nào

**Kiến thức**
- ARC đếm số tham chiếu mạnh tới mỗi object. Về 0 thì object bị giải phóng và `deinit` chạy ngay.
- ARC chạy lúc biên dịch (chèn retain/release), không có garbage collector chạy nền như Java.
- Value type (struct, enum) không được đếm tham chiếu, trừ khi chứa class bên trong.

**Ví dụ**
```swift
final class Screen {
    let name: String
    init(name: String) { self.name = name; print("init \(name)") }
    deinit { print("deinit \(name)") }
}

var home: Screen? = Screen(name: "Home")   // count = 1
var alias = home                            // count = 2
home = nil                                  // count = 1
alias = nil                                 // count = 0 → "deinit Home"
```

**Bài tập:** Thêm `deinit { print(...) }` vào 5 ViewController trong một dự án bạn đang có. Mở rồi đóng từng màn hình, ghi lại màn hình nào không in `deinit`. Đó là danh sách nghi vấn leak cho cả tuần.

### Ngày 2 — strong, weak, unowned

**Kiến thức**
- `weak`: không giữ object, luôn là optional, tự thành `nil` khi object chết. Dùng khi object kia có thể chết trước.
- `unowned`: không giữ object, không optional; truy cập sau khi object chết sẽ crash. Chỉ dùng khi chứng minh được object kia sống lâu hơn (ví dụ `Customer` và `CreditCard` của nó).
- Quy tắc an toàn: phân vân thì dùng `weak`.

**Ví dụ**
```swift
final class Customer {
    let name: String
    var card: CreditCard?
    init(name: String) { self.name = name }
}
final class CreditCard {
    let number: String
    unowned let owner: Customer      // thẻ không tồn tại khi không có chủ
    init(number: String, owner: Customer) { self.number = number; self.owner = owner }
}
```

**Bài tập:** Mô hình `Teacher` – `Classroom` – `Student` với quan hệ hai chiều. Chọn `strong`/`weak`/`unowned` cho từng chiều và giải thích. Viết test chứng minh cả cụm được giải phóng khi `Classroom` bị bỏ.

### Ngày 3 — Retain cycle trong closure

**Kiến thức**
- Object giữ closure (lưu vào property), closure bắt `self` mạnh → vòng tròn, không ai về 0.
- `[weak self]` + `guard let self else { return }` là mẫu chuẩn.
- Closure không escaping (`map`, `forEach`, `UIView.animate`) không gây cycle vì không được lưu lại.

**Ví dụ**
```swift
final class ProfileViewModel {
    var onUpdate: (() -> Void)?
    private var name = ""

    func bind(service: ProfileService) {
        service.observe { [weak self] newName in
            guard let self else { return }
            self.name = newName
            self.onUpdate?()
        }
    }
}
```

**Bài tập:** Viết một `ImageDownloader` có `completion` được lưu lại, và một `ViewController` dùng nó theo cách gây leak. Chứng minh leak bằng `deinit` không chạy, rồi sửa. Giải thích vì sao `UIView.animate(withDuration:) { self.view.alpha = 0 }` không cần `[weak self]`.

### Ngày 4 — Các nguồn leak khác: delegate, Timer, NotificationCenter

**Kiến thức**
- Delegate phải là `weak var delegate: SomeDelegate?` với `protocol SomeDelegate: AnyObject`.
- `Timer.scheduledTimer(... repeats: true)` bị run loop giữ; closure hoặc target bắt `self` thì VC sống mãi. Phải `invalidate()`.
- `NotificationCenter.addObserver(forName:object:queue:using:)` trả về token, phải giữ token và `removeObserver`. Bản async `for await _ in NotificationCenter.default.notifications(named:)` cũng giữ `self` nếu Task không bị huỷ.

**Ví dụ**
```swift
final class CountdownViewController: UIViewController {
    private var timer: Timer?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func tick() { /* ... */ }
}
```

**Bài tập:** Viết một màn hình có cả 3 nguồn leak (delegate strong, Timer, Notification observer). Dùng Debug Memory Graph (nút ba vòng tròn trong thanh debug của Xcode) để chụp đồ thị tham chiếu của từng leak, rồi sửa từng cái.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Làm "săn leak" có giới hạn thời gian 90 phút: tự viết (hoặc nhờ đồng nghiệp viết) một app nhỏ có 5 leak giấu kín (closure, delegate, Timer, NotificationCenter, Task bắt `self` trong `for await`). Tìm cả 5 chỉ bằng Memory Graph và Instruments → Leaks. Ghi lại cách phát hiện từng cái.

---

## Tuần 2 · Vòng đời ViewController và Auto Layout

### Ngày 6 — Vòng đời UIViewController

**Kiến thức**
- Thứ tự: `init` → `loadView` → `viewDidLoad` → `viewWillAppear` → `viewIsAppearing` (iOS 17, kích thước đã đúng) → `viewDidAppear` → `viewWillDisappear` → `viewDidDisappear`.
- `viewDidLoad` chỉ chạy một lần: dựng view, đăng ký cell. Cập nhật dữ liệu khi quay lại màn hình thì đặt ở `viewWillAppear`.
- Layout phụ thuộc kích thước (bo tròn theo chiều cao) đặt ở `viewDidLayoutSubviews` hoặc `viewIsAppearing`, không ở `viewDidLoad`.

**Ví dụ**
```swift
final class LifecycleViewController: UIViewController {
    override func loadView() { view = UIView(); view.backgroundColor = .systemBackground }
    override func viewDidLoad() { super.viewDidLoad(); print("viewDidLoad", view.bounds) }
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated); print("viewIsAppearing", view.bounds)
    }
}
```

**Bài tập:** In log mọi phương thức vòng đời của 2 VC trong một `UINavigationController`. Push, pop, present modal dạng `.pageSheet` và `.fullScreen`. Vẽ bảng thứ tự gọi cho từng trường hợp; ghi chú vì sao `.pageSheet` không gọi `viewWillDisappear` ở VC bên dưới.

### Ngày 7 — Auto Layout bằng code

**Kiến thức**
- Luôn đặt `translatesAutoresizingMaskIntoConstraints = false` khi tự thêm constraint.
- Dùng `NSLayoutConstraint.activate([...])` để kích hoạt hàng loạt.
- Priority (1–1000), `contentHuggingPriority` (không muốn to ra), `contentCompressionResistancePriority` (không muốn bị bóp nhỏ). Hai label cạnh nhau bị cắt chữ thường do hai giá trị này.

**Ví dụ**
```swift
let title = UILabel(); let price = UILabel()
[title, price].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
price.setContentCompressionResistancePriority(.required, for: .horizontal)
title.numberOfLines = 2

NSLayoutConstraint.activate([
    title.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
    title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
    price.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 8),
    price.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
    price.firstBaselineAnchor.constraint(equalTo: title.firstBaselineAnchor),
])
```

**Bài tập:** Dựng một hàng sản phẩm: ảnh vuông 64pt, tên (tối đa 2 dòng), giá luôn hiển thị đủ, nút "+" bên phải. Thử với tên rất dài và Dynamic Type cỡ lớn nhất. Không được có cảnh báo "Unable to simultaneously satisfy constraints" trong console.

### Ngày 8 — UIStackView và intrinsic content size

**Kiến thức**
- `UIStackView` tự tạo constraint cho các view con: `axis`, `spacing`, `alignment`, `distribution`.
- Intrinsic content size: kích thước tự nhiên của label, button, image view. Stack view dựa vào nó.
- View tự viết có kích thước tự nhiên thì override `intrinsicContentSize` và gọi `invalidateIntrinsicContentSize()` khi nội dung đổi.

**Ví dụ**
```swift
let stack = UIStackView(arrangedSubviews: [avatar, nameLabel, followButton])
stack.axis = .horizontal
stack.spacing = 12
stack.alignment = .center
stack.setCustomSpacing(24, after: nameLabel)
```

**Bài tập:** Viết `TagView` (nhãn bo tròn có padding) với `intrinsicContentSize` đúng, và một `TagListView` xếp tag xuống dòng khi hết chỗ (không dùng collection view). Kiểm tra với 30 tag độ dài khác nhau.

### Ngày 9 — Safe area, trait collection, dark mode

**Kiến thức**
- `safeAreaLayoutGuide` tránh notch, Dynamic Island, home indicator. `layoutMarginsGuide` thêm lề chuẩn.
- Màu động (`.label`, `.systemBackground`, màu trong Asset Catalog có biến thể Dark) tự đổi theo giao diện.
- iOS 17+: `registerForTraitChanges([UITraitUserInterfaceStyle.self]) { ... }` thay cho `traitCollectionDidChange`.

**Ví dụ**
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
        self.updateShadow()   // shadowColor là CGColor, không tự đổi theo dark mode
    }
}
```

**Bài tập:** Lấy màn hình Ngày 7, hỗ trợ đầy đủ dark mode (kể cả viền và bóng dùng `CGColor`), xoay ngang trên iPhone, và iPad ở chế độ Split View 1/3. Chụp 4 ảnh màn hình so sánh.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Dựng màn hình Hồ sơ người dùng bằng code: ảnh bìa co giãn khi kéo (stretchy header), avatar đè lên mép ảnh bìa, tên, bio nhiều dòng, 3 chỉ số (bài viết, người theo dõi, đang theo dõi), nút Theo dõi. Hỗ trợ dark mode, Dynamic Type, xoay màn hình. Không dùng Storyboard.

---

## Tuần 3 · Danh sách hiện đại trong UIKit

### Ngày 11 — Diffable data source

**Kiến thức**
- `UITableViewDiffableDataSource` / `UICollectionViewDiffableDataSource` quản lý dữ liệu bằng snapshot; tự tính khác biệt và animate.
- Item identifier phải `Hashable` và **ổn định** (dùng id, không dùng cả model nếu model thay đổi).
- Nội dung item đổi mà id giữ nguyên: dùng `snapshot.reconfigureItems(_:)` (iOS 15+).

**Ví dụ**
```swift
enum Section { case main }

private lazy var dataSource = UITableViewDiffableDataSource<Section, Product.ID>(
    tableView: tableView
) { [weak self] tableView, indexPath, id in
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    var content = cell.defaultContentConfiguration()
    content.text = self?.products[id]?.name
    cell.contentConfiguration = content
    return cell
}

func apply(_ items: [Product]) {
    var snapshot = NSDiffableDataSourceSnapshot<Section, Product.ID>()
    snapshot.appendSections([.main])
    snapshot.appendItems(items.map(\.id))
    dataSource.apply(snapshot, animatingDifferences: true)
}
```

**Bài tập:** Viết danh sách việc cần làm có thêm, xoá (vuốt), đánh dấu hoàn thành, sắp xếp lại. Dùng id làm item identifier. Giải thích lỗi crash "Fatal: supplied item identifiers are not unique" và cách tái hiện nó.

### Ngày 12 — Compositional layout

**Kiến thức**
- `UICollectionViewCompositionalLayout` mô tả layout bằng Item → Group → Section, mỗi section một kiểu.
- `orthogonalScrollingBehavior` cho section cuộn ngang trong danh sách dọc (kiểu App Store).
- Kích thước: `.fractionalWidth`, `.absolute`, `.estimated` (tự co theo nội dung).

**Ví dụ**
```swift
func carouselSection() -> NSCollectionLayoutSection {
    let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                        heightDimension: .fractionalHeight(1)))
    let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: .init(widthDimension: .fractionalWidth(0.8), heightDimension: .absolute(180)),
        subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.orthogonalScrollingBehavior = .groupPagingCentered
    section.interGroupSpacing = 12
    return section
}
```

**Bài tập:** Dựng trang chủ app đặt đồ ăn gồm 4 section: banner cuộn ngang có phân trang, lưới danh mục 4 cột, danh sách "Gần bạn" cuộn ngang, danh sách nhà hàng dọc. Mỗi section có header.

### Ngày 13 — Tái sử dụng cell, prefetch, tự co chiều cao

**Kiến thức**
- Cell được tái sử dụng: phải reset mọi trạng thái trong `prepareForReuse` (ảnh, task tải ảnh đang chạy).
- Lỗi kinh điển: ảnh tải xong hiển thị nhầm cell vì cell đã được dùng cho hàng khác.
- `prefetchDataSource` để tải trước dữ liệu/ảnh của hàng sắp hiện.

**Ví dụ**
```swift
final class ProductCell: UICollectionViewCell {
    private var imageTask: Task<Void, Never>?
    private var representedID: Product.ID?

    func configure(with product: Product, loader: ImageLoader) {
        representedID = product.id
        imageTask = Task { [weak self] in
            guard let data = try? await loader.image(for: product.imageURL) else { return }
            guard let self, self.representedID == product.id else { return }  // cell đã bị reuse?
            self.imageView.image = UIImage(data: data)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageView.image = nil
    }
}
```

**Bài tập:** Tạo danh sách 1.000 ảnh từ một API ảnh miễn phí. Cuộn thật nhanh và quay video màn hình để bắt lỗi ảnh nhảy nhầm cell. Sửa bằng `representedID` + huỷ task. Thêm prefetch và so sánh độ mượt.

### Ngày 14 — Cell registration và content configuration

**Kiến thức**
- `UICollectionView.CellRegistration` thay cho đăng ký bằng chuỗi identifier, an toàn kiểu.
- `UIListContentConfiguration` cho cell dạng danh sách chuẩn; `UIContentConfiguration` tự viết cho cell tuỳ biến, cập nhật theo trạng thái (selected, highlighted).
- `UICollectionLayoutListConfiguration` tạo danh sách kiểu Settings bằng collection view.

**Ví dụ**
```swift
let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Setting> { cell, _, setting in
    var content = cell.defaultContentConfiguration()
    content.text = setting.title
    content.image = UIImage(systemName: setting.icon)
    cell.contentConfiguration = content
    cell.accessories = [.disclosureIndicator()]
}
// trong data source:
// collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: setting)
```

**Bài tập:** Dựng màn hình Cài đặt giống app Settings: nhóm có header/footer, hàng có switch, hàng có giá trị bên phải, hàng mở màn hình con. Dùng list configuration + cell registration, không dùng `UITableView`.

### Ngày 15 — Thực hành tuần 3

**Bài tập:** Dựng feed mạng xã hội: bài viết có văn bản dài (gập/mở "Xem thêm"), 1–4 ảnh xếp lưới, nút thích có animation, kéo xuống để tải lại, cuộn tới cuối tự tải trang tiếp. Dùng diffable data source với `reconfigureItems` khi bấm thích (không reload cả danh sách).

---

## Tuần 4 · Điều hướng, vòng đời app và chất lượng

### Ngày 16 — Điều hướng và Coordinator cơ bản

**Kiến thức**
- `UINavigationController` (push/pop), present modal, `UITabBarController`.
- VC không nên biết VC tiếp theo là gì. Coordinator giữ logic điều hướng, VC chỉ báo sự kiện ("người dùng chọn sản phẩm X").
- Coordinator con phải được giải phóng khi luồng kết thúc, nếu không sẽ leak cả luồng.

**Ví dụ**
```swift
@MainActor
final class ProductCoordinator {
    private let navigation: UINavigationController
    init(navigation: UINavigationController) { self.navigation = navigation }

    func start() {
        let list = ProductListViewController()
        list.onSelect = { [weak self] product in self?.showDetail(product) }
        navigation.pushViewController(list, animated: false)
    }

    private func showDetail(_ product: Product) {
        navigation.pushViewController(ProductDetailViewController(product: product), animated: true)
    }
}
```

**Bài tập:** Viết `AppCoordinator` điều phối: chưa đăng nhập → luồng Onboarding (3 màn) → Đăng nhập; đã đăng nhập → Tab bar 3 tab. Đăng xuất phải đưa về Đăng nhập và giải phóng toàn bộ coordinator của tab (kiểm bằng `deinit`).

### Ngày 17 — Vòng đời app và Scene

**Kiến thức**
- Trạng thái: not running → inactive → active → background → suspended.
- `UISceneDelegate`: `sceneDidBecomeActive`, `sceneWillResignActive`, `sceneDidEnterBackground`. iPad có thể có nhiều scene (cửa sổ) cùng lúc.
- Vào background chỉ có vài giây: lưu dữ liệu, dừng timer, đóng kết nối không cần thiết.

**Ví dụ**
```swift
func sceneDidEnterBackground(_ scene: UIScene) {
    draftStore.saveNow()
    priceSocket.disconnect()
}

func sceneWillEnterForeground(_ scene: UIScene) {
    priceSocket.connectIfNeeded()
}
```

**Bài tập:** Viết app ghi chú lưu bản nháp khi vào background và khôi phục khi mở lại (kể cả khi bị hệ thống kill: dùng Xcode → Debug → Simulate Background Fetch hoặc dừng app từ Xcode khi đang ở background). Hỗ trợ 2 cửa sổ trên iPad, mỗi cửa sổ một ghi chú.

### Ngày 18 — Bàn phím và Accessibility cơ bản

**Kiến thức**
- iOS 15+: `view.keyboardLayoutGuide` để ghim view vào trên bàn phím, không cần lắng nghe notification.
- Dynamic Type: `UIFont.preferredFont(forTextStyle:)` + `adjustsFontForContentSizeCategory = true`.
- VoiceOver: `accessibilityLabel`, `accessibilityTraits`, `accessibilityValue`; gộp nhiều view thành một phần tử (`isAccessibilityElement = true` trên view cha).

**Ví dụ**
```swift
NSLayoutConstraint.activate([
    inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
])

priceLabel.font = .preferredFont(forTextStyle: .headline)
priceLabel.adjustsFontForContentSizeCategory = true
likeButton.accessibilityLabel = "Thích"
likeButton.accessibilityValue = isLiked ? "Đã thích" : "Chưa thích"
```

**Bài tập:** Dựng màn hình chat có ô nhập dính trên bàn phím, danh sách tin nhắn tự cuộn xuống cuối. Bật VoiceOver và dùng app chỉ bằng giọng đọc: gửi một tin, đọc 3 tin gần nhất. Ghi lại mọi chỗ VoiceOver đọc sai hoặc không đọc.

### Ngày 19 — Đa ngôn ngữ với String Catalog

**Kiến thức**
- String Catalog (`.xcstrings`) tự trích chuỗi từ code khi build. Dùng `String(localized:)` hoặc `LocalizedStringResource`.
- Số nhiều: biến thể theo số lượng ("1 món" / "3 món") cấu hình trong catalog.
- Không ghép chuỗi bằng `+`: thứ tự từ khác nhau giữa các ngôn ngữ. Dùng chuỗi có tham số.

**Ví dụ**
```swift
let count = 3
let title = String(localized: "\(count) items in cart",
                   comment: "Tiêu đề giỏ hàng, count là số món")
let price = 45_000.formatted(.currency(code: "VND"))
let date = Date.now.formatted(date: .abbreviated, time: .shortened)
```

**Bài tập:** Bản địa hoá app Ngày 16 sang tiếng Việt và tiếng Anh, có ít nhất 2 chuỗi số nhiều. Định dạng tiền và ngày theo locale. Chạy với ngôn ngữ giả "Double-Length Pseudolanguage" trong scheme để tìm chỗ bị cắt chữ.

### Ngày 20 — Thực hành và kiểm tra tháng 2

**Bài tập:** App UIKit 3 màn hình hoàn toàn bằng code: Danh sách sản phẩm (compositional layout, ảnh tải bất đồng bộ), Chi tiết (cuộn, ảnh lớn, nút thêm vào giỏ), Giỏ hàng (sửa số lượng, xoá, tổng tiền). Điều hướng bằng Coordinator. Yêu cầu nghiệm thu:
- Mọi VC và coordinator in `deinit` khi đóng.
- Memory Graph sạch sau 10 lần mở/đóng màn Chi tiết.
- Không có cảnh báo Auto Layout.
- Dùng được bằng VoiceOver và Dynamic Type lớn nhất.

**Tự đánh giá:** làm lại câu 4–5 của bài trắc nghiệm, và giải thích không nhìn tài liệu: vì sao Timer gây leak, khác biệt `weak`/`unowned`, cách chống ảnh nhảy nhầm cell.
