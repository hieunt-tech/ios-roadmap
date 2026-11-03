// swift-tools-version: 6.0
//
// ConcurrencyLab — Bài kiểm tra năng lực iOS (Phần B mở rộng)
//
//   swift test                         → chạy test trên BÀI LÀM của bạn (Sources/Exercises)
//   swift test -Xswiftc -DSOLUTION     → chạy cùng bộ test trên ĐÁP ÁN (Sources/Solutions)
//   swift test --filter Bai1           → chỉ chạy Bài 1
//
// Swift 6 language mode được bật mặc định với tools-version 6.0,
// nên mọi cảnh báo data race đều là lỗi biên dịch.

import PackageDescription

let package = Package(
    name: "ConcurrencyLab",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Exercises", targets: ["Exercises"]),
    ],
    targets: [
        // Kiểu dữ liệu và protocol dùng chung. KHÔNG sửa.
        .target(name: "LabCore"),

        // Bài làm của bạn. Chỉ sửa trong thư mục này.
        .target(name: "Exercises", dependencies: ["LabCore"]),

        // Đáp án tham khảo. Đừng mở trước khi làm xong.
        .target(name: "Solutions", dependencies: ["LabCore"]),

        // Fake có điều khiển + tiện ích test async. KHÔNG sửa.
        .target(name: "LabTestSupport", dependencies: ["LabCore"]),

        // Bộ test. Chọn module bằng cờ biên dịch SOLUTION. KHÔNG sửa.
        .testTarget(
            name: "LabTests",
            dependencies: ["LabCore", "LabTestSupport", "Exercises", "Solutions"]
        ),
    ]
)
