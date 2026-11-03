# Lộ trình iOS: từ 1 năm kinh nghiệm lên Senior

Lộ trình chia theo **từng tháng, từng tuần, từng buổi học**. Mỗi buổi có ba phần: **kiến thức** cần nắm, **ví dụ** code để gõ lại, và **bài tập** (chỉ mô tả đề, tự làm). Lộ trình gồm 12 tháng nền tảng và 2 chuyên đề nâng cao mức Senior: **AI trên iOS** và **CI/CD & Release Engineering**.

Đi kèm là **ConcurrencyLab**, một Swift Package gồm 5 bài sửa lỗi concurrency thực tế, có 31 test tất định, đáp án và phần giải thích.

- **Dành cho:** iOS developer khoảng 1 năm kinh nghiệm: làm được màn hình, gọi API, nhưng còn lúng túng với concurrency, kiến trúc, test, hiệu năng.
- **Đích đến sau 12 tháng nền tảng:** Mid vững. Tự thiết kế và giao một tính năng lớn từ đầu tới cuối, giải thích được lựa chọn kiến trúc, review được code người khác.
- **Đích đến sau 2 chuyên đề:** Senior. Chịu trách nhiệm cho tính năng AI ở production (đo, đánh giá, an toàn, chi phí) và cho cả hệ thống phát hành của app (tốc độ, bảo mật chuỗi cung ứng, phát hành theo giai đoạn, số liệu DORA).
- **Khối lượng:** 240 buổi nền tảng + 40 buổi chuyên đề, mỗi buổi khoảng 2 giờ, tổng khoảng 560 giờ.

> **Mức độ khó là có chủ đích.** Từ Tháng 4 trở đi, nhiều bài tập không có đáp án duy nhất; bài được coi là đạt khi qua **tiêu chí nghiệm thu đo được** (phút, ms, %, số lỗi), không phải khi "chạy được". Nếu một buổi mất 4 giờ thay vì 2, đó là bình thường; dùng Thứ Bảy để bù.

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
| 13 | **Chuyên đề A**: AI trên iOS | 25/10 – 19/11/2027 | Capstone "Trợ lý tập luyện" + **Phần D1** | [ai-tren-ios.md](docs/chuyen-de/ai-tren-ios.md) |
| 14 | **Chuyên đề B**: CI/CD & Release Engineering | 22/11 – 17/12/2027 | Capstone "Hệ thống phát hành" + **Phần D2** | [ci-cd-release-engineering.md](docs/chuyen-de/ci-cd-release-engineering.md) |

Hai chuyên đề cũng có thể học song song vào mỗi Thứ Bảy, sau khi xong tháng tiên quyết. Chuyên đề B học từ sau Tháng 9; chuyên đề A học từ sau Tháng 10.

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

### Chuyên đề nâng cao (mức Senior)

#### [Chuyên đề A — AI trên iOS](docs/chuyen-de/ai-tren-ios.md)
*Tiên quyết: Tháng 4, 7, 10.*
1. Chọn công cụ: on-device / Private Cloud Compute / đám mây; Core ML (chuyển đổi, palettization, đo p95); Vision/NaturalLanguage/Speech; Core AI
2. Foundation Models ở production: nén ngữ cảnh, guided generation và streaming UI, tool calling chống prompt injection, prewarm và trạng thái nhiệt
3. RAG trên máy: embedding, chunking, đo recall@k, trích dẫn có kiểm chứng; LLM đám mây qua proxy SSE, hạn mức chi phí; định tuyến lai, ẩn danh PII
4. Eval phiên bản hoá có quy tắc chặn thống kê, guardrail và mô hình rủi ro, vận hành (flag theo phiên bản prompt, chỉ số không chứa nội dung), kỹ thuật phần mềm có AI agent

#### [Chuyên đề B — CI/CD & Release Engineering](docs/chuyen-de/ci-cd-release-engineering.md)
*Tiên quyết: Tháng 7, 9.*
1. DORA cho mobile, build tái lập (ghim Xcode và dependency), build-for-testing + shard, phân tích `.xcresult`, phát hiện flaky, PR ≤ 10 phút
2. Signing bằng keychain tạm / cloud-managed, environment có duyệt, quyền tối thiểu, action ghim SHA, SBOM, Dependabot, kiểm tra `.ipa` trước khi gửi
3. Release train, App Store Connect API (công cụ `asc` tự viết), *release guardian* tự dừng phased release và tắt flag, dashboard sức khoẻ phiên bản
4. Cổng chất lượng (coverage dòng thay đổi, ngân sách kích thước, hồi quy hiệu năng), pipeline đêm có eval AI, CI theo module bị ảnh hưởng, chi phí và runner tự host

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

## 4. Tiêu chuẩn "hoàn thành" dùng cho mọi bài tập từ Tháng 4

Một bài tập chỉ được đánh dấu xong khi đạt **tất cả** các mục áp dụng được:

| Mảng | Tiêu chí |
| --- | --- |
| Đúng | Có test cho hành vi chính và ít nhất 2 trường hợp biên; test tất định (không `sleep`, không mạng thật); chạy 20 lần liên tiếp đều xanh |
| An toàn concurrency | Swift 6 language mode, không cảnh báo; `--sanitize=thread` sạch; mỗi `@unchecked Sendable` hay `nonisolated(unsafe)` có chú thích chứng minh |
| Bộ nhớ | Memory Graph sạch sau 10 lần mở/đóng màn hình liên quan |
| Hiệu năng | Có số liệu đo trên máy thật, bản Release; đạt ngân sách bài tập nêu |
| Trải nghiệm | Trạng thái loading / rỗng / lỗi / offline; VoiceOver và Dynamic Type lớn nhất dùng được |
| Bảo mật | Không secret trong repo, không token/PII trong log, dữ liệu nhạy cảm trong Keychain |
| Tài liệu | Ghi vào `NOTES.md`: nguyên nhân gốc / quyết định, phương án đã loại, giới hạn còn lại |
| Quy trình | Qua PR có pipeline xanh; PR < 400 dòng thay đổi hoặc có lý do |

---

## 5. Bài kiểm tra năng lực

Phần A–C dùng cho 12 tháng nền tảng, tổng 100 điểm. Phần D dùng cho hai chuyên đề và được chấm riêng.

| Phần | Nội dung | Thời gian | Điểm |
| --- | --- | --- | --- |
| A | 15 câu trắc nghiệm (Swift, memory, UI, concurrency, kiến trúc, testing, hiệu năng) | 20 phút | 30 |
| B | **ConcurrencyLab**: 5 bài, 31 test. Đề: [BAI_KIEM_TRA.md](BAI_KIEM_TRA.md). Điểm B = điểm lab ÷ 2 | 6–8 giờ | 50 |
| C | Thiết kế kiến trúc một màn hình/tính năng và trình bày | 30 phút | 20 |

**Quy đổi:** dưới 50 điểm là Junior · 50–69 là Junior+ / Mid sớm · 70–84 là Mid · từ 85 trở lên là Mid+ / gần Senior.

### Phần D — Capstone chuyên đề (mức Senior, mỗi phần 100 điểm)

| Phần | Nội dung | Barem |
| --- | --- | --- |
| D1 | Trợ lý AI trên máy có RAG, tool calling, định tuyến lai, eval ≥ 150 ca trong CI, mô hình rủi ro, dashboard vận hành | [ai-tren-ios.md, Buổi 20](docs/chuyen-de/ai-tren-ios.md#buổi-20--capstone-chuyên-đề-a-và-chấm-điểm) |
| D2 | Hệ thống phát hành: PR ≤ 10 phút, tag → App Store Connect không thao tác tay, release guardian, cổng chất lượng, DORA | [ci-cd-release-engineering.md, Buổi 20](docs/chuyen-de/ci-cd-release-engineering.md#buổi-20--capstone-chuyên-đề-b-và-chấm-điểm) |

Đạt **Senior** khi: tổng A–C ≥ 85 **và** D1 ≥ 80 **và** D2 ≥ 80.

### Bảng tiến độ (tự điền)

| Lần | Thời điểm | A /30 | B /50 | C /20 | Tổng | Ghi chú |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Trước khi bắt đầu | | | | | |
| 1 | Cuối tháng 3 | | | | | |
| 2 | Cuối tháng 6 | | | | | |
| 3 | Cuối tháng 9 | | | | | |
| 4 | Cuối tháng 12 | | | | | Mục tiêu ≥ 80 |

| Capstone | Thời điểm | Điểm /100 | Ghi chú |
| --- | --- | --- | --- |
| D1 · AI trên iOS | Cuối chuyên đề A | | Mục tiêu ≥ 80 |
| D2 · CI/CD & Release | Cuối chuyên đề B | | Mục tiêu ≥ 80 |

### Ma trận năng lực

Chấm mỗi dòng theo cột mô tả đúng nhất việc bạn **làm được mà không cần tra cứu, và đã làm ít nhất một lần ở production hoặc trong dự án xuyên suốt**. Làm ở lần 0, lần 4 và sau mỗi chuyên đề. Cột Staff là định hướng dài hạn, không phải mục tiêu của lộ trình.

| Mảng | Junior (~1 năm) | Mid | Senior | Staff | Học ở |
| --- | --- | --- | --- | --- | --- |
| Swift | optional, struct/class, closure | generics, `associatedtype`, `some`/`any`, result builder | thiết kế API generic, hiểu chi phí runtime | đặt chuẩn API cho nhiều team, đóng góp/đánh giá Swift Evolution | T1 |
| Memory | `[weak self]` theo thói quen | giải thích ARC, tìm cycle bằng Memory Graph | tối ưu CoW, phân tích leak trong code lạ | xây công cụ phát hiện leak tự động trong CI | T1–2 |
| UI | dựng màn hình theo design | identity, state ownership, Auto Layout không thử-sai | design system dùng chung, UIKit–SwiftUI sạch | chiến lược UI cho nhiều app, đo chất lượng UI bằng số liệu | T2–3 |
| Concurrency | `async/await` cơ bản, GCD | actor, `Sendable`, cancellation, Swift 6 | ranh giới isolation cho cả app, gỡ race, test race tất định | dẫn dắt chuyển cả codebase lớn sang Swift 6 | T4 |
| Kiến trúc | MVVM theo mẫu | chọn có lý do, DI, module SPM | định hướng kiến trúc, ADR, migrate dần | kiến trúc nhiều app/nhiều team, nền tảng dùng chung | T5 |
| Dữ liệu | REST + JSON | retry, cache, SwiftData, migration | offline-first, đồng bộ, xung đột | thiết kế API contract cùng backend, chiến lược đồng bộ toàn hệ thống | T6 |
| Testing | ít hoặc không viết | Swift Testing, mock, test async | chiến lược test cho team, test flaky ≈ 0 | hạ tầng test cho tổ chức | T7 |
| Hiệu năng | thấy chậm nhưng không biết đo | Instruments, MetricKit | ngân sách hiệu năng, theo dõi hồi quy | chương trình hiệu năng có số liệu production cho nhiều app | T8 |
| CI/CD & phát hành | archive thủ công | pipeline PR, TestFlight, crash report | build tái lập, signing an toàn, release train, phased release có guardian, cổng chất lượng, DORA | nền tảng CI cho tổ chức, runner tự host, chi phí và độ tin cậy | T9 + CĐ B |
| AI trên iOS | biết tên tính năng | Foundation Models cơ bản, App Intents | chọn mô hình có số liệu, RAG, eval trong CI, an toàn và quyền riêng tư, vận hành | chiến lược AI sản phẩm, hạ tầng eval và mô hình dùng chung | T10 + CĐ A |
| Nền tảng | biết tên tính năng | widget, Live Activity, Liquid Glass | đánh giá khi nào nên dùng, tích hợp sâu với hệ thống | ảnh hưởng tới roadmap sản phẩm dựa trên nền tảng mới | T10 |
| Thiết kế & dẫn dắt | làm theo task | ước lượng, review, system design | mentor, RFC, dẫn dắt kỹ thuật một mảng | dẫn dắt kỹ thuật nhiều team, định hình văn hoá kỹ thuật | T11–12 |

---

## 6. Chạy ConcurrencyLab

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

## 7. Tài nguyên dùng xuyên suốt

| Loại | Tài nguyên |
| --- | --- |
| Ngôn ngữ | [The Swift Programming Language](https://docs.swift.org/swift-book/), [Swift Evolution](https://github.com/swiftlang/swift-evolution), sách *Advanced Swift* (objc.io) |
| Apple | [Tài liệu Apple Developer](https://developer.apple.com/documentation/), [video WWDC26](https://developer.apple.com/wwdc26/schedule/), Human Interface Guidelines |
| Cộng đồng | [Hacking with Swift](https://www.hackingwithswift.com), [Swift by Sundell](https://www.swiftbysundell.com), [Point-Free](https://www.pointfree.co), [iOS Dev Weekly](https://iosdevweekly.com) |
| Concurrency | Video WWDC về Swift concurrency (2021–2026), blog của Matt Massicotte |
| AI trên iOS | Tài liệu Foundation Models, Core ML, coremltools; video WWDC26 về Apple Intelligence, Core AI, Evaluations; hướng dẫn bảo mật LLM (OWASP Top 10 for LLM Applications) |
| CI/CD | `man xcodebuild`, tài liệu App Store Connect API, GitHub Actions security hardening, sách *Accelerate* (Forsgren, Humble, Kim) về chỉ số DORA |

**Lưu ý về phiên bản:** nội dung viết theo Swift 6.4, Xcode 27 và iOS 27 (WWDC26). Các API của Tháng 10 và chuyên đề A thay đổi theo từng năm; trước mỗi buổi hãy đối chiếu với tài liệu Apple mới nhất.
