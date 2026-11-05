// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Located in Nino/Source. Include current Swift files without backups or local diagnostics.
let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let entries = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
let sources = entries.filter { !$0.hasPrefix(".") && $0.hasSuffix(".swift") && $0 != "Package.swift" }.sorted()
let excluded = entries.filter { !sources.contains($0) && $0 != "Package.swift" && !$0.hasPrefix(".") }
let package = Package(
    name: "Nino",
    platforms: [.macOS("15.0")],
    products: [.executable(name: "Nino", targets: ["Nino"])],
    dependencies: [.package(url: "https://github.com/openid/AppAuth-iOS.git", exact: "2.1.0"),
                   .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1")],
    targets: [
        .executableTarget(
            name: "Nino",
            dependencies: [.product(name: "AppAuth", package: "AppAuth-iOS"),
                           .product(name: "Sparkle", package: "Sparkle")],
            path: ".",
            exclude: excluded,
            sources: sources,
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
                .linkedFramework("SwiftUI"), .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"), .linkedFramework("AVKit"),
                .linkedFramework("ScreenCaptureKit"), .linkedFramework("Speech"),
                .linkedFramework("FoundationModels"), .linkedFramework("Carbon")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
