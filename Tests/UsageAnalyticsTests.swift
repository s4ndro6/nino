import Foundation

actor UsageProbe {
    var bodies: [Data] = []
    var failures = 0
    var delay = false
    func configure(failures: Int = 0, delay: Bool = false) { self.failures = failures; self.delay = delay }
    func send(_ url: URL, _ data: Data) async throws -> Data {
        bodies.append(data)
        if delay { try? await Task.sleep(for: .milliseconds(100)) } // Deliberately ignores cancellation, like a late server callback.
        if failures > 0 { failures -= 1; throw URLError(.timedOut) }
        let batch = try JSONDecoder().decode(UsageBatch.self, from: data)
        return try JSONSerialization.data(withJSONObject: ["schema_version":1, "batch_id":batch.batchID, "accepted_count":batch.counters.reduce(0) { $0 + $1.count }, "duplicate":false])
    }
    func snapshots() -> [Data] { bodies }
}
@MainActor final class UsageClock { var date = Date(timeIntervalSince1970: 1_793_836_800) }

@main struct UsageAnalyticsTests {
    @MainActor static func main() async throws {
        let manager = FileManager.default
        let base = URL(fileURLWithPath: manager.currentDirectoryPath).appendingPathComponent("work/nino-tests/usage-fixture-" + UUID().uuidString)
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: base) }
        func root(_ name: String) throws -> URL { let path = base.appendingPathComponent(name); try manager.createDirectory(at: path, withIntermediateDirectories: true); return path }
        let endpoint = URL(string: "https://metrics.example.test/v1/usage")!
        let probe = UsageProbe(), clock = UsageClock()
        let firstRoot = try root("consent")
        let analytics = UsageAnalytics(root: firstRoot, endpoint: endpoint, now: { clock.date }, transport: { try await probe.send($0,$1) })
        analytics.track(.appOpened); await analytics.uploadPending()
        precondition(analytics.consent == .undecided && analytics.pendingEventCount == 0)
        precondition(!manager.fileExists(atPath: firstRoot.appendingPathComponent("Privacy").path))
        let noChoiceCalls = await probe.snapshots(); precondition(noChoiceCalls.isEmpty)
        let firstDecline = analytics.setConsent(.declined); if !firstDecline { FileHandle.standardError.write(Data(((analytics.status ?? "no status") + " root=" + firstRoot.path + "\n").utf8)) }; precondition(firstDecline); analytics.track(.timerStarted); await analytics.uploadPending()
        let declinedCalls = await probe.snapshots(); precondition(declinedCalls.isEmpty && analytics.pendingEventCount == 0)
        precondition(analytics.setConsent(.accepted)); analytics.track(.timerStarted); analytics.track(.timerStarted)
        let loaded = UsageAnalytics(root: firstRoot, now: { clock.date })
        precondition(loaded.consent == .accepted && loaded.pendingEventCount == 2)
        await loaded.uploadPending(); precondition(loaded.status?.contains("aucun serveur") == true)
        await probe.configure(failures: 1)
        await analytics.uploadPending(); precondition(analytics.pendingEventCount == 2)
        analytics.track(.projectCreated)
        await analytics.uploadPending(); precondition(analytics.pendingEventCount == 1)
        var bodies = await probe.snapshots()
        precondition(bodies.count == 2)
        let failed = try JSONDecoder().decode(UsageBatch.self, from: bodies[0]), retried = try JSONDecoder().decode(UsageBatch.self, from: bodies[1])
        precondition(failed == retried, "Retry must preserve the full immutable batch and ID")
        await analytics.uploadPending(); precondition(analytics.pendingEventCount == 0)
        bodies = await probe.snapshots()
        let next = try JSONDecoder().decode(UsageBatch.self, from: bodies[2])
        precondition(next.batchID != failed.batchID, "A batch ID cannot be a stable installation ID")
        let payload = try JSONSerialization.jsonObject(with: bodies[0]) as! [String:Any]
        precondition(Set(payload.keys) == Set(["schema_version","policy_version","consented_at_day","batch_id","counters"]))
        precondition(failed.counters[0].count == 2 && failed.policyVersion == UsageAnalytics.consentVersion)

        analytics.track(.assistantUsed); await probe.configure(delay: true)
        let sending = Task { await analytics.uploadPending() }
        try await Task.sleep(for: .milliseconds(15))
        precondition(analytics.setConsent(.declined))
        let withdrawalStatus = analytics.status
        await sending.value
        precondition(analytics.pendingEventCount == 0 && analytics.consent == .declined && analytics.status == withdrawalStatus)
        precondition(!manager.fileExists(atPath: firstRoot.appendingPathComponent("Privacy/usage-queue.json").path))
        let refused = UsageAnalytics(root: firstRoot, now: { clock.date }); precondition(refused.consent == .declined)
        precondition(analytics.setConsent(.accepted)); analytics.track(.appOpened); analytics.purgePending()
        precondition(analytics.pendingEventCount == 0 && analytics.consent == .accepted)

        let bounds = UsageAnalytics(root: try root("bounds"), now: { clock.date })
        precondition(bounds.setConsent(.accepted))
        for _ in 0..<1004 { bounds.track(.appOpened) }
        precondition(bounds.pendingEventCount == UsageAnalytics.maxCount)
        let expiryRoot = try root("expiry")
        let expiry = UsageAnalytics(root: expiryRoot, now: { clock.date })
        precondition(expiry.setConsent(.accepted)); expiry.track(.timerStarted)
        clock.date.addTimeInterval(31 * 86_400)
        let expired = UsageAnalytics(root: expiryRoot, now: { clock.date })
        precondition(expired.pendingEventCount == 0)
        let saved = try String(contentsOf: expiryRoot.appendingPathComponent("Privacy/usage-queue.json"), encoding: .utf8)
        precondition(!saved.contains("timer_started"), "Expiry must be persisted, not just hidden")

        let pendingRoot = try root("pending-expiry")
        let pendingProbe = UsageProbe(); await pendingProbe.configure(failures: 1)
        let pending = UsageAnalytics(root: pendingRoot, endpoint: endpoint, now: { clock.date }, transport: { try await pendingProbe.send($0,$1) })
        precondition(pending.setConsent(.accepted)); pending.track(.timerStarted); await pending.uploadPending()
        clock.date.addTimeInterval(31 * 86_400); pending.track(.feedbackCreated)
        let pendingDisk = try String(contentsOf: pendingRoot.appendingPathComponent("Privacy/usage-queue.json"), encoding: .utf8)
        precondition(!pendingDisk.contains("timer_started") && pending.pendingEventCount == 1)
        let policyRoot = try root("policy")
        let policy = UsageAnalytics(root: policyRoot, now: { clock.date }); precondition(policy.setConsent(.accepted)); policy.track(.appOpened)
        let consentURL = policyRoot.appendingPathComponent("Privacy/usage-consent.json")
        var changedPolicy = try JSONSerialization.jsonObject(with: Data(contentsOf: consentURL)) as! [String:Any]
        changedPolicy["policyVersion"] = 999
        try JSONSerialization.data(withJSONObject: changedPolicy).write(to: consentURL)
        let newPolicy = UsageAnalytics(root: policyRoot, now: { clock.date })
        precondition(newPolicy.consent == .undecided && newPolicy.pendingEventCount == 0)
        precondition(!manager.fileExists(atPath: policyRoot.appendingPathComponent("Privacy/usage-queue.json").path))

        for url in ["http://metrics.example.test/v1/usage", "https://u:p@metrics.example.test/v1/usage", "https://metrics.example.test/v1/usage?email=x", "https://metrics.example.test/other"] {
            precondition(!UsageAnalytics.validEndpoint(URL(string:url)!))
        }
        var badAck = ["schema_version":1,"batch_id":failed.batchID,"accepted_count":2,"duplicate":false] as [String:Any]
        badAck["email"] = "forbidden"
        do { try UsageAnalytics.validateAck(JSONSerialization.data(withJSONObject:badAck), for:failed); preconditionFailure("Unexpected ack fields accepted") } catch {}
        badAck.removeValue(forKey:"email"); badAck["schema_version"] = 1.5
        do { try UsageAnalytics.validateAck(JSONSerialization.data(withJSONObject:badAck), for:failed); preconditionFailure("Fractional schema accepted") } catch {}

        let foreign = try root("foreign"), hostile = try root("symlink")
        let sentinel = foreign.appendingPathComponent("usage-queue.json")
        try Data("do not touch".utf8).write(to:sentinel)
        try manager.createSymbolicLink(at:hostile.appendingPathComponent("Privacy"), withDestinationURL:foreign)
        let linked = UsageAnalytics(root:hostile, now:{ clock.date })
        precondition(!linked.setConsent(.accepted)); linked.track(.appOpened); linked.purgePending()
        let sentinelText = try String(contentsOf:sentinel,encoding:.utf8); precondition(sentinelText == "do not touch")
        precondition(!manager.fileExists(atPath:foreign.appendingPathComponent("usage-consent.json").path))
        print("PASS usage analytics: no collection/network before consent, refusal, persisted choice, no-endpoint, immutable retry, fresh batch IDs, strict payload/ack, withdrawal+late callback, purge, count bounds, persisted expiry, HTTPS endpoint validation, symlink ancestor protection")
    }
}
