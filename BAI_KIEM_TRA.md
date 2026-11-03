# ConcurrencyLab — Đề bài thực hành (Phần B của bài kiểm tra năng lực)

[← Về lộ trình 12 tháng](README.md) · Thời điểm làm theo lộ trình: [Tháng 4](docs/lo-trinh/thang-04.md) (Bài 1: Ngày 10, Bài 2: Ngày 15, Bài 3: Ngày 16, Bài 4: Ngày 17, Bài 5: Ngày 18)

Năm bài sửa lỗi lấy từ các sự cố production có thật: request trùng, refresh token đồng thời, response về sai thứ tự, data race trong code GCD cũ, rò rỉ subscription. Mỗi bài có code đang chạy được nhưng sai, một bộ test tái hiện lỗi **một cách tất định** (không phụ thuộc may rủi), và một đáp án tham khảo.

- **Dành cho:** iOS developer khoảng 1 năm kinh nghiệm, đang hướng tới Mid-level.
- **Thời gian gợi ý:** 6–8 giờ, có thể chia 5 buổi (mỗi bài 1–2 giờ).
- **Kiến thức kiểm tra:** actor và reentrancy, `Task` có/không cấu trúc, cancellation, continuation, `Sendable`, `@MainActor`, lock, `AsyncStream`, retain cycle, thiết kế để test được.

---

## 1. Chuẩn bị

| Yêu cầu | Phiên bản |
| --- | --- |
| macOS | 14 trở lên |
| Xcode | 16 trở lên (Swift 6.0+). Package bật Swift 6 language mode: cảnh báo data race là lỗi biên dịch. |

```bash
cd ConcurrencyLab

# 1. Kiểm tra môi trường: chạy bộ test trên ĐÁP ÁN, phải xanh hết
swift test -Xswiftc -DSOLUTION

# 2. Chạy bộ test trên BÀI LÀM của bạn (lúc đầu sẽ đỏ nhiều)
swift test

# Chỉ chạy một bài
swift test --filter Bai1

# Bài 4 nên chạy kèm Thread Sanitizer
swift test --filter Bai4 --sanitize=thread
```

Mở bằng Xcode: `open Package.swift`, rồi `⌘U`. Xcode chạy test trên bài làm.

> Lần chạy đầu với code khởi đầu, **Bài 4 có thể crash cả tiến trình test** (data race làm hỏng bộ nhớ của `Array`). Đó chính là lỗi cần sửa. Khi đó chạy từng bài bằng `--filter`.

---

## 2. Quy tắc làm bài

1. **Chỉ sửa trong `Sources/Exercises/`.** Không sửa `LabCore`, `LabTestSupport`, `Tests`.
2. **Giữ nguyên API public** (tên type, `init`, method, property public). Được thêm type, hàm, property `private`/`internal`.
3. **Không mở `Sources/Solutions/` và `GIAI_THICH.md`** cho tới khi làm xong bài đó.
4. **Cấm các "mẹo" sau** (bị trừ điểm review dù test xanh):
   - Thêm `Task.sleep` để "đợi cho chắc".
   - Gắn `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` để tắt lỗi biên dịch mà không chứng minh được vì sao an toàn.
   - Bắt và nuốt mọi lỗi (`catch {}`) để test không thấy lỗi.
5. **Mỗi bài viết một đoạn "PR description" 5–10 dòng** vào file `NOTES.md` (tự tạo): nguyên nhân gốc, cách sửa, đánh đổi. Đoạn này được chấm.

---

## 3. Cấu trúc dự án

```
ConcurrencyLab/
├── README.md             Lộ trình học 12 tháng (mục lục)
├── BAI_KIEM_TRA.md       Đề ConcurrencyLab (file này)
├── docs/lo-trinh/        Từng tháng: kiến thức, ví dụ, bài tập theo ngày
├── Package.swift
├── Sources/
│   ├── LabCore/          Kiểu dữ liệu + protocol dùng chung (không sửa)
│   ├── Exercises/        ← BÀI LÀM CỦA BẠN
│   ├── Solutions/        Đáp án tham khảo
│   └── LabTestSupport/   Fake có điều khiển + tiện ích test async (không sửa)
├── Tests/LabTests/       31 test, chọn module bằng cờ -DSOLUTION
├── GIAI_THICH.md         Giải thích đáp án, lỗi sai thường gặp
└── .github/workflows/    CI chạy cả hai chế độ trên macOS
```

**Vì sao test không bị "flaky"?** Các fake trong `LabTestSupport` giữ mọi request lại cho tới khi test chủ động trả kết quả. Test quyết định chính xác request nào xong trước, request nào bị huỷ, nên race condition được tái hiện mỗi lần chạy. Đáng đọc kỹ `ControlledCalls.swift` và `Metric.swift`: đây cũng là kỹ thuật bạn nên dùng để test code async trong dự án thật.

---

## 4. Năm bài

### Bài 1 · ImageLoader — tải ảnh dùng chung (`Bai1_ImageLoader.swift`)

**Bối cảnh.** Feed sản phẩm, cùng một thumbnail xuất hiện ở nhiều cell. Sau khi chuyển sang `async/await`, hoá đơn CDN tăng 40%. Cell bị reuse thì có lúc cell khác mất ảnh theo. Lướt lâu thì app bị kill vì hết bộ nhớ.

**Yêu cầu.**

| # | Hành vi | Test |
| --- | --- | --- |
| 1.1 | Nhiều lời gọi đồng thời cùng URL chỉ tạo **một** request mạng; tất cả nhận cùng kết quả. | `concurrentCallsShareOneRequest` |
| 1.2 | Ảnh đã tải được trả từ cache. | `cachedImageIsReused` |
| 1.3 | Lỗi mạng được trả cho mọi caller đang chờ, **không** bị cache; lần sau tải lại. | `failureIsSharedButNotCached` |
| 1.4 | Một caller bị huỷ: caller đó nhận `CancellationError` **ngay**, các caller khác vẫn nhận ảnh, request mạng **không** bị huỷ. | `cancellingOneCallerKeepsSharedDownload` |
| 1.5 | Mọi caller bị huỷ: request mạng bị huỷ. Lần gọi sau tải mới bình thường. | `cancellingAllCallersCancelsDownload` |
| 1.6 | Cache giới hạn theo tổng số byte (`cacheCapacityBytes`), loại ảnh ít dùng gần đây nhất (LRU). | `cacheEvictsLeastRecentlyUsed` |
| 1.7 | Ảnh lớn hơn toàn bộ dung lượng cache: vẫn trả về, không cache. | `oversizedImageIsNotCached` |

**Edge case cần tự nghĩ.** Download đã bị huỷ (vì mọi caller rời đi) kết thúc muộn, đúng lúc đã có download mới cho cùng URL. Kết quả của download cũ có được phép đụng vào state của download mới không?

<details>
<summary>Gợi ý (mở khi bí quá 30 phút)</summary>

- Actor không có data race, nhưng **tại mỗi `await` actor có thể chạy lời gọi khác** (reentrancy). Kiểm tra cache → `await` → ghi cache là một chuỗi không nguyên tử.
- Lưu "việc đang làm" (một `Task`) thay vì chỉ lưu "kết quả". Caller sau chờ việc đang làm.
- `await task.value` **không** dừng được khi caller bị huỷ: nó chờ tới khi task xong. Muốn caller thoát ngay, mỗi caller cần một điểm chờ của riêng mình (`CheckedContinuation`) và `withTaskCancellationHandler`.
- Gắn một `token` (UUID) cho mỗi download để nhận ra kết quả lỗi thời.
</details>

**Câu hỏi phỏng vấn kèm theo.** Vì sao `async let` không dùng được để gộp request ở đây? Khi nào nên dùng `NSCache` thay vì tự viết LRU?

---

### Bài 2 · AuthenticatedClient — tự refresh token (`Bai2_AuthenticatedClient.swift`)

**Bối cảnh.** App ngân hàng. Mở app sau 1 giờ, Home gọi 5 API song song, cả 5 nhận 401, cả 5 cùng refresh. Server dùng *refresh-token rotation*: chỉ lần đầu thành công, 4 lần sau nhận `invalidGrant` và người dùng bị đăng xuất oan. Tài khoản bị khoá quyền thì app retry vô hạn. Mất mạng lúc refresh thì bị đăng xuất.

**Yêu cầu.**

| # | Hành vi | Test |
| --- | --- | --- |
| 2.1 | Nhiều request cùng gặp 401: **đúng một** lần refresh, mọi request được retry và thành công. | `concurrent401sTriggerSingleRefresh` |
| 2.2 | Refresh trả `RefreshError.invalidGrant`: mọi request ném `AuthError.sessionExpired`, `tokens == nil`, các lần `send` sau ném ngay không gọi mạng. | `revokedRefreshTokenExpiresSession` |
| 2.3 | Request gửi bằng token cũ, nhận 401 **sau khi** request khác đã refresh xong: chỉ retry bằng token mới, **không** refresh lần nữa. | `late401ReusesAlreadyRefreshedToken` |
| 2.4 | Retry bằng token mới vẫn 401: ném `AuthError.unauthorized`. Tổng cộng đúng 2 lần gửi, 1 lần refresh. | `persistent401StopsAfterOneRetry` |
| 2.5 | Refresh lỗi mạng (`URLError`): ném lỗi đó ra, **giữ nguyên** token; lần sau refresh lại được. | `networkErrorDuringRefreshKeepsSession` |

**Edge case cần tự nghĩ.** Request đầu tiên kích hoạt refresh rồi bị huỷ (người dùng rời màn hình). Các request khác đang chờ cùng refresh có bị ảnh hưởng không?

<details>
<summary>Gợi ý</summary>

- Giữ `Task<TokenPair, Error>?` của lần refresh đang chạy. Request nào gặp 401 thì chờ chung task đó.
- Nhớ token đã dùng cho request. Khi nhận 401, so với token hiện tại: khác nhau nghĩa là đã có người refresh rồi.
- Phân biệt "phiên hết hạn" với "không gọi được server". Chỉ cái đầu mới xoá token.
- Đệ quy `send` gọi lại chính nó là cách nhanh nhất để retry vô hạn.
</details>

**Câu hỏi phỏng vấn kèm theo.** Nếu refresh token được lưu trong Keychain và có hai process (app + Notification Service Extension) cùng refresh thì sao?

---

### Bài 3 · SearchViewModel — tìm kiếm khi đang gõ (`Bai3_SearchViewModel.swift`)

**Bối cảnh.** App đặt đồ ăn. Gõ "pho" thì thấy kết quả của "ph" vì response của "ph" về sau. Mỗi phím gõ một request, backend quá tải giờ trưa. Xoá ô tìm kiếm thì danh sách cũ lại hiện về. Gõ nhanh thì hiện banner lỗi "cancelled".

**Lưu ý quan trọng:** `FakeSearchAPI` **phớt lờ cancellation**, giống nhiều backend thật. Huỷ `Task` không có nghĩa là response sẽ không về.

**Yêu cầu.**

| # | Hành vi | Test |
| --- | --- | --- |
| 3.1 | Response của truy vấn cũ về sau không được ghi đè kết quả của truy vấn mới. | `staleResponseIsIgnored` |
| 3.2 | Chờ `debounce` trước khi gọi API; truy vấn mới huỷ truy vấn đang chờ. Chỉ truy vấn cuối được gửi. Bị huỷ thì **không** hiện lỗi. | `debounceCancelsEarlierQueries` |
| 3.3 | Ô rỗng (hoặc chỉ khoảng trắng): `results` rỗng ngay, `isLoading = false`, không gọi API; response đang bay bị bỏ qua. | `clearingQueryDropsInFlightSearch` |
| 3.4 | Cắt khoảng trắng đầu/cuối. Truy vấn trùng truy vấn hiện tại thì không gửi lại. `query` lưu bản đã cắt. | `trimsAndSkipsDuplicateQueries` |
| 3.5 | Lỗi mạng: `errorMessage != nil`, `isLoading = false`. Lần tìm sau thành công thì `errorMessage = nil`. | `errorIsShownThenClearedBySuccess` |

**Edge case cần tự nghĩ.** `URLSession` khi bị huỷ ném `URLError(.cancelled)`, không phải `CancellationError`. Code của bạn có hiện banner lỗi trong trường hợp đó không?

<details>
<summary>Gợi ý</summary>

- Huỷ task cũ là cần nhưng chưa đủ. Trước khi ghi state, hỏi: "task này còn là task hiện tại không?"
- Đặt debounce bên trong task để huỷ task là huỷ luôn việc chờ.
- `Task.isCancelled` sau khi `await` xong cho biết task đã bị huỷ trong lúc chờ.
</details>

**Câu hỏi phỏng vấn kèm theo.** Viết lại bằng `.task(id: query)` của SwiftUI thì phần nào tự động đúng, phần nào vẫn phải tự xử lý?

---

### Bài 4 · EventBatcher — gom sự kiện analytics (`Bai4_EventBatcher.swift`)

**Bối cảnh.** Codebase 6 năm tuổi. Crash `EXC_BAD_ACCESS` trong `Array.append` không tái hiện được trên máy dev. Số sự kiện thiếu 3%, một số bị gửi trùng. Dùng app trên máy bay 8 tiếng thì crash vì thiếu bộ nhớ.

**Ràng buộc thực tế:** `log(_:)` được gọi từ khắp nơi trong code cũ (delegate UIKit, callback GCD, thread của SDK bên thứ ba). Nó **phải đồng bộ**, không được `async`, không được chặn thread gọi lâu. Vì thế không thể đơn giản đổi class thành actor.

**Yêu cầu.**

| # | Hành vi | Test |
| --- | --- | --- |
| 4.1 | `log` gọi đồng thời từ nhiều thread: không crash, không mất, không trùng; tại mỗi thời điểm tối đa **một** upload đang chạy. | `concurrentLoggingIsSafe` |
| 4.2 | Sự kiện log trong lúc một upload đang chạy không bị mất. | `eventsLoggedDuringUploadSurvive` |
| 4.3 | Upload lỗi: batch được trả về **đầu** hàng đợi, giữ đúng thứ tự log; lần flush sau gửi lại. | `failedUploadIsRetriedInOrder` |
| 4.4 | Buffer có giới hạn `maxBufferedEvents`: đầy thì bỏ sự kiện **cũ nhất**, `droppedCount` đếm số bị bỏ. | `bufferDropsOldestWhenFull` |
| 4.5 | Hai lần `flush()` cùng lúc: chỉ một upload, không gửi trùng. `flush()` chỉ trả về khi mọi sự kiện có trong buffer lúc gọi đã được xử lý. | `concurrentFlushesDoNotDuplicate` |

Hành vi tự flush: khi số sự kiện chờ chạm `batchSize`. Mỗi lần upload tối đa `batchSize` sự kiện.

**Edge case cần tự nghĩ.** Vì sao "giữ lock trong lúc upload" vừa sai về hiệu năng vừa không biên dịch được với Swift 6?

<details>
<summary>Gợi ý</summary>

- Phần đồng bộ (buffer) cần lock: `OSAllocatedUnfairLock` (iOS 16+), `Mutex` (iOS 18+) hoặc `NSLock`.
- Lấy batch **ra khỏi** buffer trong lock rồi mới upload ngoài lock. Đừng xoá buffer sau khi upload xong.
- Để các lần flush chạy tuần tự, một actor là chưa đủ vì nó reentrant tại `await`. Cần một hàng đợi các `Task` nối đuôi nhau.
</details>

**Câu hỏi phỏng vấn kèm theo.** Khi nào chọn lock thay vì actor? Upload lỗi liên tục khi offline thì nên thêm gì (gợi ý: exponential backoff, `NWPathMonitor`)?

---

### Bài 5 · PriceFeed + PriceViewModel — giá realtime (`Bai5_PriceFeed.swift`)

**Bối cảnh.** App chứng khoán. Mở Watchlist và Chi tiết mã cùng lúc thì server thấy 2 kết nối WebSocket từ một máy. Đóng màn hình Chi tiết, Memory Graph vẫn thấy ViewModel sống. Thoát hết màn hình giá, socket vẫn mở và hao pin. Mở lại thì không thấy giá nhảy nữa.

**Yêu cầu `PriceFeed`.**

| # | Hành vi | Test |
| --- | --- | --- |
| 5.1 | Nhiều subscriber đến cùng lúc (kể cả trong lúc đang kết nối): chỉ **một** lần `connect()`. | `concurrentSubscribersShareOneConnection` |
| 5.2 | Mỗi subscriber chỉ nhận giá của mã mình đăng ký, đúng thứ tự. | `ticksAreRoutedBySymbolInOrder` |
| 5.3 | Consumer ngừng lặp (task bị huỷ) thì tự huỷ đăng ký. Subscriber cuối rời đi thì `disconnect()` đúng một lần. Subscribe lại thì kết nối lại. | `lastSubscriberClosesSocketAndResubscribeReconnects` |
| 5.4 | Một trong nhiều subscriber rời đi: socket vẫn mở, người còn lại vẫn nhận giá. | `remainingSubscriberKeepsReceiving` |

**Yêu cầu `PriceViewModel`.**

| # | Hành vi | Test |
| --- | --- | --- |
| 5.5 | `start()` hiển thị giá mới nhất vào `latest`, `isStreaming = true`. | `showsLatestTick` |
| 5.6 | `stop()` huỷ subscription, `isStreaming = false`; socket đóng nếu không còn ai. | `stopCancelsSubscription` |
| 5.7 | ViewModel bị giải phóng (màn hình đóng) mà **quên gọi `stop()`**: không rò rỉ, subscription vẫn được huỷ. | `releasingViewModelCleansUp` |
| 5.8 | `start()` gọi hai lần liên tiếp chỉ tạo một subscription. | `startIsIdempotent` |
| 5.9 | `stop()` rồi `start()` ngay: vẫn stream; task cũ kết thúc muộn không được đặt `isStreaming = false`. | `restartAfterStopKeepsStreaming` |

**Edge case cần tự nghĩ.** Mọi subscriber rời đi **trong lúc** `connect()` đang chạy. Khi kết nối xong thì sao?

<details>
<summary>Gợi ý</summary>

- `AsyncStream.Continuation.onTermination` được gọi khi consumer ngừng lặp. Đó là chỗ để huỷ đăng ký.
- Trạng thái kết nối nên là một `enum` (chưa kết nối / đang kết nối với task X / đã kết nối) thay vì một `Bool`.
- `Task { for await ... { self.x = ... } }` giữ `self` mạnh suốt vòng lặp. `[weak self]` cộng `guard let self` **bên trong** thân vòng lặp mới giải quyết được.
- Ở Swift 6, `deinit` của class `@MainActor` không đọc được property `@MainActor`. Hãy để một object nhỏ (`Sendable`) giữ `Task` và huỷ nó trong `deinit` của chính object đó.
</details>

**Câu hỏi phỏng vấn kèm theo.** Thêm tự kết nối lại khi mất mạng với exponential backoff thì cần thêm trạng thái nào vào máy trạng thái?

---

## 5. Barem chấm (100 điểm)

Mỗi bài 20 điểm: **12 điểm test + 8 điểm review code**.

**Điểm test** = 12 × (số test xanh / tổng số test của bài). Bài 1: 7 test, Bài 2: 5, Bài 3: 5, Bài 4: 5, Bài 5: 9.

**Điểm review** (tự chấm hoặc nhờ senior chấm, dựa trên `GIAI_THICH.md`):

| Tiêu chí | Điểm | Đạt khi |
| --- | --- | --- |
| Đúng vì đúng lý do | 3 | Giải thích được trong NOTES.md vì sao lỗi xảy ra và vì sao cách sửa loại bỏ hẳn nó, không chỉ làm test xanh |
| Không dùng mẹo cấm | 2 | Không `sleep`, không `@unchecked Sendable`/`nonisolated(unsafe)` vô căn cứ, không nuốt lỗi (mục 2.4) |
| Dễ đọc | 2 | Tên rõ, hàm ngắn, trạng thái biểu diễn bằng kiểu (enum, struct) thay vì nhiều `Bool` rời rạc |
| Nêu đánh đổi | 1 | NOTES.md nêu ít nhất một giới hạn của cách sửa (ví dụ: chưa có backoff, LRU O(n)) |

**Quy đổi cấp độ** (khớp với lộ trình):

| Tổng điểm | Cấp độ |
| --- | --- |
| < 50 | Junior |
| 50–69 | Junior+ / Mid sớm |
| 70–84 | Mid |
| ≥ 85 | Mid+ / gần Senior |

Trong bài kiểm tra năng lực tổng (100 điểm: A trắc nghiệm 30, B thực hành 50, C thiết kế 20), điểm Phần B = điểm dự án này ÷ 2.

---

## 6. Sau khi làm xong

1. Chạy `swift test --sanitize=thread` trên bài làm: không được có cảnh báo của TSan.
2. So với `Sources/Solutions/` và đọc `GIAI_THICH.md`, đặc biệt mục "Cách sửa trông đúng nhưng sai".
3. Áp dụng vào dự án thật: tìm trong codebase của bạn chỗ nào có `await` giữa "kiểm tra" và "ghi" trong actor, chỗ nào `Task { self... }` trong ViewModel.
4. Làm lại toàn bộ sau 3 tháng, so điểm.
