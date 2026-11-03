# Lộ trình iOS 12 tháng: từ 1 năm kinh nghiệm lên Mid–Senior

Lộ trình chia theo **từng tháng, từng tuần, từng buổi học**. Mỗi buổi có ba phần: **kiến thức** cần nắm, **ví dụ** code để gõ lại, và **bài tập** (chỉ mô tả đề, tự làm). Đi kèm là **ConcurrencyLab**, một dự án Swift Package gồm 5 bài sửa lỗi concurrency thực tế, có bộ test và đáp án. Đây là Phần B của bài kiểm tra năng lực.

- **Dành cho:** iOS developer khoảng 1 năm kinh nghiệm: làm được màn hình, gọi API, nhưng còn lúng túng với concurrency, kiến trúc, test, hiệu năng.
- **Đích đến sau 12 tháng:** tự thiết kế và giao một tính năng lớn từ đầu tới cuối, giải thích được lựa chọn kiến trúc, review được code người khác.
- **Khối lượng:** 240 buổi × khoảng 2 giờ = khoảng 480 giờ.

---

## 1. Cách học

### Nhịp học

| | |
| --- | --- |
| Mỗi tuần | 5 buổi, từ Thứ Hai đến Thứ Sáu. Buổi thứ 5 của tuần là **thực hành tổng hợp**. |
| Mỗi tháng | 4 tuần = 20 buổi. Buổi 20 là **ôn tập + tự kiểm tra**. |
| Thứ Bảy | Tuỳ chọn: bù buổi bị lỡ, hoặc làm tiếp dự án xuyên suốt. |
| Chủ Nhật | Nghỉ. |

### Một buổi học 2 giờ

| Thời gian | Việc |
| --- | --- |
| 30 phút | Đọc phần **Kiến thức**, tra tài liệu Apple hoặc xem video WWDC liên quan nếu cần |
| 30 phút | Gõ lại phần **Ví dụ** trong Playground hoặc dự án nháp, sửa thử để xem kết quả thay đổi |
| 60 phút | Làm **Bài tập**. Chưa xong thì để dành cho Thứ Bảy; không bỏ qua |

Ghi chép vào một file `NHAT_KY.md`: mỗi buổi 3 dòng gồm điều đã học, điều còn chưa hiểu, và link code bài tập.

### Lịch gợi ý

Lịch dưới đây bắt đầu từ Thứ Hai 09/11/2026 và nghỉ 2 tuần dịp Tết (01–14/02/2027). Nếu bắt đầu muộn hơn, chỉ cần dời toàn bộ.

| Tháng học | Chủ đề | Thời gian gợi ý | Đầu ra cuối tháng | Chi tiết |
| --- | --- | --- | --- | --- |
| 1 | Swift nâng cao | 09/11 – 04/12/2026 | `Cache<Key, Value>` generic có test | [thang-01.md](docs/lo-trinh/thang-01.md) |
| 2 | Memory và UIKit vững | 07/12/2026 – 01/01/2027 | App UIKit 3 màn hình bằng code, không leak | [thang-02.md](docs/lo-trinh/thang-02.md) |
| 3 | SwiftUI vững | 04/01 – 29/01/2027 | **Mốc M1** + kiểm tra **lần 1** | [thang-03.md](docs/lo-trinh/thang-03.md) |
| — | *Nghỉ Tết* | 01/02 – 14/02/2027 | | |
| 4 | Swift Concurrency | 15/02 – 12/03/2027 | 5 bài **ConcurrencyLab** xanh, sạch TSan | [thang-04.md](docs/lo-trinh/thang-04.md) |
| 5 | Kiến trúc và modularization | 15/03 – 09/04/2027 | 3 Swift Package + ADR | [thang-05.md](docs/lo-trinh/thang-05.md) |
| 6 | Networking và lưu trữ dữ liệu | 12/04 – 07/05/2027 | **Mốc M2** + kiểm tra **lần 2** | [thang-06.md](docs/lo-trinh/thang-06.md) |
| 7 | Testing | 10/05 – 04/06/2027 | Coverage module lõi ≥ 70%, snapshot + UI test | [thang-07.md](docs/lo-trinh/thang-07.md) |
| 8 | Hiệu năng | 07/06 – 02/07/2027 | Báo cáo hiệu năng trước/sau | [thang-08.md](docs/lo-trinh/thang-08.md) |
| 9 | CI/CD và phát hành | 05/07 – 30/07/2027 | **Mốc M3** + kiểm tra **lần 3** | [thang-09.md](docs/lo-trinh/thang-09.md) |
| 10 | Nền tảng iOS 27 | 02/08 – 27/08/2027 | App Intent, widget, tính năng AI trên máy | [thang-10.md](docs/lo-trinh/thang-10.md) |
| 11 | Mobile system design | 30/08 – 24/09/2027 | Đề thiết kế 45 phút trọn vẹn | [thang-11.md](docs/lo-trinh/thang-11.md) |
| 12 | Dẫn dắt và tổng kết | 27/09 – 22/10/2027 | **Mốc M4** + kiểm tra **lần 4** | [thang-12.md](docs/lo-trinh/thang-12.md) |

---

## 2. Nội dung từng tháng (tóm tắt theo tuần)

Mỗi dòng là một tuần (5 buổi). Bấm vào tháng để xem chi tiết từng ngày.

### [Tháng 1 — Swift nâng cao](docs/lo-trinh/thang-01.md)
1. struct/class, copy-on-write, `inout` và exclusivity, enum có associated value
2. Protocol và dispatch, generics, `associatedtype`, `some`/`any`
3. Closure và capture, hàm bậc cao, typed throws, optional
4. Codable nâng cao, property wrapper, result builder, macro

### [Tháng 2 — Memory và UIKit vững](docs/lo-trinh/thang-02.md)
1. ARC, `weak`/`unowned`, retain cycle trong closure, delegate, Timer
2. Vòng đời ViewController, Auto Layout bằng code, stack view, trait và dark mode
3. Diffable data source, compositional layout, tái sử dụng cell, cell registration
4. Coordinator, vòng đời app và scene, bàn phím và accessibility, String Catalog

### [Tháng 3 — SwiftUI vững](docs/lo-trinh/thang-03.md)
1. View là giá trị, identity và lifetime, `@State`/`@Binding`, `@Observable`
2. Quy trình layout, Grid và ViewThatFits, tự viết `Layout`, Liquid Glass
3. NavigationStack theo dữ liệu, sheet, hiệu năng List, `.task(id:)`
4. Animation, UIKit trong SwiftUI và ngược lại, Preview và accessibility

### [Tháng 4 — Swift Concurrency](docs/lo-trinh/thang-04.md)
1. async/await, task có/không cấu trúc, `async let` và TaskGroup, cancellation
2. Actor, **reentrancy**, `@MainActor`, `Sendable` → **ConcurrencyLab Bài 1**
3. Continuation, `withTaskCancellationHandler`, `AsyncStream`, chuyển sang Swift 6 → **Bài 2**
4. Debounce → **Bài 3**, lock hay actor → **Bài 4**, vòng đời Task → **Bài 5**, Swift 6.4

### [Tháng 5 — Kiến trúc và modularization](docs/lo-trinh/thang-05.md)
1. SOLID, MVVM, dependency injection, composition root
2. Router, luồng dữ liệu một chiều, Clean Architecture, mô hình hoá lỗi, ADR
3. Swift Package, chiến lược chia module, access control, build time
4. Design system, cấu hình môi trường, `Logger`, checklist code review

### [Tháng 6 — Networking và lưu trữ dữ liệu](docs/lo-trinh/thang-06.md)
1. URLSession, API client theo Endpoint, retry có backoff, Keychain và refresh token
2. HTTP cache, pipeline ảnh, mạng chập chờn, phân trang
3. SwiftData: model, query, migration, `@ModelActor`
4. Core Data cũ, file và App Group, offline-first, bảo mật

### [Tháng 7 — Testing](docs/lo-trinh/thang-07.md)
1. Swift Testing, tham số hoá, chuyển từ XCTest
2. Test double, test async, **test race tất định**, test ViewModel
3. Snapshot test, XCUITest, test plan và test flaky, TDD
4. Test SwiftData, contract test, kiến trúc test, review test

### [Tháng 8 — Hiệu năng](docs/lo-trinh/thang-08.md)
1. Instruments, Time Profiler, Hang, hiệu năng SwiftUI
2. Allocations, bộ nhớ ảnh, thời gian khởi động, MetricKit
3. Chi phí ẩn của Swift, collection, pin và mạng, kích thước app
4. Signpost, background task, ngân sách hiệu năng, phân tích sự cố

### [Tháng 9 — CI/CD và phát hành](docs/lo-trinh/thang-09.md)
1. Code signing, cấu hình và bí mật, TestFlight, privacy manifest
2. Xcode Cloud, GitHub Actions, Fastlane, version tự động
3. Crash và symbolication, analytics, feature flag, SwiftLint
4. Dependency, checklist phát hành và hotfix, kiểm tra accessibility, bản địa hoá

### [Tháng 10 — Nền tảng iOS 27](docs/lo-trinh/thang-10.md)
1. App Intents, AppEntity, App Shortcuts và Siri, widget tương tác
2. Live Activity, Foundation Models, sinh dữ liệu có cấu trúc, đánh giá tính năng AI
3. Liquid Glass, giao diện co giãn tự do, push, StoreKit 2
4. Quyền riêng tư, Universal Link, HealthKit/EventKit, accessibility nâng cao

### [Tháng 11 — Mobile system design](docs/lo-trinh/thang-11.md)
1. Khung 45 phút, ước lượng, kiến trúc client, chiến lược cache → đề News Feed
2. Thời gian thực, app chat, offline-first, tải file lớn → đề Chat
3. Phân trang, thông báo, bảo mật, observability → đề Theo dõi giao hàng
4. Phỏng vấn thử, câu hỏi hành vi STAR, tài liệu đánh đổi

### [Tháng 12 — Dẫn dắt và tổng kết](docs/lo-trinh/thang-12.md)
1. Review code, RFC, ước lượng, mentor
2. AI agent trong Xcode có kiểm soát, refactor code cũ, nợ kỹ thuật, postmortem
3. Trình bày kỹ thuật, mã nguồn mở, CV, luyện phỏng vấn coding
4. Hoàn thiện dự án, nhìn lại cả năm, **kiểm tra tổng**

---

## 3. Dự án xuyên suốt

Chọn **một app duy nhất** cho cả năm, mỗi tháng xây tiếp trên tháng trước. Gợi ý: app theo dõi tập luyện hoặc thói quen, vì app này có danh sách, chi tiết, form, đồng bộ server, widget, Live Activity và AI. Có thể dùng luôn dự án cá nhân đang làm.

| Mốc | Hết tháng | Phải có |
| --- | --- | --- |
| M1 | 3 | Danh sách + chi tiết SwiftUI, điều hướng theo dữ liệu, model generic, không leak |
| M2 | 6 | ≥ 3 Swift Package, Networking dùng actor, Swift 6 bật, SwiftData offline, 1 ADR |
| M3 | 9 | Coverage module lõi ≥ 70%, CI chạy test mỗi PR, build tự lên TestFlight |
| M4 | 12 | App Intent qua Siri/Shortcuts, widget, tính năng Foundation Models có eval, README kiến trúc, bản 1.0 |

---

## 4. Bài kiểm tra năng lực

Tổng 100 điểm, gồm 3 phần:

| Phần | Nội dung | Thời gian | Điểm |
| --- | --- | --- | --- |
| A | 15 câu trắc nghiệm (Swift, memory, UI, concurrency, kiến trúc, testing, hiệu năng) | 20 phút | 30 |
| B | **ConcurrencyLab**: 5 bài, 31 test. Đề: [BAI_KIEM_TRA.md](BAI_KIEM_TRA.md). Điểm B = điểm lab ÷ 2 | 6–8 giờ | 50 |
| C | Thiết kế kiến trúc một màn hình/tính năng và trình bày | 30 phút | 20 |

**Quy đổi:** dưới 50 điểm là Junior · 50–69 là Junior+ / Mid sớm · 70–84 là Mid · từ 85 trở lên là Mid+ / gần Senior.

### Bảng tiến độ (tự điền)

| Lần | Thời điểm | A /30 | B /50 | C /20 | Tổng | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Trước khi bắt đầu | | | | | |
| 1 | Cuối tháng 3 | | | | | |
| 2 | Cuối tháng 6 | | | | | |
| 3 | Cuối tháng 9 | | | | | |
| 4 | Cuối tháng 12 | | | | | Mục tiêu ≥ 80 |

### Ma trận tự đánh giá

Chấm mỗi dòng theo cột mô tả đúng nhất việc bạn **làm được mà không cần tra cứu**. Làm ở lần 0 và lần 4 để so sánh.

| Mảng | Junior (~1 năm) | Mid | Senior | Tháng |
| --- | --- | --- | --- | --- |
| Swift | optional, struct/class, closure | generics, `associatedtype`, `some`/`any`, result builder | thiết kế API generic, hiểu chi phí runtime | 1 |
| Memory | `[weak self]` theo thói quen | giải thích ARC, tìm cycle bằng Memory Graph | tối ưu CoW, phân tích leak trong code lạ | 1–2 |
| UI | dựng màn hình theo design | identity, state ownership, Auto Layout không thử-sai | component dùng chung, UIKit–SwiftUI sạch | 2–3 |
| Concurrency | `async/await` cơ bản, GCD | actor, `Sendable`, cancellation, Swift 6 | ranh giới isolation cho cả app, gỡ race | 4 |
| Kiến trúc | MVVM theo mẫu | chọn có lý do, DI, module SPM | định hướng kiến trúc, ADR, migrate dần | 5 |
| Dữ liệu | REST + JSON | retry, cache, SwiftData, migration | offline-first, đồng bộ, xung đột | 6 |
| Testing | ít hoặc không viết | Swift Testing, mock, test async | chiến lược test cho team | 7 |
| Hiệu năng | thấy chậm nhưng không biết đo | Instruments, MetricKit | ngân sách hiệu năng, theo dõi hồi quy | 8 |
| Phát hành | archive thủ công | CI/CD, TestFlight, crash | pipeline, feature flag, phased release | 9 |
| Nền tảng | biết tên tính năng | App Intents, Foundation Models, Liquid Glass | đánh giá khi nào nên dùng, đo chất lượng AI | 10 |
| Thiết kế & dẫn dắt | làm theo task | ước lượng, review, system design | mentor, RFC, dẫn dắt kỹ thuật | 11–12 |

---

## 5. Chạy ConcurrencyLab

Yêu cầu macOS 14+ và Xcode 16+ (Swift 6.0+).

```bash
swift test -Xswiftc -DSOLUTION              # kiểm tra môi trường: đáp án phải xanh hết
swift test                                  # chạy test trên bài làm của bạn
swift test --filter Bai1                    # chỉ chạy một bài
swift test --filter Bai4 --sanitize=thread  # kèm Thread Sanitizer
```

- Đề bài, quy tắc, barem: [BAI_KIEM_TRA.md](BAI_KIEM_TRA.md)
- Giải thích đáp án (đọc sau khi làm xong): [GIAI_THICH.md](GIAI_THICH.md)
- Bài làm: `Sources/Exercises/` · Đáp án: `Sources/Solutions/` · Fake và tiện ích test: `Sources/LabTestSupport/`

---

## 6. Tài nguyên dùng xuyên suốt

| Loại | Tài nguyên |
| --- | --- |
| Ngôn ngữ | [The Swift Programming Language](https://docs.swift.org/swift-book/), [Swift Evolution](https://github.com/swiftlang/swift-evolution), sách *Advanced Swift* (objc.io) |
| Apple | [Tài liệu Apple Developer](https://developer.apple.com/documentation/), [video WWDC26](https://developer.apple.com/wwdc26/schedule/), Human Interface Guidelines |
| Cộng đồng | [Hacking with Swift](https://www.hackingwithswift.com), [Swift by Sundell](https://www.swiftbysundell.com), [Point-Free](https://www.pointfree.co), [iOS Dev Weekly](https://iosdevweekly.com) |
| Concurrency | Video WWDC về Swift concurrency (2021–2026), blog của Matt Massicotte |

**Lưu ý về phiên bản:** nội dung viết theo Swift 6.4, Xcode 27 và iOS 27 (WWDC26). Các API của Tháng 10 thay đổi theo từng năm; trước mỗi buổi hãy đối chiếu với tài liệu Apple mới nhất.
