# Tháng 12 — Dẫn dắt và tổng kết

**Mục tiêu:** chuyển từ "làm tốt việc của mình" sang "giúp team làm tốt hơn": review, viết tài liệu kỹ thuật, ước lượng, mentor, xử lý sự cố, làm việc với AI agent có kiểm soát. Hoàn thiện dự án xuyên suốt và làm bài kiểm tra tổng.
**Đầu ra cuối tháng:** Mốc **M4** hoàn chỉnh, bài kiểm tra năng lực **lần 4** (mục tiêu ≥ 80), một bài trình bày kỹ thuật 20 phút.

[← Tháng 11](thang-11.md) · [Mục lục](../../README.md) · [Chuyên đề A →](../chuyen-de/ai-tren-ios.md)

---

## Tuần 1 · Làm việc cùng team

### Ngày 1 — Review code hiệu quả

**Kiến thức**
- Mục tiêu của review: tìm lỗi, chia sẻ kiến thức, giữ codebase nhất quán. Không phải để chứng minh mình giỏi.
- Đọc mô tả PR và chạy thử trước khi đọc code; review trong vòng một ngày làm việc.
- Phân loại bình luận: **[Bắt buộc]**, **[Nên]**, **[Gợi ý/Nit]**, **[Hỏi]**. Khen chỗ làm tốt cũng là review.

**Ví dụ**
```
[Hỏi] Nếu người dùng bấm "Đặt hàng" 2 lần trong lúc request đầu chưa xong
thì có tạo 2 đơn không? Mình chưa thấy chỗ chặn ở ViewModel.

[Nit] Có thể dùng `items.isEmpty` thay `items.count == 0`.

[Tốt] Test race cho refresh token rất rõ, mình sẽ dùng lại mẫu này.
```

**Bài tập:** Dùng checklist review đã viết ở Tháng 5 Ngày 19, review 3 PR thật trong team (hoặc PR mở trên một repo mã nguồn mở iOS). Đếm số bình luận mỗi loại; nhờ tác giả đánh giá bình luận nào hữu ích nhất.

### Ngày 2 — Viết tài liệu kỹ thuật (RFC)

**Kiến thức**
- RFC (tài liệu đề xuất) trước khi làm việc lớn: *Bối cảnh → Mục tiêu và không-mục-tiêu → Đề xuất → Phương án khác → Rủi ro → Kế hoạch triển khai → Câu hỏi mở*.
- Câu đầu tiên của mỗi phần là kết luận; người đọc bận chỉ đọc câu đầu.
- Sơ đồ thay cho đoạn văn dài khi mô tả luồng, kiến trúc.

**Ví dụ (phần mở đầu một RFC)**
```
# RFC: Chuyển lớp mạng sang Swift 6 strict concurrency

Đề xuất: chuyển module Networking sang Swift 6 trong 2 sprint, bắt đầu từ
AuthenticatedTransport vì đây là nguồn của 70% crash liên quan concurrency.

Không-mục-tiêu: chưa chuyển các module UI; chưa đổi API công khai.
```

**Bài tập:** Viết RFC 2–3 trang cho một thay đổi kỹ thuật thật cần làm trong dự án của bạn (ví dụ chuyển sang SwiftData, tách module, đổi kiến trúc màn hình chính). Gửi cho 2 người đọc góp ý, cập nhật theo góp ý.

### Ngày 3 — Ước lượng và chia nhỏ việc

**Kiến thức**
- Chia việc tới mức mỗi phần ≤ 1 ngày; việc không chia nhỏ được nghĩa là chưa hiểu rõ, cần một spike (làm thử có giới hạn thời gian).
- Ước lượng theo khoảng (2–4 ngày) kèm mức tự tin; nêu rõ giả định và phụ thuộc.
- Theo dõi ước lượng và thực tế để hiệu chỉnh: hầu hết lập trình viên ước lượng thiếu khoảng 1,5–2 lần.

**Ví dụ**
```
Tính năng: Đặt lại đơn gần nhất qua Siri (tổng 3–5 ngày, tự tin 70%)
1. Endpoint reorder ở backend: phụ thuộc team server, chưa tính
2. OrderService.reorderLast + test             0,5 ngày
3. AppIntent + dialog + test perform()          0,5 ngày
4. AppShortcutsProvider vi/en                   0,5 ngày
5. Xử lý lỗi: món hết hàng, ngoài giờ           1 ngày
6. Thử trên máy thật với Siri, sửa lỗi           1–2 ngày (rủi ro cao nhất)
Giả định: backend có endpoint trước ngày 3.
```

**Bài tập:** Chia nhỏ và ước lượng một tính năng sắp làm trong dự án xuyên suốt. Ghi lại thời gian thực tế từng phần khi làm; cuối tháng so sánh và tính hệ số hiệu chỉnh của bản thân.

### Ngày 4 — Mentor và pair programming

**Kiến thức**
- Mentor tốt hỏi nhiều hơn nói: "Bạn nghĩ lỗi nằm ở đâu?", "Có cách nào để test giả thuyết đó?".
- Pair programming: một người lái (gõ), một người dẫn đường (nghĩ hướng đi); đổi vai mỗi 25 phút.
- Chia sẻ kiến thức có hệ thống: tài liệu onboarding, buổi chia sẻ 15 phút hằng tuần, ví dụ code mẫu trong repo.

**Ví dụ (câu hỏi gợi mở khi người khác bí)**
```
"Bạn đã tái hiện được lỗi chưa? Mất bao lâu để tái hiện?"
"Nếu phải viết một test làm lỗi này lộ ra, test sẽ trông thế nào?"
"Trước khi lỗi xuất hiện, thay đổi gần nhất là gì?"
```

**Bài tập:** Hướng dẫn một người ít kinh nghiệm hơn làm Bài 1 của ConcurrencyLab trong 2 buổi pair programming. Không đưa đáp án; chỉ đặt câu hỏi. Ghi lại họ bí ở đâu và câu hỏi nào giúp họ vượt qua.

### Ngày 5 — Thực hành tuần 1

**Bài tập:** Viết tài liệu onboarding cho dự án xuyên suốt: cách chạy, kiến trúc 1 trang, quy ước code, cách viết test, cách phát hành, 5 lỗi người mới hay gặp. Nhờ một người chưa biết dự án làm theo từ đầu, đo thời gian tới lần chạy test đầu tiên thành công.

---

## Tuần 2 · Codebase lâu dài

### Ngày 6 — Làm việc với AI agent trong Xcode có kiểm soát

**Kiến thức**
- Xcode 27 hỗ trợ cắm nhiều AI agent (qua Agent Client Protocol), agent có thể lập kế hoạch, sửa code, chạy test, thao tác simulator.
- Quy trình an toàn: viết yêu cầu rõ kèm tiêu chí nghiệm thu → để agent lập kế hoạch → duyệt kế hoạch → agent làm theo từng bước nhỏ → **bạn đọc từng dòng diff** → chạy test và TSan.
- Agent hay sai ở đúng những chỗ năm nay bạn học: concurrency (reentrancy, cancellation), vòng đời task, retain cycle. Không merge code mà bạn không giải thích được.

**Ví dụ (một yêu cầu tốt cho agent)**
```
Thêm phân trang cursor cho FeedRepository.
- Giữ nguyên API public của FeedViewModel.
- Không được có 2 request trang tiếp theo cùng lúc (xem FeedPager trong Tháng 6).
- Thêm test dùng ControlledCalls cho: cuộn nhanh 10 lần → 1 request; lỗi → thử lại được.
- Chạy swift test --sanitize=thread, phải xanh.
Lập kế hoạch trước, chờ tôi duyệt rồi mới sửa code.
```

**Bài tập:** Giao cho AI agent làm lại Bài 3 ConcurrencyLab trên một nhánh mới, theo quy trình trên. Review diff như review PR của đồng nghiệp: liệt kê mọi lỗi agent mắc, chỗ nào test bắt được, chỗ nào chỉ bạn bắt được.

### Ngày 7 — Refactor code cũ an toàn

**Kiến thức**
- Trước khi sửa: viết *characterization test* ghi lại hành vi hiện tại (kể cả hành vi lạ), để biết refactor có làm đổi hành vi không.
- Strangler pattern: viết phần mới bên cạnh phần cũ, chuyển dần từng màn hình/luồng, xoá phần cũ khi không còn ai dùng.
- Mỗi PR refactor không thay đổi hành vi; tách riêng với PR thêm tính năng.

**Ví dụ**
```swift
// Characterization test: ghi lại hành vi hiện tại, kể cả chỗ có vẻ sai
@Test func legacyPriceRoundsDownAt500() {
    #expect(LegacyPriceFormatter.format(12_500) == "12.000đ")   // đang làm tròn xuống, giữ nguyên khi refactor
}
```

**Bài tập:** Chọn màn hình cũ nhất trong dự án (hoặc một repo mã nguồn mở cũ). Viết 10 characterization test, rồi refactor sang MVVM + `@Observable` theo strangler pattern qua ít nhất 3 PR nhỏ. Mọi test cũ vẫn xanh sau mỗi PR.

### Ngày 8 — Quản lý nợ kỹ thuật

**Kiến thức**
- Ghi nợ kỹ thuật như một hạng mục công việc: mô tả, tác động (chậm phát triển, lỗi, crash), chi phí sửa, rủi ro nếu không sửa.
- Ưu tiên theo tác động ÷ chi phí; trả nợ đều đặn (ví dụ 15–20% thời gian mỗi sprint) thay vì chờ "sprint dọn dẹp".
- Thuyết phục người quản lý bằng số liệu: thời gian build, số bug lặp lại, thời gian người mới bắt đầu đóng góp.

**Ví dụ**
```
| Nợ                               | Tác động                         | Chi phí | Ưu tiên |
| AuthManager singleton, không test | 3 bug đăng xuất/quý              | 3 ngày  | Cao     |
| Build sạch 9 phút                | Mỗi dev mất ~40 phút/ngày        | 5 ngày  | Cao     |
| 200 cảnh báo Swift 6             | Chặn bật strict concurrency      | 8 ngày  | Trung bình |
```

**Bài tập:** Lập bảng nợ kỹ thuật 10 mục cho dự án thật của bạn, có ước lượng tác động bằng số. Viết đề xuất nửa trang gửi người quản lý cho 3 mục ưu tiên cao nhất.

### Ngày 9 — Xử lý sự cố và postmortem

**Kiến thức**
- Khi có sự cố production: ổn định trước (tắt feature flag, kill switch), tìm nguyên nhân sau. Thông báo sớm cho người liên quan.
- Postmortem không đổ lỗi: *Tóm tắt → Ảnh hưởng (bao nhiêu người, bao lâu) → Dòng thời gian → Nguyên nhân gốc → Điều đã làm tốt → Điều cần cải thiện → Hành động (có người phụ trách, có hạn)*.
- Hỏi "5 lần vì sao" để đi từ triệu chứng tới nguyên nhân hệ thống.

**Ví dụ (dòng thời gian)**
```
09:12  Bản 2.3 đạt 20% phased release
10:40  Crash-free giảm từ 99,8% xuống 98,1%
10:55  Trực ca nhận cảnh báo, tạm dừng phased release
11:20  Xác định crash ở CartViewModel.removeItem (index out of range)
11:35  Tắt flag new_cart, crash-free hồi về 99,7%
14:00  Bản 2.3.1 sửa lỗi gửi Expedited Review
```

**Bài tập:** Viết postmortem đầy đủ cho một sự cố thật bạn từng gặp (hoặc mô phỏng từ một bài ConcurrencyLab, ví dụ "đăng xuất hàng loạt do refresh đồng thời"). Có ít nhất 3 hành động phòng ngừa cụ thể.

### Ngày 10 — Thực hành tuần 2

**Bài tập:** Diễn tập sự cố với dự án xuyên suốt: một người cố tình đưa lỗi vào bản TestFlight sau feature flag; bạn phát hiện qua crash report/metric, tắt flag, sửa, phát hành bản vá, viết postmortem. Đo thời gian từ lúc lỗi xuất hiện tới lúc ổn định.

---

## Tuần 3 · Lan toả và phát triển sự nghiệp

### Ngày 11 — Trình bày kỹ thuật

**Kiến thức**
- Một bài nói = một thông điệp chính. Mở đầu bằng vấn đề người nghe gặp, kết thúc bằng điều họ làm được ngay ngày mai.
- Code trên slide: tối đa 10–12 dòng, chữ to, làm nổi dòng quan trọng. Demo trực tiếp phải có video dự phòng.
- Tập trước ít nhất 2 lần, bấm giờ.

**Ví dụ (dàn ý 20 phút)**
```
1. Sự cố: 4% người dùng bị đăng xuất mỗi ngày (2 phút)
2. Vì sao actor không cứu được: reentrancy (5 phút, có sơ đồ)
3. Cách sửa: lưu Task thay vì Bool, so token (5 phút, code)
4. Cách test race một cách tất định (5 phút, demo)
5. Checklist mang về (3 phút)
```

**Bài tập:** Chuẩn bị bài trình bày 20 phút về chủ đề bạn nắm chắc nhất năm nay (gợi ý: một bài ConcurrencyLab). Trình bày cho team hoặc một meetup iOS, xin phản hồi bằng phiếu 3 câu.

### Ngày 12 — Đóng góp mã nguồn mở

**Kiến thức**
- Bắt đầu từ việc nhỏ: sửa tài liệu, thêm test, sửa issue gắn nhãn "good first issue".
- Đọc `CONTRIBUTING.md`, thảo luận trong issue trước khi gửi PR lớn.
- Mã nguồn mở là cách tốt để học cách người giỏi tổ chức code và review.

**Ví dụ (quy trình)**
```bash
gh repo fork owner/library --clone
cd library && git checkout -b fix/typo-in-readme
# sửa, chạy test
git commit -m "Fix typo in README installation section"
gh pr create --fill
```

**Bài tập:** Chọn một thư viện Swift bạn dùng hằng ngày. Đọc 3 PR đã merge gần đây để hiểu quy trình. Gửi 1 PR (tài liệu, test, hoặc sửa lỗi nhỏ). Ghi lại phản hồi của maintainer.

### Ngày 13 — Hồ sơ năng lực và CV

**Kiến thức**
- CV kỹ sư: mỗi dòng là kết quả có số liệu ("giảm thời gian khởi động 35%", "đưa crash-free từ 99,1% lên 99,8%"), không phải danh sách công nghệ.
- Portfolio: 1–2 dự án có README tốt, kiến trúc rõ, có test, có CI (dự án xuyên suốt và ConcurrencyLab đáp ứng điều này).
- Chuẩn bị câu chuyện cho mỗi dòng trong CV (nối với STAR ở Tháng 11).

**Ví dụ**
```
Trước: "Làm việc với Swift, SwiftUI, Combine, Core Data, CI/CD."
Sau:   "Chuyển lớp mạng sang Swift 6 strict concurrency, loại bỏ lỗi
        đăng xuất do refresh token đồng thời (4% → 0,02% người dùng/ngày)."
```

**Bài tập:** Viết lại CV và hồ sơ LinkedIn/GitHub theo nguyên tắc trên với ít nhất 5 dòng có số liệu từ năm nay. Hoàn thiện README của dự án xuyên suốt như một portfolio.

### Ngày 14 — Luyện phỏng vấn coding

**Kiến thức**
- Phỏng vấn iOS thường có: một bài thuật toán mức vừa (mảng, chuỗi, dictionary, cây), một bài thực hành (dựng màn hình, sửa bug), câu hỏi kiến thức nền tảng.
- Nói ý tưởng trước khi code, nêu độ phức tạp, tự viết test cho trường hợp biên.
- Bài thực hành iOS hay gặp: danh sách có tìm kiếm + phân trang + tải ảnh, chính là những gì bạn đã làm.

**Ví dụ**
```swift
// Nhóm các từ là đảo chữ của nhau: O(n · k log k)
func groupAnagrams(_ words: [String]) -> [[String]] {
    Array(Dictionary(grouping: words) { String($0.sorted()) }.values)
}
```

**Bài tập:** Giải 10 bài mức vừa (mảng, chuỗi, hash map, hai con trỏ, BFS/DFS) bằng Swift, mỗi bài ≤ 30 phút có test. Làm một bài thực hành tự bấm giờ 90 phút: "danh sách quốc gia có tìm kiếm, cờ tải từ mạng, ấn vào xem chi tiết".

### Ngày 15 — Thực hành tuần 3: trình bày kỹ thuật

**Bài tập:** Trình bày bài nói đã chuẩn bị ở Ngày 11 cho ít nhất 5 người. Ghi hình, xem lại, viết 3 điểm cải thiện. Đăng nội dung dưới dạng bài viết blog hoặc README.

---

## Tuần 4 · Hoàn thiện và kiểm tra tổng

### Ngày 16 — Hoàn thiện dự án xuyên suốt (1/3): tính năng

**Kiến thức**
- Cắt phạm vi có chủ đích: một sản phẩm nhỏ hoàn chỉnh tốt hơn một sản phẩm lớn dở dang.
- Danh sách "định nghĩa hoàn thành": test, accessibility, đa ngôn ngữ, xử lý lỗi, hiệu năng, tài liệu.

**Ví dụ (định nghĩa hoàn thành cho một tính năng)**
```
[ ] Test cho logic nghiệp vụ và race condition chính
[ ] Trạng thái loading / rỗng / lỗi / offline
[ ] VoiceOver và Dynamic Type lớn nhất
[ ] vi + en
[ ] Không hang > 100 ms trên máy cũ nhất
[ ] Có trong tài liệu kiến trúc
```

**Bài tập:** Rà toàn bộ tính năng của dự án theo định nghĩa hoàn thành. Cắt hoặc hoàn thiện từng tính năng; không để tính năng nào ở trạng thái dở dang.

### Ngày 17 — Hoàn thiện dự án xuyên suốt (2/3): chất lượng

**Bài tập:** Chạy toàn bộ kiểm tra chất lượng: unit + snapshot + UI test xanh 20 lần liên tiếp, TSan sạch, Accessibility Audit sạch, báo cáo hiệu năng cập nhật (khởi động, bộ nhớ, hitch), coverage module lõi ≥ 70%. Sửa mọi vấn đề còn lại.

### Ngày 18 — Hoàn thiện dự án xuyên suốt (3/3): tài liệu và phát hành

**Bài tập:** Viết README cuối cùng của dự án: mục tiêu, ảnh chụp, kiến trúc (sơ đồ), quyết định quan trọng (link ADR), tích hợp hệ thống, cách chạy và test, giới hạn đã biết. Phát hành bản 1.0 lên TestFlight qua pipeline. Đánh dấu hoàn thành **Mốc M4**.

### Ngày 19 — Nhìn lại cả năm

**Bài tập:** So sánh ma trận tự đánh giá đầu năm (README, mục Tự đánh giá) với hiện tại, từng dòng. Viết 1 trang: 3 điều tiến bộ nhiều nhất, 3 điều còn yếu, kế hoạch 6 tháng tiếp theo (đào sâu một mảng: hiệu năng, kiến trúc lớn, AI trên thiết bị, hay chuyển hướng Senior/Tech Lead).

### Ngày 20 — Kiểm tra năng lực lần 4 (tổng)

**Bài tập:** Làm toàn bộ bài kiểm tra năng lực trong một buổi như thi thật:
- **Phần A:** 15 câu trắc nghiệm, 20 phút.
- **Phần B:** ConcurrencyLab làm lại từ đầu trên nhánh mới, không xem lời giải cũ, tối đa 6 giờ (có thể chia 2 ngày).
- **Phần C:** đề thiết kế mới, trình bày 30 phút cho một người chấm.

Ghi điểm vào bảng tiến độ trong README, so với lần 0. Mục tiêu tổng ≥ 80 (Mid+ / gần Senior).
