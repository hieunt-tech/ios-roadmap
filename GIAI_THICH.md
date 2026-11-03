# Giải thích đáp án

Đọc sau khi đã làm xong bài tương ứng. Mỗi bài gồm: nguyên nhân gốc, cách sửa, các cách sửa "trông đúng" nhưng sai, và hướng mở rộng.

---

## Bài 1 · ImageLoader

### Nguyên nhân gốc

```swift
if let cached = cache[url] { return cached }
let data = try await network.data(from: url)   // ← actor nhả ra ở đây
cache[url] = data
```

Actor bảo đảm **không có hai đoạn code chạy cùng lúc trên actor**, nhưng không bảo đảm một hàm chạy liền một mạch. Tại mỗi `await`, actor được phép chạy lời gọi khác (reentrancy). Mười lời gọi lần lượt kiểm tra cache, cùng thấy trống, cùng `await` tải. Không có data race, nhưng có **race logic**.

Code gốc còn hai lỗi nữa: mỗi caller có request riêng nên huỷ một caller chỉ huỷ request của nó (đúng về hành vi nhưng tốn băng thông), và cache không giới hạn.

### Cách sửa

1. **Lưu "việc đang làm" thay vì chỉ "kết quả".** `downloads: [URL: Download]` giữ task tải đang chạy. Caller đến sau đăng ký vào download sẵn có.
2. **Mỗi caller một continuation.** Nếu caller chỉ `await download.task.value`, khi caller bị huỷ nó vẫn phải ngồi chờ task xong (`Task.value` không phản ứng với cancellation của người chờ). Với `withCheckedThrowingContinuation` + `withTaskCancellationHandler`, caller bị huỷ được resume ngay bằng `CancellationError`.
3. **Đếm waiter.** Waiter cuối rời đi thì `task.cancel()`.
4. **Token cho mỗi download.** Task đã bị huỷ vẫn chạy tới cuối và gọi `complete`. Nếu trong lúc đó đã có download mới cho cùng URL, so token giúp bỏ qua kết quả cũ.
5. **LRU theo byte.** Không cache ảnh lớn hơn toàn bộ dung lượng.

### Race quan trọng nhất: huỷ trước khi kịp đăng ký

`onCancel` chạy đồng bộ ngay trên thread gọi `cancel()`, không phải trên actor. Có thể nó chạy **trước** khi continuation được đăng ký. Đáp án xử lý bằng hai lớp:

- `join` (chạy đồng bộ trên actor) kiểm tra `Task.isCancelled` trước khi đăng ký.
- `onCancel` tạo `Task { await self.leave(...) }`. Task này phải xếp hàng chờ actor, nên luôn chạy **sau** `join`.

### Cách sửa trông đúng nhưng sai

| Cách sửa | Vì sao sai |
| --- | --- |
| `var inFlight: [URL: Task<Data, Error>]`, caller `await inFlight[url]!.value` | Đúng ý 1.1 nhưng hỏng 1.4/1.5: caller bị huỷ không thoát ngay; không biết khi nào mọi caller đã rời đi để huỷ request. |
| Tạo task bằng `async let` hoặc gọi mạng trực tiếp trong caller đầu tiên | Caller đầu bị huỷ thì request bị huỷ theo, mọi caller khác nhận `CancellationError`. |
| Xoá `inFlight[url]` trong `defer` ngay sau `await` | Nếu download cũ bị huỷ và đã có download mới, `defer` của cái cũ xoá mất entry của cái mới. Đó là lý do cần token. |
| Dùng `NSCache` với `countLimit` | Không giới hạn theo byte; `NSCache` cũng có thể tự xoá bất kỳ lúc nào nên test 1.6 không ổn định. Chấp nhận được trong app thật nếu dùng `totalCostLimit`. |

### Mở rộng

- LRU O(1): dictionary + danh sách liên kết đôi.
- Xoá cache khi nhận `UIApplication.didReceiveMemoryWarningNotification`.
- Cache đĩa (tầng 2) với giới hạn và thời hạn.
- Ưu tiên tải: ảnh đang hiển thị trước, ảnh prefetch sau (`TaskPriority`).

---

## Bài 2 · AuthenticatedClient

### Nguyên nhân gốc

Mỗi request tự refresh khi gặp 401. Với **refresh-token rotation**, refresh token chỉ dùng được một lần. Lần refresh thứ hai dùng token đã bị vô hiệu → `invalidGrant` → app tưởng phiên hết hạn. Đây là lỗi phổ biến nhất khi tích hợp OAuth trên mobile.

Hai lỗi phụ: đệ quy `send` không có điểm dừng, và mọi lỗi refresh đều bị xử lý như nhau.

### Cách sửa

1. **Single-flight.** `refreshTask: Task<TokenPair, Error>?`. Request gặp 401 mà đang có refresh thì chờ chung.
2. **So token đã dùng với token hiện tại.** Request gửi bằng `access-0`, khi nó nhận 401 thì client đã có `access-1` → chỉ retry. Không có bước này, request chậm sẽ refresh bằng `refresh-1` và đốt luôn token mới (test 2.3).
3. **Retry đúng một lần**, vẫn 401 thì `.unauthorized`.
4. **Phân loại lỗi.** `invalidGrant` → xoá token, `.sessionExpired`. Lỗi khác (mạng, timeout, 5xx) → giữ token, ném lỗi gốc.

Task refresh là **task không cấu trúc** bắt `self` nên được cô lập trên actor. Nhờ đó:
- Caller đầu tiên bị huỷ thì refresh vẫn chạy tiếp cho những người khác.
- Ghi `currentTokens` và `refreshTask = nil` không cần `await`, không có khoảng hở để race.

### Cách sửa trông đúng nhưng sai

| Cách sửa | Vì sao sai |
| --- | --- |
| Thêm `var isRefreshing = false`, request khác thấy `true` thì `Task.sleep` rồi thử lại | Polling, chậm, và vẫn race. Bị trừ điểm review. |
| Chỉ làm single-flight, không so token | Hỏng test 2.3: request chậm nhận 401 sau khi refresh xong sẽ refresh lần 2. |
| `refreshTask = nil` ngay sau `await task.value` trong caller | Nếu nhiều caller cùng chờ, ai resume trước sẽ xoá task; vẫn đúng. Nhưng nếu caller đầu bị huỷ thì không ai xoá → task cũ (đã xong) bị dùng lại mãi. Đặt việc dọn vào chính task (`defer`) an toàn hơn. |
| Bọc refresh trong `withTaskGroup` / `async let` | Refresh bị huỷ theo caller đầu tiên. |
| Bắt mọi lỗi refresh và xoá token | Mất mạng trong thang máy = bị đăng xuất (test 2.5). |

### Mở rộng

- Refresh chủ động trước khi hết hạn dựa trên `exp` của JWT.
- Hai process cùng refresh (app + extension): cần khoá liên tiến trình (file lock trong App Group) hoặc để chỉ app chính refresh.
- Phân biệt 401 vì token hết hạn với 403 vì thiếu quyền.

---

## Bài 3 · SearchViewModel

### Nguyên nhân gốc

Mỗi lần gõ tạo một `Task` mới mà không huỷ cái cũ. Task nào về sau cùng thì ghi `results`, bất kể nó thuộc truy vấn nào. Ngay cả khi đã huỷ task cũ, **API vẫn có thể trả về** (fake trong bài phớt lờ cancellation, giống nhiều backend thật). Cancellation trong Swift là hợp tác, không phải cưỡng chế.

Lỗi phụ: `catch` hiện mọi lỗi kể cả `CancellationError`; không cắt khoảng trắng; ô chỉ có khoảng trắng vẫn gọi API.

### Cách sửa

1. Chuẩn hoá truy vấn, bỏ qua nếu trùng.
2. `searchTask?.cancel()` trước khi tạo task mới. Debounce nằm **trong** task nên bị huỷ cùng.
3. **Kiểm tra trước khi ghi:** `!Task.isCancelled && normalized == query`. Đây là dòng quan trọng nhất của bài.
4. Áp dụng cùng phép kiểm tra trong `catch`: lỗi của task lỗi thời bị bỏ qua. Cách này xử lý luôn `URLError(.cancelled)` mà không cần liệt kê từng loại lỗi huỷ.
5. `[weak self]` để màn hình đóng giữa chừng thì ViewModel vẫn được giải phóng.

### Cách sửa trông đúng nhưng sai

| Cách sửa | Vì sao sai |
| --- | --- |
| Chỉ thêm `searchTask?.cancel()` | API không tôn trọng cancellation → kết quả cũ vẫn ghi đè (test 3.1). |
| `catch is CancellationError { }` rồi hiện mọi lỗi khác | `URLSession` ném `URLError(.cancelled)` → vẫn hiện banner lỗi trong app thật. |
| Dùng biến đếm `requestID` nhưng tăng nó **bên trong** task | Task chưa chạy tới dòng tăng thì task khác đã chạy → so sai. Phải chụp giá trị lúc tạo task. |
| Debounce bằng `Timer` / `DispatchWorkItem` bên ngoài task | Được, nhưng có hai cơ chế huỷ khác nhau phải đồng bộ với nhau, dễ sót. |

### Mở rộng

- SwiftUI: `.task(id: query) { ... }` tự huỷ task cũ khi `query` đổi. Vẫn phải tự lo kiểm tra trước khi ghi nếu API không tôn trọng huỷ.
- Cache kết quả theo truy vấn để gõ lùi (backspace) hiện ngay.
- Hiển thị "đang tìm" chỉ sau 150 ms để tránh nhấp nháy.

---

## Bài 4 · EventBatcher

### Nguyên nhân gốc

1. **Data race thật.** `buffer` là `Array` bị ghi từ nhiều thread. `Array` không an toàn luồng; hai `append` đồng thời có thể làm hỏng bộ nhớ → `EXC_BAD_ACCESS`. `@unchecked Sendable` là lời hứa với compiler rằng "tôi tự lo", và code đã không giữ lời.
2. **Mất sự kiện.** `flush` chụp `buffer`, `await upload`, rồi `buffer.removeAll()`. Sự kiện log trong lúc upload bị xoá luôn.
3. **Gửi trùng.** Hai `flush` cùng chụp cùng nội dung buffer.
4. **Không giới hạn.** Offline lâu → buffer phình vô hạn.

### Cách sửa

- `log` phải đồng bộ → dùng **lock** cho buffer, không dùng actor. Lock được giữ cực ngắn: append, cắt overflow, quyết định có tự flush không.
- **Không bao giờ giữ lock qua `await`.** Lấy batch ra khỏi buffer trong lock → upload ngoài lock → lỗi thì trả về đầu buffer trong lock. Swift 6 cũng chặn điều này: closure của `withLock` không phải `async`.
- **Tuần tự hoá flush bằng chuỗi Task** (`FlushSerializer`). Một actor đơn thuần là chưa đủ: actor reentrant tại `await upload`, nên lời gọi flush thứ hai sẽ chen vào giữa. Mỗi việc mới `await previous?.value` trước khi chạy.
- Cờ `autoFlushScheduled` tránh tạo hàng nghìn Task khi log dồn dập.

### Cách sửa trông đúng nhưng sai

| Cách sửa | Vì sao sai |
| --- | --- |
| Đổi thành `actor EventBatcher` | `log` thành `async`, phá API; mọi chỗ gọi trong code cũ phải đổi thành `Task { await batcher.log(e) }` và **mất thứ tự** sự kiện. |
| `DispatchQueue` serial + `sync` cho `log` | Chạy được, nhưng `flush` async trên queue đó dễ dẫn tới deadlock nếu ai đó gọi từ chính queue. Lock gọn hơn. |
| Giữ `buffer.removeAll()` nhưng chuyển vào lock | Vẫn mất sự kiện log trong lúc upload. Phải lấy batch ra **trước** khi upload. |
| Actor `isFlushing` + `return` sớm nếu đang flush | Hỏng 4.5: caller thứ hai trả về trước khi sự kiện của nó được gửi. |
| Chèn batch lỗi vào **cuối** buffer | Sai thứ tự: sự kiện mới hơn được gửi trước. |

### Mở rộng

- Exponential backoff khi upload lỗi liên tiếp; tạm dừng khi `NWPathMonitor` báo mất mạng.
- Ghi buffer xuống đĩa khi app vào background để không mất khi bị kill.
- Gom theo thời gian (flush mỗi 30 giây) bên cạnh gom theo số lượng.

---

## Bài 5 · PriceFeed + PriceViewModel

### Nguyên nhân gốc

**PriceFeed**
1. `if !isConnected { await socket.connect(); isConnected = true }`: lại là reentrancy. Hai subscriber cùng thấy `false` trước khi ai kịp đặt `true`.
2. Subscriber không bao giờ bị xoá: không có `onTermination`.
3. Không bao giờ `disconnect()`.
4. `isConnected` không bao giờ về `false` nên không thể kết nối lại.

**PriceViewModel**
1. `Task { for await tick in stream { self.latest = tick } }` giữ `self` mạnh. Stream không bao giờ kết thúc → Task không bao giờ kết thúc → ViewModel không bao giờ được giải phóng. Đây là retain cycle kiểu mới: không cần `self` giữ Task, chỉ cần Task giữ `self` và không bao giờ xong.
2. `stop()` không huỷ Task.

### Cách sửa

**PriceFeed** là một máy trạng thái:

```
idle ──connect()──▶ connecting(id, task) ──thành công──▶ live(id, pump)
  ▲                       │ (mọi người đã rời đi)          │
  └──────── disconnect ◀──┴────────────────────────────────┘
```

- Subscriber đến khi `connecting` thì chờ chung task kết nối.
- Sau `await task.value`, **kiểm tra lại trạng thái**: kết nối đó còn là kết nối hiện tại không, còn ai cần không.
- `onTermination` của mỗi stream gọi `unsubscribe`. Subscriber cuối rời đi khi `live` → đóng socket.
- Mỗi kết nối có `id` để vòng pump của kết nối cũ kết thúc muộn không phá kết nối mới.

**PriceViewModel**

- `[weak self]` và `guard let self` **bên trong thân vòng lặp**. `self` mạnh chỉ tồn tại trong một lượt lặp; khi đang `await` phần tử tiếp theo thì không có tham chiếu mạnh nào.
- Task được giữ trong `SubscriptionHandle`. ViewModel chết → handle chết → `deinit` của handle huỷ Task → stream kết thúc → `onTermination` → feed huỷ đăng ký → socket đóng. Cả chuỗi dọn dẹp tự chạy dù quên `stop()`.
- `generation` chặn task cũ (đã bị stop) đặt `isStreaming = false` sau khi đã `start()` lại.

### Vì sao không huỷ Task trong `deinit` của ViewModel?

Ở Swift 6, `deinit` của class `@MainActor` là **nonisolated**: không được đọc property `@MainActor` như `task`. Có ba lối ra:
1. Swift 6.2+: `isolated deinit` (SE-0371).
2. Lưu Task trong property `nonisolated(unsafe)`: được, nhưng phải tự chứng minh an toàn.
3. Để một object `Sendable` riêng giữ Task và huỷ nó trong `deinit` của chính nó (đáp án). Chạy được với mọi phiên bản Swift 6.

### Cách sửa trông đúng nhưng sai

| Cách sửa | Vì sao sai |
| --- | --- |
| `Task { [weak self] in guard let self else { return }; for await tick in stream { self.latest = tick } }` | `guard let self` **trước** vòng lặp tạo tham chiếu mạnh sống suốt vòng lặp. Vẫn rò rỉ (test 5.7). |
| Chỉ huỷ Task trong `stop()` | Màn hình bị đóng theo cách không gọi `onDisappear` (ví dụ dismiss cả navigation stack) → rò rỉ. |
| Dùng `Bool isConnecting` thay vì lưu task kết nối | Subscriber thứ hai không có gì để chờ; phải polling hoặc trả về stream trước khi kết nối xong. |
| Không kiểm tra lại sau `await connect()` | Mọi subscriber rời đi trong lúc kết nối → socket mở mà không ai dùng. |
| `bufferingPolicy: .unbounded` | Màn hình bị che (không tiêu thụ) mà giá vẫn đến → bộ nhớ tăng mãi. Với giá, chỉ cần giá mới nhất. |

### Mở rộng

- Tự kết nối lại với exponential backoff + jitter; thêm trạng thái `reconnecting(attempt)`.
- Gửi lệnh subscribe/unsubscribe theo mã lên server để server chỉ đẩy mã đang xem.
- Đóng socket khi app vào background, mở lại khi active (`scenePhase`).

---

## Nhìn lại cả năm bài

Ba mẫu lỗi lặp lại:

1. **Kiểm tra → `await` → hành động** trong actor (Bài 1, 2, 5). Sau mỗi `await`, mọi giả định về state đều phải kiểm tra lại. Cách chữa: lưu "việc đang làm" (Task) thay vì "cờ đang làm" (Bool), và dùng id/token để nhận ra kết quả lỗi thời.
2. **Cancellation là hợp tác** (Bài 1, 3). Huỷ Task không dừng được code bên ngoài; phải tự kiểm tra trước khi ghi state, và `Task.value` không phản ứng với việc người chờ bị huỷ.
3. **Vòng đời của Task** (Bài 2, 5). Task có cấu trúc chết cùng cha; task không cấu trúc sống độc lập. Chọn sai thì hoặc huỷ nhầm việc của người khác, hoặc giữ object sống mãi.
