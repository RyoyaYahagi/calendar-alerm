// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CalendarAlarmCore",
    platforms: [
        .iOS("26.0"),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "CalendarAlarmCore",
            targets: ["CalendarAlarmCore"]),
    ],
    targets: [
        .target(
            name: "CalendarAlarmCore",
            path: "Sources/CalendarAlarmCore"
        ),
        .testTarget(
            name: "CalendarAlarmCoreTests",
            dependencies: ["CalendarAlarmCore"],
            path: "Tests/CalendarAlarmCoreTests"
        ),
    ]
)
