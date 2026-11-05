import Foundation
import ImageIO
import UniformTypeIdentifiers

@main struct DeliveryTests {
    static var assertions = 0
    static func check(_ value: @autoclosure () -> Bool, _ label: String) {
        precondition(value(), label); assertions += 1
    }
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("nino-delivery-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("exports")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let context = CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 480, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.5, green: 0.8, blue: 0.6, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        let destination = CGImageDestinationCreateWithURL(folder.appendingPathComponent("vertical.png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil); check(CGImageDestinationFinalize(destination), "synthetic image")
        let rule = DeliveryRequirement(name: "vertical.png", kind: .image, width: 80, height: 120)
        let wrong = try await DeliveryInspector.inspect(folder: folder, rule: rule)
        check(wrong.verdict == .fail, "wrong aspect ratio is an actual failure")
        check(wrong.checks.contains { $0.title == "Dimensions" && $0.detail.contains("120 × 80") }, "actual dimensions shown")
        let missing = try await DeliveryInspector.inspect(folder: folder, rule: .init(name: "sous-titres.srt"))
        check(missing.verdict == .fail && !missing.canReveal, "missing required subtitle")
        var fixed = rule; fixed.width = 120; fixed.height = 80
        let good = try await DeliveryInspector.inspect(folder: folder, rule: fixed)
        check(good.verdict == .pass, "matching real image passes")
        let changing = try await DeliveryInspector.inspect(folder: folder, rule: fixed) { url, _ in
            var bytes = try Data(contentsOf: url); bytes.append(0); try bytes.write(to: url)
            return DeliveryMetadata(width: 120, height: 80, readable: true)
        }
        check(changing.verdict == .unknown && changing.checks.count == 1, "modified export cannot pass using cached metadata")
        try Data().write(to: folder.appendingPathComponent("empty.srt"))
        let empty = try await DeliveryInspector.inspect(folder: folder, rule: .init(name: "empty.srt"))
        check(empty.verdict == .fail, "empty file never passes")
        try Data("invalid png".utf8).write(to: folder.appendingPathComponent("broken.png"))
        let broken = try await DeliveryInspector.inspect(folder: folder, rule: .init(name: "broken.png", kind: .image, width: 120, height: 80))
        check(broken.verdict == .unknown, "unreadable image not a success")
        let escaped = folder.appendingPathComponent("escape.png")
        try FileManager.default.createSymbolicLink(at: escaped, withDestinationURL: folder.appendingPathComponent("vertical.png"))
        let linked = try await DeliveryInspector.inspect(folder: folder, rule: .init(name: "escape.png", kind: .image))
        check(linked.verdict == .unknown && !linked.canReveal, "symlink rejected")
        check(!DeliveryRequirement(name: "../secret").valid, "no traversal")
        check(!DeliveryRequirement(name: "/secret").valid, "no absolute paths")
        check(!DeliveryRequirement(name: "a\nb").valid, "no control characters")
        check(!DeliveryRequirement(name: "video.mp4", maxSeconds: .nan).valid, "NaN rejected")
        check(!DeliveryPlan(requirements: [.init(name: "a.png"), .init(name: "A.PNG")]).valid, "case duplicate names rejected")
        let d = DeliveryInspector.displayDimensions(size: CGSize(width: 1920, height: 1080), transform: CGAffineTransform(rotationAngle: .pi / 2))
        check(d?.0 == 1080 && d?.1 == 1920, "video rotation accounted for")
        let audioRule = DeliveryRequirement(name: "video.mp4", kind: .video, width: 1080, height: 1920, maxSeconds: 60, needsAudio: true)
        let silent = DeliveryInspector.evaluate(rule: audioRule, metadata: .init(width: 1080, height: 1920, seconds: 70, audio: false, readable: true))
        check(silent.filter { $0.verdict == .fail }.count == 2, "duration plus absent audio fail separately")
        let unknown = DeliveryInspector.evaluate(rule: audioRule, metadata: .init(readable: true))
        check(unknown.filter { $0.verdict == .unknown }.count == 3, "unknown metadata never passes")
        let report = DeliveryReport(date: Date(), files: [wrong, missing, broken])
        check(report.failures == 2 && report.unknowns == 1 && report.passed == 0, "summary keeps failures and unknown distinct")
        check(report.markdown.contains("NON VÉRIFIÉ") && !report.markdown.contains(folder.path), "report excludes absolute paths and preserves uncertainty")
        let store = DeliveryStore(file: root.appendingPathComponent("Workspace/delivery-plans.json"))
        store.activate(key: "project-a", title: "A")
        store.update(DeliveryPlan(requirements: [rule]))
        store.select(folder: folder); store.run()
        for _ in 0..<100 where store.running { try await Task.sleep(nanoseconds: 20_000_000) }
        check(store.report?.failures == 1, "real store execution finishes")
        store.update(DeliveryPlan(requirements: [fixed])); check(store.report == nil, "criteria edit invalidates report")
        store.run(); store.activate(key: "project-b", title: "B")
        try await Task.sleep(nanoseconds: 100_000_000)
        check(store.report == nil && store.folder == nil && !store.running, "project switch cancels stale results")
        store.activate(key: "project-a", title: "A")
        check(store.plan.requirements == [fixed], "criteria isolated per project")
        try await Task.sleep(nanoseconds: 150_000_000)
        let restored = DeliveryStore(file: root.appendingPathComponent("Workspace/delivery-plans.json"))
        restored.activate(key: "project-a", title: "A")
        if restored.plan.requirements != [fixed] { FileHandle.standardError.write(Data("Persistence: \(store.issue ?? "none") / \(restored.issue ?? "none")\n".utf8)) }
        check(restored.plan.requirements == [fixed] && restored.folder == nil && restored.report == nil, "restart keeps criteria but never a stale green result")
        let malformed = root.appendingPathComponent("malformed.json")
        try JSONEncoder().encode(["project-invalid": DeliveryPlan(requirements: Array(repeating: fixed, count: 31))]).write(to: malformed)
        let rejected = DeliveryStore(file: malformed); rejected.activate(key: "project-invalid", title: "Invalid")
        check(rejected.issue != nil && rejected.plan.requirements.count == 1, "rejected persisted state never reaches the UI")
        if CommandLine.arguments.count > 1 {
            let video = URL(fileURLWithPath: CommandLine.arguments[1])
            let result = try await DeliveryInspector.inspect(folder: video.deletingLastPathComponent(), rule: .init(name: video.lastPathComponent, kind: .video, width: 120, height: 80, maxSeconds: 2, needsAudio: true))
            check(result.verdict == .pass, "real local video with audio metadata")
        }
        print("Delivery: \(assertions) checks passed")
    }
}
