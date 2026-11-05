import Foundation

@main struct NativeUpdatePolicyTests {
    static func main() {
        var count = 0
        func expect(_ value: Bool) { precondition(value); count += 1 }
        var info: [String: Any] = ["CFBundleIdentifier": "app.sandro.nino", "NinoPublicDistribution": true,
            "SUPublicEDKey": Data(repeating: 1, count: 32).base64EncodedString(),
            "SUFeedURL": NativeUpdatePolicy.feed, "SUVerifyUpdateBeforeExtraction": true,
            "SUAllowsAutomaticUpdates": false]
        expect(NativeUpdatePolicy.configurationIssue(info) == nil)
        expect(NativeUpdatePolicy.configurationIssue(info, hasPrivateConfiguration: true) != nil)
        for change: [String: Any] in [
            ["CFBundleIdentifier": "app.sandro.nino.discovery.1793839061"],
            ["NinoPublicDistribution": false], ["NinoPreviewSession": true], ["NinoPortableStorage": true],
            ["SUPublicEDKey": ""], ["SUPublicEDKey": Data(repeating: 0, count: 32).base64EncodedString()],
            ["SUFeedURL": "http://nino-companion.vercel.app/appcast.xml"],
            ["SUFeedURL": "https://example.com/appcast.xml"],
            ["SUVerifyUpdateBeforeExtraction": false], ["SUAllowsAutomaticUpdates": true]
        ] { expect(NativeUpdatePolicy.configurationIssue(info.merging(change) { _, new in new }) != nil) }
        info.removeValue(forKey: "SUPublicEDKey")
        expect(NativeUpdatePolicy.configurationIssue(info) != nil)
        expect(NativeUpdatePolicy.Work().reason == nil)
        let flags: [WritableKeyPath<NativeUpdatePolicy.Work, Bool>] = [\.recording, \.starting, \.stopping,
            \.transcribing, \.importing, \.summarizing, \.generating, \.checkingDelivery,
            \.connecting, \.savingWorkspace, \.unsavedNotes]
        for flag in flags {
            var work = NativeUpdatePolicy.Work(); work[keyPath: flag] = true
            expect(work.reason != nil)
            work[keyPath: flag] = false
            expect(work.reason == nil)
        }
        print("Native update policy: \(count) assertions passed")
    }
}
