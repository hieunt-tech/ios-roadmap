# Tháng 9 — CI/CD và phát hành

**Mục tiêu:** tự đưa app từ commit tới tay người dùng: signing, TestFlight, pipeline tự động, theo dõi crash, phát hành an toàn.
**Đầu ra cuối tháng:** Mốc **M3** (mỗi PR tự chạy test, build tự lên TestFlight không cần thao tác tay) và bài kiểm tra năng lực **lần 3**.

[← Tháng 8](thang-08.md) · [Mục lục](../../README.md) · [Tháng 10 →](thang-10.md)

---

## Tuần 1 · Từ máy bạn tới TestFlight

### Ngày 1 — Code signing

**Kiến thức**
- Bốn thứ: **Certificate** (chứng minh bạn là ai), **App ID / Bundle ID**, **Device** (cho bản development/ad hoc), **Provisioning profile** (gói ba thứ trên + entitlements).
- Development vs Distribution. *Automatic signing* tiện cho cá nhân; team lớn thường dùng manual signing hoặc Fastlane `match` để mọi máy dùng chung chứng chỉ.
- Entitlements (Push, App Groups, Keychain Sharing) phải khớp giữa profile và file `.entitlements`, nếu không sẽ lỗi lúc build hoặc tính năng im lặng không chạy.

**Ví dụ (đọc thông tin profile để gỡ lỗi)**
```bash
security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/<uuid>.mobileprovision \
  | plutil -extract Entitlements xml1 -o - -
codesign -d --entitlements :- MyApp.app
```

**Bài tập:** Vẽ sơ đồ quan hệ certificate – App ID – profile – entitlements cho dự án của bạn. Cố tình gây 3 lỗi signing (sai bundle id, thiếu App Group trong profile, hết hạn certificate trên máy khác) và ghi lại thông báo lỗi + cách sửa.

### Ngày 2 — Build configuration và bí mật

**Kiến thức**
- Tách cấu hình bằng `.xcconfig` (Tháng 5, Ngày 17), mỗi môi trường một bundle id để cài song song.
- Không commit secret (API key bên thứ ba, khoá ký). Trên CI lấy từ biến môi trường bí mật; trên máy dev dùng file `.xcconfig` bị `.gitignore`.
- Mọi key nhúng trong app đều có thể bị trích xuất. Key thực sự bí mật phải nằm ở server.

**Ví dụ**
```
// Config/Secrets.xcconfig  (trong .gitignore)
MAPS_API_KEY = abc123

// Config/Base.xcconfig
#include? "Secrets.xcconfig"
MAPS_API_KEY = $(MAPS_API_KEY)
```

**Bài tập:** Rà repo của dự án tìm mọi secret đã từng được commit (`git log -p | grep -i "key\|secret\|token"`). Chuyển chúng ra `Secrets.xcconfig`, cung cấp `Secrets.example.xcconfig` cho người mới. Ghi chú key nào cần xoay vòng (đã lộ trong lịch sử git).

### Ngày 3 — Archive, TestFlight, App Store Connect

**Kiến thức**
- Product → Archive → Organizer → Distribute App → App Store Connect. Build xử lý xong (vài phút tới vài chục phút) mới hiện trong TestFlight.
- TestFlight: tester nội bộ (tối đa 100, không cần duyệt) và bên ngoài (cần Beta App Review lần đầu mỗi phiên bản).
- `CFBundleShortVersionString` (1.4.0, người dùng thấy) và `CFBundleVersion` (build number, phải tăng mỗi lần tải lên).

**Ví dụ**
```bash
xcodebuild -scheme Shop -configuration Release -archivePath build/Shop.xcarchive archive
# ExportOptions.plist có method = app-store-connect và destination = upload
# → xcodebuild tải thẳng lên App Store Connect bằng API key
xcodebuild -exportArchive -archivePath build/Shop.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

**Bài tập:** Đưa bản đầu tiên của dự án xuyên suốt lên TestFlight bằng tay qua Xcode, mời 2 tester nội bộ. Sau đó làm lại bằng dòng lệnh như ví dụ (dùng App Store Connect API key). Ghi lại mọi bước để tuần sau tự động hoá.

### Ngày 4 — Review guidelines và privacy manifest

**Kiến thức**
- Lý do bị từ chối hay gặp: app chưa hoàn chỉnh, thiếu tài khoản demo cho reviewer, tính năng thanh toán số không dùng In-App Purchase, xin quyền không rõ mục đích, thiếu nút xoá tài khoản (bắt buộc nếu có tạo tài khoản).
- **Privacy manifest** (`PrivacyInfo.xcprivacy`): khai báo dữ liệu thu thập và lý do dùng các "required reason API" (`UserDefaults`, thời gian khởi động hệ thống, dung lượng đĩa...). SDK bên thứ ba cũng phải có manifest.
- Privacy Nutrition Label trên App Store phải khớp với thực tế thu thập.

**Ví dụ (một mục trong PrivacyInfo.xcprivacy)**
```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>CA92.1</string></array>
  </dict>
</array>
```

**Bài tập:** Viết `PrivacyInfo.xcprivacy` đầy đủ cho dự án. Archive và đọc *Privacy Report* trong Organizer. Đọc App Review Guidelines mục 2, 3, 4, 5 và lập checklist 15 mục trước khi gửi duyệt.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Phát hành bản 0.1 của dự án xuyên suốt lên TestFlight cho tester bên ngoài (cần Beta App Review): có ghi chú "Có gì mới", tài khoản demo cho reviewer, privacy manifest, ảnh chụp màn hình. Ghi lại thời gian từ lúc tải lên tới lúc tester cài được.

---

## Tuần 2 · Pipeline tự động

### Ngày 6 — Xcode Cloud

**Kiến thức**
- CI/CD của Apple, cấu hình trong Xcode (Report navigator → Cloud). Workflow: điều kiện kích hoạt (PR, push nhánh, tag) → hành động (build, test, archive) → phân phối (TestFlight).
- Script tuỳ chỉnh: `ci_scripts/ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`.
- Biến môi trường bí mật cấu hình trên App Store Connect.

**Ví dụ**
```bash
#!/bin/sh
# ci_scripts/ci_post_clone.sh
set -e
# Tạo Secrets.xcconfig từ biến môi trường bí mật của Xcode Cloud
cat > "$CI_PRIMARY_REPOSITORY_PATH/Config/Secrets.xcconfig" <<EOF
MAPS_API_KEY = ${MAPS_API_KEY}
EOF
```

**Bài tập:** Tạo 2 workflow Xcode Cloud: "PR" (build + unit test khi có pull request) và "Beta" (archive + TestFlight khi merge vào `main`). Ghi lại thời gian chạy và số phút build miễn phí còn lại mỗi tháng.

### Ngày 7 — GitHub Actions với macOS runner

**Kiến thức**
- Runner `macos-15` (hoặc mới hơn) có sẵn Xcode; chọn phiên bản bằng `sudo xcode-select -s /Applications/Xcode_X.app`.
- Cache SwiftPM (`~/Library/Caches/org.swift.swiftpm`, `.build`) để giảm thời gian.
- Phút macOS tính phí cao hơn Linux: chạy những gì không cần simulator (`swift test` cho package thuần) càng nhanh càng rẻ.

**Ví dụ**
```yaml
name: PR
on: pull_request
jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: .build
          key: spm-${{ hashFiles('Package.resolved') }}
      - run: swift test --parallel
      - run: |
          xcodebuild test -scheme Shop \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -resultBundlePath TestResults.xcresult
```

**Bài tập:** Viết workflow GitHub Actions cho PR: chạy `swift test` cho các package, `xcodebuild test` cho app, đính kèm `.xcresult` khi thất bại. So sánh thời gian và chi phí với Xcode Cloud. Workflow mẫu: `.github/workflows/ci.yml` trong ConcurrencyLab.

### Ngày 8 — Fastlane

**Kiến thức**
- `match`: lưu certificate/profile mã hoá trong repo riêng, mọi máy và CI dùng chung.
- `gym` (build), `scan` (test), `pilot` (TestFlight), `deliver` (metadata App Store), `snapshot` (ảnh chụp màn hình tự động).
- `Fastfile` gom các bước thành lane: `fastlane beta`.

**Ví dụ**
```ruby
default_platform(:ios)

platform :ios do
  lane :beta do
    setup_ci if ENV["CI"]
    match(type: "appstore", readonly: true)
    increment_build_number(build_number: latest_testflight_build_number + 1)
    build_app(scheme: "Shop", export_method: "app-store")
    upload_to_testflight(skip_waiting_for_build_processing: true,
                         changelog: changelog_from_git_commits(merge_commit_filtering: "only_include_merges"))
  end
end
```

**Bài tập:** Cài Fastlane cho dự án, thiết lập `match` với một repo private, viết lane `test` và `beta`. Chạy `fastlane beta` từ máy sạch (hoặc CI) và xác nhận build mới xuất hiện trên TestFlight.

### Ngày 9 — Version và build number tự động

**Kiến thức**
- Build number phải tăng đơn điệu: lấy từ số lần chạy CI, hoặc từ TestFlight + 1, hoặc từ `git rev-list --count HEAD`.
- Version theo semantic versioning: MAJOR.MINOR.PATCH. Tag git `v1.4.0` khi phát hành.
- Ghi version và commit hash vào app (màn hình Giới thiệu) để đối chiếu khi người dùng báo lỗi.

**Ví dụ**
```bash
# Trong CI, trước khi build
BUILD_NUMBER=$(git rev-list --count HEAD)
agvtool new-version -all "$BUILD_NUMBER"
echo "GIT_SHA = $(git rev-parse --short HEAD)" > Config/BuildInfo.xcconfig
```

**Bài tập:** Tự động tăng build number trong pipeline; hiển thị "Phiên bản 1.4.0 (812) · a1b2c3d" trong màn Cài đặt. Viết quy ước version cho team: khi nào tăng MAJOR/MINOR/PATCH, ai tạo tag.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Pipeline PR hoàn chỉnh cho dự án xuyên suốt: mọi PR tự chạy build + unit test + SwiftLint (Ngày 14 nếu làm trước); merge chặn nếu đỏ (bật branch protection). Thời gian chạy dưới 15 phút.

---

## Tuần 3 · Theo dõi sau phát hành

### Ngày 11 — Crash report và symbolication

**Kiến thức**
- Crash log thô chỉ có địa chỉ bộ nhớ; cần file **dSYM** đúng build để dịch sang tên hàm và số dòng.
- Xcode Organizer → Crashes cho crash từ người dùng thật. Dịch vụ như Firebase Crashlytics, Sentry cần tải dSYM lên sau mỗi build.
- Đọc crash: loại exception (`EXC_BAD_ACCESS`, `EXC_BREAKPOINT` thường là `fatalError`/force unwrap/out of range), thread bị crash, vài frame đầu thuộc code của bạn.

**Ví dụ**
```
Exception Type:  EXC_BREAKPOINT (SIGTRAP)
Thread 0 Crashed:
0  Shop   CartViewModel.removeItem(at:) + 132 (CartViewModel.swift:58)
1  Shop   CartView.body.getter closure #2 + 88 (CartView.swift:31)
→ EXC_BREAKPOINT ở Swift thường là trap: index out of range hoặc force unwrap nil.
```

**Bài tập:** Cố tình tạo 3 loại crash (force unwrap nil, index out of range, data race chạy với TSan tắt) trong bản TestFlight. Lấy crash log từ Organizer hoặc từ máy (Settings → Privacy → Analytics Data), symbolicate, xác định đúng dòng code.

### Ngày 12 — Log và analytics từ xa

**Kiến thức**
- Log cục bộ (`Logger`) không gửi về; cần cơ chế riêng nếu muốn đọc log của người dùng (người dùng chủ động gửi, có đồng ý).
- Analytics: định nghĩa sự kiện có cấu trúc (`checkout_started`, thuộc tính `cart_value`) trong một file duy nhất; tránh chuỗi rải rác.
- Không gửi dữ liệu cá nhân (email, số điện thoại) vào analytics; tuân thủ App Tracking Transparency nếu theo dõi giữa các app.

**Ví dụ**
```swift
enum AnalyticsEvent {
    case checkoutStarted(itemCount: Int, cartValue: Decimal)
    case orderPlaced(orderID: String, paymentMethod: String)

    var name: String {
        switch self {
        case .checkoutStarted: "checkout_started"
        case .orderPlaced: "order_placed"
        }
    }
}
```

**Bài tập:** Định nghĩa 15 sự kiện analytics cho funnel mua hàng của dự án trong một enum. Gắn vào app qua `EventBatcher` của ConcurrencyLab Bài 4. Vẽ funnel dự kiến: xem sản phẩm → thêm giỏ → checkout → đặt hàng.

### Ngày 13 — Feature flag từ xa và phát hành theo giai đoạn

**Kiến thức**
- Remote config/feature flag: bật tính năng cho 5% người dùng, theo dõi crash và chỉ số, rồi mở rộng. Tắt ngay nếu có sự cố, không cần phát hành lại.
- Phased release trên App Store: 7 ngày tăng dần 1% → 100%, có thể tạm dừng.
- Flag phải có giá trị mặc định an toàn khi không tải được cấu hình, và phải được dọn khỏi code sau khi tính năng ổn định.

**Ví dụ**
```swift
protocol FeatureFlags: Sendable {
    func isEnabled(_ flag: Flag) -> Bool
}

enum Flag: String { case newCheckout = "new_checkout", liquidGlassTabBar = "lg_tab_bar" }

// Gọi trong code
if flags.isEnabled(.newCheckout) { NewCheckoutView() } else { CheckoutView() }
```

**Bài tập:** Cài `RemoteFeatureFlags` đọc JSON từ một URL (có cache, có mặc định), kèm màn hình debug để bật/tắt tay trong bản nội bộ. Viết quy trình phát hành một tính năng lớn qua 4 giai đoạn (nội bộ → 5% → 50% → 100%) với tiêu chí chuyển giai đoạn.

### Ngày 14 — SwiftLint và SwiftFormat

**Kiến thức**
- Linter bắt lỗi phong cách và một số lỗi logic (force unwrap, `print`, độ dài hàm). Formatter tự sửa định dạng để review không tranh cãi khoảng trắng.
- Chạy trong pipeline và Git hook `pre-commit`. Bật dần quy tắc, không bật tất cả một lúc trên codebase cũ.
- `swift-format` của Apple hoặc `SwiftFormat` của nicklockwood; chọn một và thống nhất.

**Ví dụ (`.swiftlint.yml`)**
```yaml
opt_in_rules:
  - force_unwrapping
  - empty_count
  - first_where
disabled_rules:
  - trailing_whitespace   # để formatter lo
line_length: 140
custom_rules:
  no_print:
    regex: '\bprint\('
    message: "Dùng Logger thay cho print"
```

**Bài tập:** Thêm SwiftLint và một formatter vào dự án, chạy trên toàn repo, sửa hoặc tạm tắt có ghi chú. Thêm vào pipeline PR và Git hook. Ghi lại 3 quy tắc team tranh cãi nhiều nhất và quyết định cuối.

### Ngày 15 — Mốc M3: pipeline lên TestFlight

**Bài tập (Mốc M3):** Merge vào `main` → pipeline tự chạy test, tăng build number, archive, tải lên TestFlight, gửi thông báo vào kênh chat của team, tải dSYM lên dịch vụ crash. Không có bước thủ công nào. Ghi tài liệu "Cách phát hành" 1 trang cho người mới.

---

## Tuần 4 · Phát hành an toàn

### Ngày 16 — Quản lý dependency

**Kiến thức**
- Ghim phiên bản (`.upToNextMinor(from:)` cho thư viện quan trọng), commit `Package.resolved` cho app.
- Cập nhật định kỳ (ví dụ mỗi tháng) trong PR riêng; đọc changelog; chạy toàn bộ test.
- Đánh giá trước khi thêm thư viện: còn được bảo trì không, kích thước, có privacy manifest không, có thể tự viết trong 1 ngày không.

**Ví dụ**
```swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMinor(from: "1.17.0")),
]
```

**Bài tập:** Lập bảng mọi dependency của dự án: phiên bản, lần cập nhật cuối của thư viện, giấy phép, có privacy manifest không, lý do dùng. Đề xuất bỏ ít nhất 1 thư viện và tự thay thế.

### Ngày 17 — Checklist phát hành, rollback và hotfix

**Kiến thức**
- App Store không cho rollback: bản lỗi đã phát hành chỉ có thể sửa bằng bản mới. Vì vậy phased release, feature flag và kill switch là lưới an toàn.
- Hotfix: nhánh từ tag đang chạy, sửa tối thiểu, xin Expedited Review nếu nghiêm trọng.
- Buộc cập nhật (force update) khi API cũ bị tắt: app kiểm tra phiên bản tối thiểu từ server.

**Ví dụ (một phần checklist phát hành)**
```
[ ] Toàn bộ test xanh trên commit được tag
[ ] Kiểm thử luồng chính trên iOS thấp nhất được hỗ trợ và iOS mới nhất
[ ] Ghi chú phát hành (vi, en) đã duyệt
[ ] Feature flag của tính năng mới mặc định TẮT
[ ] Bật phased release
[ ] Người trực theo dõi crash 48 giờ đầu
```

**Bài tập:** Viết checklist phát hành 20 mục và quy trình hotfix cho team. Cài cơ chế "phiên bản tối thiểu": server trả `minimumVersion`, app thấp hơn thì hiện màn hình yêu cầu cập nhật không đóng được.

### Ngày 18 — Kiểm tra accessibility trước khi phát hành

**Kiến thức**
- Accessibility Inspector → Audit; Xcode có thể chạy audit trong UI test (`try app.performAccessibilityAudit()`, iOS 17).
- Kiểm tra: VoiceOver đọc đúng thứ tự, mọi nút có nhãn, tương phản màu, Dynamic Type lớn nhất không cắt chữ, vùng chạm ≥ 44×44 pt.
- Ở nhiều thị trường, accessibility là yêu cầu pháp lý cho app ngân hàng, dịch vụ công.

**Ví dụ**
```swift
func testHomeIsAccessible() throws {
    let app = XCUIApplication(); app.launch()
    try app.performAccessibilityAudit()
}
```

**Bài tập:** Thêm `performAccessibilityAudit()` cho 5 màn hình chính vào UI test, sửa mọi vấn đề phát hiện. Nhờ một người chưa từng dùng app thử hoàn thành đặt hàng chỉ bằng VoiceOver, ghi lại chỗ họ bị kẹt.

### Ngày 19 — Kiểm thử bản địa hoá

**Kiến thức**
- Kiểm tra ngôn ngữ dài (tiếng Đức, pseudolanguage), ngôn ngữ phải-sang-trái (tiếng Ả Rập), định dạng ngày/tiền theo vùng.
- Xuất/nhập bản dịch: Product → Export Localizations (`.xcloc`) để gửi người dịch.
- Ảnh chụp App Store theo từng ngôn ngữ có thể tự động bằng UI test + `fastlane snapshot`.

**Ví dụ**
```swift
func testCheckoutInArabic() {
    let app = XCUIApplication()
    app.launchArguments += ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
    app.launch()
    // chụp ảnh, kiểm tra layout lật đúng chiều
}
```

**Bài tập:** Chạy app với pseudolanguage Double-Length và Right-to-Left, sửa mọi chỗ cắt chữ hoặc lật sai. Tự động chụp ảnh 5 màn hình × 2 ngôn ngữ bằng UI test.

### Ngày 20 — Ôn tập và kiểm tra lần 3

**Bài tập:** Phát hành bản 0.2 của dự án qua toàn bộ pipeline, có phased release (giả lập nếu chưa lên App Store), feature flag cho một tính năng mới, checklist phát hành đã điền.

**Kiểm tra lần 3:** làm lại bài kiểm tra năng lực (Phần A, ConcurrencyLab trên nhánh mới, Phần C). Ghi điểm vào bảng tiến độ trong README. Mục tiêu tổng ≥ 70 (mức Mid).
