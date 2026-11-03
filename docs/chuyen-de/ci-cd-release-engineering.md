# Chuyên đề B — CI/CD và Release Engineering cho iOS (mức Senior)

**Dành cho ai:** đã xong Tháng 9 (đã có pipeline PR và đưa build lên TestFlight). Chuyên đề này nâng từ "có pipeline" lên "sở hữu hệ thống phát hành": tái lập được, nhanh, an toàn chuỗi cung ứng, tự động hoá phát hành theo giai đoạn, có cổng chất lượng và có số liệu DORA.

**Khi nào học:** như "Tháng 14", hoặc mỗi Thứ Bảy song song với Tháng 10–12.

**Đầu ra:** capstone **"Hệ thống phát hành"** cho dự án xuyên suốt: PR dưới 10 phút, phát hành từ tag tới TestFlight không thao tác tay, signing không có bí mật lưu lâu trên runner, phased release tự tạm dừng khi chỉ số xấu, dashboard DORA. Chấm theo barem ở cuối file.

**Mức độ:** khó. Mọi bài tập có tiêu chí đo được (phút, %, số lần thất bại). Lệnh và tên build setting thay đổi theo phiên bản Xcode: đối chiếu `man xcodebuild` và release notes của Xcode bạn dùng.

[← Mục lục](../../README.md) · [← Chuyên đề AI](ai-tren-ios.md)

---

## Tuần 1 · Pipeline tái lập được và nhanh

### Buổi 1 — Nguyên lý và chỉ số DORA cho mobile

**Kiến thức**
- Bốn chỉ số DORA: **tần suất phát hành**, **lead time** (commit → người dùng), **tỉ lệ thay đổi gây lỗi**, **thời gian khôi phục**. Mobile có đặc thù: App Review, người dùng không tự cập nhật, không thể rollback bản đã phát hành.
- Trunk-based development: nhánh ngắn (< 2 ngày), merge thường xuyên, tính năng dở dang nằm sau feature flag. Release branch chỉ để ổn định bản phát hành.
- Pipeline là code: lưu trong repo, được review như code, chạy được trên máy dev.

**Ví dụ (cách đo lead time cho một bản iOS)**
```
lead_time = thời điểm bản phát hành đạt 100% phased release
          − thời điểm commit cũ nhất trong bản đó được merge vào main
Thành phần: chờ release train + build/test + TestFlight QA + App Review + phased rollout
→ Thành phần nào chiếm nhiều nhất thì tối ưu thành phần đó trước.
```

**Bài tập:** Đo 4 chỉ số DORA cho 5 bản phát hành gần nhất của một app thật bạn làm (hoặc dự án xuyên suốt, dùng dữ liệu TestFlight). Phân rã lead time thành các thành phần như trên. Viết đề xuất 1 trang: 3 thay đổi quy trình giảm lead time nhiều nhất, có ước lượng.

### Buổi 2 — Build tái lập được

**Kiến thức**
- Ghim phiên bản Xcode (file `.xcode-version` + công cụ `xcodes`), ghim simulator runtime, ghim dependency (`Package.resolved` được commit).
- CI không được tự nâng dependency: `-onlyUsePackageVersionsFromResolvedFile` (hoặc `-disableAutomaticPackageResolution`) để fail nếu `Package.resolved` lệch.
- Biến môi trường, locale, timezone của runner ảnh hưởng tới test; đặt cố định (`TZ=Asia/Ho_Chi_Minh`, `LANG=en_US.UTF-8`) hoặc làm test độc lập với chúng.

**Ví dụ**
```bash
# scripts/ci/bootstrap.sh
set -euo pipefail
XCODE_VERSION="$(cat .xcode-version)"
sudo xcodes select "$XCODE_VERSION"
xcodebuild -version
xcodebuild -resolvePackageDependencies \
  -onlyUsePackageVersionsFromResolvedFile \
  -clonedSourcePackagesDirPath .spm
git diff --exit-code Package.resolved   # fail nếu resolve làm thay đổi file
```

**Bài tập:** Làm cho build của dự án tái lập được: ghim Xcode, ghim dependency, cố định môi trường. Kiểm chứng bằng cách build cùng một commit trên 2 runner khác nhau và trên máy bạn, so sánh checksum của binary Swift module chính (ghi nhận phần nào khác và vì sao: timestamp, đường dẫn).

### Buổi 3 — Tăng tốc build và test

**Kiến thức**
- Tách `build-for-testing` (một lần) và `test-without-building` (chia nhiều shard song song trên nhiều simulator hoặc nhiều runner) dùng file `.xctestrun`.
- Cache: thư mục SwiftPM đã clone, DerivedData (cẩn thận: cache hỏng gây lỗi khó hiểu, phải có khoá cache theo `Package.resolved` + phiên bản Xcode). Xcode 26 có compilation caching (build setting cho phép tái dùng kết quả biên dịch); kiểm tra tên setting trong release notes trước khi bật.
- Parallel testing trong một máy: `-parallel-testing-enabled YES -parallel-testing-worker-count N`. Test phải độc lập mới song song được.

**Ví dụ**
```bash
xcodebuild build-for-testing -scheme Shop \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/dd -clonedSourcePackagesDirPath .spm

XCTESTRUN=$(ls build/dd/Build/Products/*.xctestrun)
# Shard 1/2 và 2/2 chạy trên 2 job khác nhau
xcodebuild test-without-building -xctestrun "$XCTESTRUN" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ShopTests/CartTests -only-testing:ShopTests/CheckoutTests \
  -parallel-testing-enabled YES -resultBundlePath build/shard1.xcresult
```

**Bài tập:** Đo thời gian pipeline PR hiện tại theo từng bước. Áp dụng: cache có khoá đúng, build-for-testing một lần, chia test thành 3 shard cân bằng theo thời gian chạy (dựa trên dữ liệu từ `.xcresult` lần trước). Mục tiêu: giảm ≥ 40% thời gian từ lúc mở PR tới lúc có kết quả.

### Buổi 4 — Đọc `.xcresult`, báo cáo và phát hiện test flaky

**Kiến thức**
- `xcrun xcresulttool get test-results summary|tests --path X.xcresult` xuất JSON (Xcode 16+): số test, thất bại, thời gian từng test, lần retry.
- Chạy lại test thất bại để phân loại flaky: `-retry-tests-on-failure -test-iterations 3`. Test đạt ở lần retry là **flaky**, không phải "xanh".
- Gắn kết quả vào PR: chú thích dòng code thất bại (GitHub annotations), tóm tắt trong comment, đính kèm `.xcresult` khi đỏ.

**Ví dụ**
```bash
xcrun xcresulttool get test-results tests --path build/shard1.xcresult > tests.json
# Lấy 10 test chậm nhất để cân bằng shard
jq -r '[.. | objects | select(.nodeType? == "Test Case") | {name: .name, d: (.durationInSeconds // 0)}]
       | sort_by(-.d) | .[:10][] | "\(.d)s \(.name)"' tests.json
```

**Bài tập:** Viết script (Swift script hoặc Python) đọc mọi `.xcresult` của pipeline, xuất: tổng hợp đạt/thất bại, top 10 test chậm, danh sách test flaky (đạt sau retry). Lưu lịch sử 30 lần chạy, tự mở issue cho test flaky ≥ 3 lần/30. Đăng tóm tắt thành comment trên PR.

### Buổi 5 — Thực hành tuần 1: PR dưới 10 phút

**Bài tập:** Dựng lại pipeline PR của dự án xuyên suốt: bootstrap tái lập, cache, build-for-testing + 3 shard, retry phân loại flaky, `swift test` cho package thuần chạy song song trên runner rẻ, báo cáo lên PR, `concurrency` huỷ lần chạy cũ khi có commit mới. Nghiệm thu: p50 thời gian ≤ 10 phút trên 10 PR liên tiếp, 0 lần đỏ do hạ tầng (không phải do code).

---

## Tuần 2 · Signing và an toàn chuỗi cung ứng

### Buổi 6 — Signing tự động không lộ bí mật

**Kiến thức**
- Ba cách: (1) Fastlane `match` (chứng chỉ mã hoá trong repo riêng), (2) cloud-managed signing qua `xcodebuild -allowProvisioningUpdates` với App Store Connect API key, (3) Xcode Cloud tự quản lý.
- Trên runner dùng chung: tạo **keychain tạm** cho mỗi job, import chứng chỉ, đặt partition list để `codesign` dùng không cần hỏi, xoá keychain ở bước cuối (kể cả khi job thất bại).
- API key App Store Connect: quyền tối thiểu (App Manager hoặc Developer, không Admin), lưu dạng secret, xoay vòng định kỳ.

**Ví dụ**
```bash
# scripts/ci/signing-setup.sh
set -euo pipefail
KC="$RUNNER_TEMP/build.keychain-db"; KC_PW="$(openssl rand -base64 24)"
security create-keychain -p "$KC_PW" "$KC"
security set-keychain-settings -lut 3600 "$KC"
security unlock-keychain -p "$KC_PW" "$KC"
echo "$DIST_CERT_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/dist.p12"
security import "$RUNNER_TEMP/dist.p12" -k "$KC" -P "$DIST_CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PW" "$KC"
security list-keychains -d user -s "$KC" $(security list-keychains -d user | tr -d '"')
rm "$RUNNER_TEMP/dist.p12"
# Bước dọn (luôn chạy): security delete-keychain "$KC"
```

**Bài tập:** Cài signing cho pipeline phát hành theo 2 cách (keychain tạm + profile, và cloud-managed signing với API key). So sánh: số secret phải lưu, thời gian setup, rủi ro khi runner bị xâm nhập. Chứng minh bước dọn chạy cả khi build thất bại (cố tình làm build lỗi).

### Buổi 7 — Quản lý secret và quyền của pipeline

**Kiến thức**
- Nguyên tắc tối thiểu quyền: `permissions:` của GitHub Actions mặc định `contents: read`; job phát hành mới có quyền ghi.
- **Environment** có bảo vệ: job phát hành chỉ chạy khi có người duyệt, chỉ từ nhánh/tag được phép; secret phát hành chỉ thuộc environment đó, không lộ cho job PR.
- PR từ fork không được nhận secret. Không in secret ra log; cẩn thận `set -x`. Ghim action theo commit SHA, không theo tag di động.

**Ví dụ**
```yaml
name: Release
on:
  push:
    tags: ["v*.*.*"]
permissions:
  contents: read
jobs:
  release:
    runs-on: macos-15
    environment: production          # cần người duyệt, chỉ cho tag v*
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@<commit-sha-40-ky-tu>   # ghim SHA
      - run: ./scripts/ci/signing-setup.sh
        env:
          DIST_CERT_P12_BASE64: ${{ secrets.DIST_CERT_P12_BASE64 }}
          DIST_CERT_PASSWORD: ${{ secrets.DIST_CERT_PASSWORD }}
      - run: ./scripts/ci/archive-and-upload.sh
      - if: always()
        run: ./scripts/ci/signing-cleanup.sh
```

**Bài tập:** Rà toàn bộ workflow của dự án theo checklist 12 mục (quyền mặc định, environment, fork PR, action ghim SHA, secret trong log, `pull_request_target` nguy hiểm, cache bị đầu độc, thời hạn API key...). Sửa mọi mục chưa đạt. Viết lịch xoay vòng secret và thử xoay một secret mà không làm gián đoạn pipeline.

### Buổi 8 — An toàn chuỗi cung ứng phần mềm

**Kiến thức**
- Dependency là code của người khác chạy trong app bạn: ghim phiên bản chính xác cho app, xem diff khi nâng, ưu tiên thư viện có bảo trì, có privacy manifest.
- Binary target (`.xcframework`) phải có `checksum`; không tải binary từ URL không cố định.
- SBOM (danh sách thành phần) cho mỗi bản phát hành; quét giấy phép (GPL không phù hợp App Store); cập nhật tự động bằng Dependabot (hỗ trợ Swift Package Manager) kèm pipeline test đầy đủ.

**Ví dụ**
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "swift"
    directory: "/"
    schedule: { interval: "weekly" }
    open-pull-requests-limit: 5
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
```
```bash
# SBOM cho bản phát hành (ví dụ dùng syft)
syft dir:. -o spdx-json > build/sbom-$(git describe --tags).spdx.json
```

**Bài tập:** Sinh SBOM cho dự án, lập bảng giấy phép của mọi dependency, bật Dependabot cho Swift và GitHub Actions. Viết chính sách "thêm dependency mới" 1 trang (tiêu chí, người duyệt, kiểm tra privacy manifest, kế hoạch thoát nếu thư viện ngừng bảo trì). Đính kèm SBOM vào GitHub Release tự động.

### Buổi 9 — Kiểm tra artifact trước khi phát hành

**Kiến thức**
- Kiểm tra tự động trên chính file `.ipa` sẽ gửi đi: entitlements đúng môi trường (không còn `get-task-allow`, `aps-environment = production`), bundle id, version/build, privacy manifest có mặt, không còn URL staging.
- So sánh với bản phát hành trước để phát hiện thay đổi bất thường (thêm quyền, tăng kích thước).
- Fail sớm trước khi chờ App Review cả ngày mới biết lỗi.

**Ví dụ**
```bash
unzip -q build/export/Shop.ipa -d build/ipa
APP=build/ipa/Payload/Shop.app
codesign -d --entitlements :- "$APP" > build/entitlements.plist
/usr/libexec/PlistBuddy -c "Print :aps-environment" build/entitlements.plist | grep -q production
! /usr/libexec/PlistBuddy -c "Print :get-task-allow" build/entitlements.plist 2>/dev/null | grep -q true
test -f "$APP/PrivacyInfo.xcprivacy"
! grep -R "staging-api.example.com" "$APP" --binary-files=text -q
```

**Bài tập:** Viết `scripts/ci/verify-ipa.sh` kiểm tra 10 điều kiện cho artifact phát hành (gồm các điều trên + kích thước so với bản trước không tăng quá 5% nếu không có nhãn PR `size-increase-approved`). Chạy như một bước bắt buộc trước khi tải lên.

### Buổi 10 — Thực hành tuần 2: pipeline phát hành an toàn

**Bài tập:** Pipeline `Release` chạy khi đẩy tag `v*`: cần người duyệt trong environment `production`, signing bằng keychain tạm hoặc cloud-managed, build tái lập, `verify-ipa.sh`, tải lên App Store Connect, đính SBOM vào GitHub Release, dọn bí mật trong mọi trường hợp. Nghiệm thu: một người khác trong team phát hành được chỉ bằng `git tag v1.2.0 && git push --tags` + bấm duyệt.

---

## Tuần 3 · Release engineering

### Buổi 11 — Release train, nhánh phát hành và ghi chú phát hành

**Kiến thức**
- Release train: cắt bản theo lịch cố định (ví dụ mỗi 2 tuần), tính năng chưa xong thì đi chuyến sau hoặc nằm sau flag. Giảm áp lực "cố nhồi cho kịp".
- Nhánh `release/1.4`: chỉ nhận cherry-pick sửa lỗi đã merge vào `main` trước. Tự động hoá việc cắt nhánh, tăng version, mở PR cherry-pick.
- Ghi chú phát hành tự động từ commit theo quy ước (Conventional Commits) hoặc nhãn PR; người viết nội dung chỉ biên tập lại.

**Ví dụ**
```bash
# Cắt release branch mỗi Thứ Hai tuần chẵn
VERSION=$(./scripts/version next-minor)            # 1.4.0
git switch -c "release/${VERSION%.*}" origin/main
agvtool new-marketing-version "$VERSION"
git commit -am "chore(release): cut $VERSION"
git push -u origin HEAD
git log --pretty='- %s' "$(git describe --tags --abbrev=0)"..HEAD \
  | grep -E '^- (feat|fix)' > build/release-notes-draft.md
```

**Bài tập:** Viết quy trình release train cho team 6 iOS dev: lịch, ai cắt nhánh, tiêu chí đóng băng, quy trình hotfix, cách xử lý tính năng trễ chuyến. Tự động hoá: workflow hẹn giờ cắt nhánh, tăng version, sinh bản nháp ghi chú phát hành tiếng Việt và tiếng Anh theo nhóm (tính năng mới, sửa lỗi).

### Buổi 12 — Tự động hoá App Store Connect API

**Kiến thức**
- Xác thực bằng JWT ký ES256 từ API key (`kid`, `iss`, `aud: appstoreconnect-v1`, hạn tối đa 20 phút).
- Tác vụ tự động được: tạo phiên bản, cập nhật metadata và "Có gì mới", gán build vào nhóm TestFlight, gửi duyệt, bật và điều khiển phased release, đọc phản hồi tester.
- Tôn trọng giới hạn tần suất; mọi script phải idempotent (chạy lại không tạo bản trùng).

**Ví dụ (tạm dừng phased release)**
```swift
// Swift script: ./scripts/asc/pause-phased-release.swift <phasedReleaseID>
var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com/v1/appStoreVersionPhasedReleases/\(phasedReleaseID)")!)
request.httpMethod = "PATCH"
request.setValue("Bearer \(try makeJWT(keyID: env("ASC_KEY_ID"), issuer: env("ASC_ISSUER_ID"), p8: env("ASC_KEY_P8")))",
                 forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = Data("""
{"data":{"type":"appStoreVersionPhasedReleases","id":"\(phasedReleaseID)",
 "attributes":{"phasedReleaseState":"PAUSED"}}}
""".utf8)
let (_, response) = try await URLSession.shared.data(for: request)
precondition((response as? HTTPURLResponse)?.statusCode == 200)
// makeJWT: dùng CryptoKit P256.Signing.PrivateKey(pemRepresentation:) ký header.payload
```

**Bài tập:** Viết công cụ dòng lệnh Swift `asc` (dùng `swift-argument-parser`) với 4 lệnh: `testflight assign --build --group`, `whatsnew set --locale --file`, `phased pause|resume`, `status` (in trạng thái bản đang duyệt/đang phát hành). Ký JWT bằng CryptoKit, có test cho phần ký với khoá thử nghiệm.

### Buổi 13 — Phát hành theo giai đoạn có lưới an toàn

**Kiến thức**
- Ba lớp an toàn: **feature flag** (tắt tính năng ngay lập tức), **phased release** (giới hạn số người nhận bản mới), **kill switch / phiên bản tối thiểu** (chặn bản lỗi nghiêm trọng).
- Định nghĩa trước *guardrail metrics* và ngưỡng: crash-free users, tỉ lệ hang, tỉ lệ lỗi API, chỉ số nghiệp vụ (tỉ lệ đặt hàng thành công). Quyết định dừng phải dựa trên số liệu, không dựa trên cảm giác.
- So sánh theo phiên bản (bản mới vs bản cũ cùng thời điểm), cần đủ mẫu trước khi kết luận.

**Ví dụ (quy tắc tự động dừng)**
```
Mỗi giờ trong 7 ngày phased release:
  n_mới = số phiên trên bản mới trong 24h qua
  nếu n_mới ≥ 2.000 và (crash_free_mới < crash_free_cũ − 0,3 điểm %
                          hoặc tỉ_lệ_đặt_hàng_mới < tỉ_lệ_cũ × 0,95):
      → asc phased pause
      → tắt flag của tính năng mới trong bản này
      → nhắn kênh #release kèm số liệu, gắn người trực
```

**Bài tập:** Cài job hẹn giờ "release guardian" theo quy tắc trên: đọc chỉ số từ dịch vụ crash/analytics (hoặc từ một API giả lập bạn tự viết), gọi công cụ `asc` để tạm dừng, tắt flag, gửi thông báo. Viết test với dữ liệu giả cho 6 tình huống (đủ mẫu/chưa đủ, vượt ngưỡng crash, vượt ngưỡng nghiệp vụ, dao động nhỏ không dừng...).

### Buổi 14 — Quan sát sức khoẻ bản phát hành

**Kiến thức**
- Tải dSYM tự động sau mỗi build phát hành; kiểm tra crash report đã được symbolicate (crash không symbolicate = mù).
- Dashboard theo phiên bản: crash-free users/sessions, hang rate, thời gian khởi động (MetricKit), tỉ lệ cập nhật lên bản mới, top crash mới xuất hiện.
- Liên kết crash với commit/PR: gắn version + build + commit SHA vào báo cáo.

**Ví dụ**
```bash
# Sau archive: tải dSYM (ví dụ Crashlytics; dịch vụ khác có CLI tương tự)
find build/Shop.xcarchive/dSYMs -name "*.dSYM" -print0 \
  | xargs -0 -I{} "$UPLOAD_SYMBOLS_TOOL" -gsp GoogleService-Info.plist -p ios {}
```

**Bài tập:** Dựng dashboard sức khoẻ phát hành (Grafana, Looker Studio hoặc trang HTML tĩnh do pipeline sinh) với 6 chỉ số theo phiên bản, cập nhật mỗi giờ. Thêm kiểm tra trong pipeline: build phát hành thất bại nếu tải dSYM không thành công.

### Buổi 15 — Thực hành tuần 3: release guardian

**Bài tập:** Diễn tập toàn bộ: phát hành bản có lỗi cố ý (sau flag, chỉ crash ở 5% người dùng giả lập), release guardian phát hiện và tự dừng trong vòng 1 giờ giả lập, tắt flag, thông báo, rồi bạn phát hành bản sửa qua quy trình hotfix. Viết postmortem và đo thời gian khôi phục (MTTR).

---

## Tuần 4 · Cổng chất lượng và nền tảng CI

### Buổi 16 — Cổng chất lượng tự động

**Kiến thức**
- Cổng chặn merge phải **khách quan và ổn định**, nếu không team sẽ học cách bỏ qua: coverage của phần code thay đổi (không phải coverage tổng), ngân sách kích thước app, hồi quy hiệu năng so với baseline, accessibility audit, không cảnh báo mới.
- Phân biệt cổng chặn (đỏ = không merge) và cổng cảnh báo (comment lên PR).
- Mỗi cổng có chủ sở hữu và quy trình ngoại lệ có ghi lại (nhãn PR + người duyệt).

**Ví dụ (coverage của dòng thay đổi)**
```bash
xcrun xccov view --report --json build/test.xcresult > coverage.json
git diff -U0 origin/main...HEAD -- '*.swift' > changes.diff
# script: giao các dòng thêm mới trong changes.diff với dòng có executionCount trong coverage.json
swift scripts/diff-coverage.swift changes.diff coverage.json --min 80
```

**Bài tập:** Cài 4 cổng: coverage dòng thay đổi ≥ 80% (chặn), kích thước tải về không tăng > 3% (chặn, có ngoại lệ), benchmark thời gian khởi động không chậm hơn baseline > 10% (cảnh báo), accessibility audit cho 5 màn hình (chặn). Viết `diff-coverage.swift`. Chạy trên 10 PR thật, ghi số lần cổng chặn đúng và chặn nhầm.

### Buổi 17 — Pipeline đêm: eval AI, test dài, kiểm tra sâu

**Kiến thức**
- Việc chậm hoặc không tất định không nên chặn PR: bộ eval AI, UI test đầy đủ trên nhiều thiết bị, test lặp lại tìm flaky, Thread/Address Sanitizer toàn bộ, test trên iOS thấp nhất được hỗ trợ.
- Pipeline đêm chạy trên `main`, so với baseline, mở issue tự động khi hồi quy và gắn người thay đổi gần nhất ở vùng code liên quan.
- Kết quả eval AI là chuỗi thời gian: lưu theo ngày để thấy xu hướng, không chỉ đạt/không đạt.

**Ví dụ**
```yaml
name: Nightly
on:
  schedule: [{ cron: "0 19 * * *" }]   # 02:00 giờ Việt Nam
jobs:
  ai-eval:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@<sha>
      - run: swift test --filter Eval --parallel 2>&1 | tee eval.log
      - run: swift scripts/eval-report.swift eval.log --baseline eval-baseline.json --max-drop 5 > eval-summary.md
      - if: failure()
        run: gh issue create --title "Hồi quy eval AI $(date +%F)" --body-file eval-summary.md --label ai-regression
```

**Bài tập:** Dựng pipeline đêm cho dự án: eval AI của chuyên đề A với quy tắc chặn thống kê, UI test trên 3 thiết bị và iOS thấp nhất, TSan + ASan toàn bộ, lặp 20 lần tìm flaky. Lưu lịch sử kết quả 30 ngày và vẽ biểu đồ xu hướng tỉ lệ đạt eval.

### Buổi 18 — CI cho codebase nhiều module

**Kiến thức**
- Chỉ build và test những gì bị ảnh hưởng: từ danh sách file thay đổi → module chứa chúng → mọi module phụ thuộc ngược vào đó. Dùng `swift package show-dependencies --format json` hoặc đồ thị của Tuist.
- Sinh project (Tuist, XcodeGen) để bỏ xung đột `project.pbxproj` và để đồ thị module là dữ liệu đọc được.
- Luôn có một đường "chạy tất cả" (pipeline đêm hoặc khi đổi file hạ tầng) để không bỏ sót.

**Ví dụ**
```bash
CHANGED=$(git diff --name-only origin/main...HEAD)
MODULES=$(echo "$CHANGED" | sed -nE 's#^Sources/([^/]+)/.*#\1#p' | sort -u)
if echo "$CHANGED" | grep -qE '^(Package\.swift|Package\.resolved|\.github/|scripts/ci/)'; then
  echo "all"; exit 0
fi
swift scripts/affected-modules.swift --changed $MODULES --graph <(swift package show-dependencies --format json)
# → in ra danh sách test target cần chạy, dùng cho --filter hoặc -only-testing
```

**Bài tập:** Viết `affected-modules.swift` tính tập module bị ảnh hưởng (gồm phụ thuộc ngược bắc cầu), có test cho đồ thị mẫu 8 module. Tích hợp vào pipeline PR. Đo: thời gian trung bình của PR chỉ sửa 1 feature trước và sau; số lần bỏ sót lỗi (kiểm bằng pipeline đêm chạy tất cả) trong 2 tuần.

### Buổi 19 — Hạ tầng runner: chi phí, độ tin cậy, tự host

**Kiến thức**
- Runner macOS đám mây tiện nhưng đắt; tự host (Mac mini, máy ảo macOS với Tart/Anka) rẻ hơn khi dùng nhiều nhưng tốn công vận hành. Giấy phép macOS giới hạn số máy ảo macOS chạy đồng thời trên một máy Apple.
- Runner phải *dùng một lần* (ephemeral): mỗi job một máy ảo sạch, tránh lệch trạng thái và rò rỉ bí mật giữa các job.
- Đo chi phí mỗi PR, thời gian chờ có runner, tỉ lệ job thất bại do hạ tầng. Mục tiêu: thất bại do hạ tầng < 1%.

**Ví dụ (ước lượng chi phí)**
```
PR/ngày: 25 · phút macOS/PR: 12 · ngày làm việc/tháng: 22
→ 6.600 phút macOS/tháng cho PR + pipeline đêm 40 phút × 30 = 1.200
→ ~7.800 phút/tháng. So với 2 Mac mini tự host (khấu hao 24 tháng + điện + công vận hành 4 giờ/tháng)
→ lập bảng điểm hoà vốn theo số phút/tháng.
```

**Bài tập:** Lập phân tích chi phí 1 trang cho 3 phương án (runner đám mây GitHub, Xcode Cloud, tự host 2 máy ảo trên Mac mini) với số liệu thật của dự án. Nếu có máy Mac, dựng một runner tự host ephemeral bằng máy ảo (Tart), chạy pipeline PR trên đó và đo thời gian, tỉ lệ lỗi hạ tầng trong 1 tuần.

### Buổi 20 — Capstone chuyên đề B và chấm điểm

**Bài tập (capstone):** Nộp "Hệ thống phát hành" của dự án xuyên suốt: mọi workflow và script trong repo, tài liệu kiến trúc pipeline (sơ đồ), runbook phát hành và hotfix, dashboard DORA 4 tuần, postmortem của buổi diễn tập, phân tích chi phí.

**Barem chấm (100 điểm):**

| Tiêu chí | Điểm | Đạt tối đa khi |
| --- | --- | --- |
| Tốc độ và tái lập | 15 | p50 PR ≤ 10 phút; build cùng commit cho kết quả như nhau; Xcode và dependency được ghim |
| Độ tin cậy | 10 | Thất bại do hạ tầng < 1%; test flaky được phát hiện và cách ly tự động |
| Signing và bí mật | 15 | Không bí mật tồn tại lâu trên runner; environment có duyệt; action ghim SHA; quyền tối thiểu |
| Chuỗi cung ứng | 10 | SBOM mỗi bản, Dependabot, chính sách dependency, verify-ipa bắt buộc |
| Tự động hoá phát hành | 20 | Tag → TestFlight → gửi duyệt không thao tác tay; công cụ `asc`; ghi chú phát hành tự sinh |
| Lưới an toàn | 20 | Release guardian tự dừng phased release và tắt flag; diễn tập có MTTR đo được |
| Cổng chất lượng và số liệu | 10 | ≥ 4 cổng có chủ sở hữu; pipeline đêm có eval AI; dashboard DORA |

Quy đổi: ≥ 85 là Senior / Staff về release engineering · 70–84 là Mid+ vững · < 70 nên làm lại Tuần 2–3.
