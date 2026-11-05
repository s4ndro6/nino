import Foundation

@main struct AppUpdatesTests {
    @MainActor static func main() async throws {
        var assertions = 0
        func check(_ condition: Bool, _ label: String) { precondition(condition, label); assertions += 1 }
        func feed(_ version: String = "0.21.0", draft: Bool = false, url: String? = nil, size: Int = 1024, tag: String? = nil) throws -> Data {
            try JSONSerialization.data(withJSONObject: [["tag_name": tag ?? "v\(version)", "draft": draft, "prerelease": true, "body":"Des nouveautés", "assets":[["name":"Nino-\(version)-macOS-arm64.dmg", "browser_download_url":url ?? "https://github.com/s4ndro6/nino/releases/download/v\(version)/Nino-\(version)-macOS-arm64.dmg", "size":size, "state":"uploaded"]]]])
        }
        check(NinoVersion("0.9.0")! < NinoVersion("0.20.0")!, "semantic numeric ordering")
        check(NinoVersion("v1.0.0") == NinoVersion("1.0.0"), "v normalization")
        for invalid in ["", "1", "1.2", "1.2.3.4", "1.02.3", "1.2.3-beta", "1.2.3/path", "-1.2.3", "١.2.3"] { check(NinoVersion(invalid) == nil, "invalid version") }
        let release = try NinoReleaseFeed.newest(feed(), current: "0.20.0")
        check(release?.version.description == "0.21.0", "published alpha eligible")
        check(try NinoReleaseFeed.newest(feed("0.20.0"), current:"0.20.0") == nil, "equal")
        check(try NinoReleaseFeed.newest(feed("0.19.0"), current:"0.20.0") == nil, "no downgrade")
        check(try NinoReleaseFeed.newest(feed(draft:true), current:"0.20.0") == nil, "draft rejected")
        for url in ["http://github.com/s4ndro6/nino/releases/download/v0.21.0/Nino-0.21.0-macOS-arm64.dmg", "https://evil.test/Nino.dmg", "https://github.com/other/nino/releases/download/v0.21.0/Nino-0.21.0-macOS-arm64.dmg", "https://github.com/s4ndro6/nino/releases/download/v0.21.0/Nino-0.21.0-macOS-arm64.dmg?next=evil"] { check(try NinoReleaseFeed.newest(feed(url:url), current:"0.20.0") == nil, "only exact asset trusted") }
        check(try NinoReleaseFeed.newest(feed(size:0), current:"0.20.0") == nil, "empty asset")
        check(try NinoReleaseFeed.newest(feed(size:200_000_001), current:"0.20.0") == nil, "oversize asset")
        check(try NinoReleaseFeed.newest(feed(tag:"0.21.0"), current:"0.20.0") == nil, "tag must match release URL")
        do { _ = try NinoReleaseFeed.newest(Data(repeating: 32, count:1_048_577),current:"0.20.0"); fatalError("oversize response accepted") } catch { assertions += 1 }
        do { _ = try NinoReleaseFeed.newest(Data("oops".utf8),current:"0.20.0"); fatalError("bad JSON accepted") } catch { assertions += 1 }
        let name = "NinoUpdatesTests-\(UUID())"
        let prefs = UserDefaults(suiteName:name)!
        defer { prefs.removePersistentDomain(forName:name) }
        var now = Date(timeIntervalSince1970:1_800_000_000), calls=0
        let payload=try feed()
        let updates=AppUpdates(defaults:prefs,current:"0.20.0",now:{now},fetch:{calls += 1;return payload})
        await updates.check(manual:false)
        check(calls==0 && !updates.automatic,"no default network")
        await updates.check(manual:true)
        check(calls==1 && updates.hint,"manual works without enabling automatic")
        check(!updates.automatic,"manual does not opt in")
        let restart=AppUpdates(defaults:prefs,current:"0.20.0",now:{now},fetch:{payload})
        check(restart.latest != nil && restart.hint,"restart keeps detected offer")
        updates.later(); check(!updates.hint,"later hides")
        let snoozed=AppUpdates(defaults:prefs,current:"0.20.0",now:{now},fetch:{payload})
        check(snoozed.latest != nil && !snoozed.hint,"restart keeps later deadline")
        now=now.addingTimeInterval(86_401); check(updates.hint,"later expires")
        updates.skip(); check(!updates.hint,"skip version")
        await updates.check(manual:true);check(!updates.hint,"manual refresh preserves skip")
        prefs.set(true,forKey:"updates.automatic")
        let resumed=AppUpdates(defaults:prefs,current:"0.20.0",now:{now},fetch:{calls += 1;return payload})
        check(resumed.latest?.version.description == "0.21.0" && !resumed.hint,"cached offer survives restart and keeps skip")
        let before=calls;await resumed.check(manual:false);check(calls==before,"daily throttle survives relaunch")
        now=now.addingTimeInterval(86_401);await resumed.check(manual:false);check(calls==before+1,"next day checks")
        resumed.setAutomatic(false);await resumed.check(manual:false);check(calls==before+1,"disable blocks requests")
        prefs.set(try feed(url:"https://evil.test/update.dmg"),forKey:"updates.feed")
        let corrupted=AppUpdates(defaults:prefs,current:"0.20.0",fetch:{payload})
        check(corrupted.latest == nil,"untrusted cache revalidated")
        let failed=AppUpdates(defaults:prefs,current:"0.20.0",fetch:{throw NinoReleaseFeed.Failure.unavailable})
        await failed.check(manual:true);check(failed.latest==nil && !failed.checking && failed.message.contains("Impossible"),"failure not up to date")
        let newerPayload=try feed("0.22.0")
        let newer=AppUpdates(defaults:prefs,current:"0.20.0",fetch:{newerPayload})
        await newer.check(manual:true);check(newer.hint && newer.latest?.version.description == "0.22.0","skip does not hide next version")
        var suspended: CheckedContinuation<Data, Error>?
        let pending=AppUpdates(defaults:prefs,current:"0.20.0",fetch:{try await withCheckedThrowingContinuation { suspended=$0 }})
        let pendingTask=Task { await pending.check(manual:true) }
        while suspended == nil { await Task.yield() }
        let original=pending.latest
        pending.setAutomatic(false)
        suspended?.resume(returning:payload)
        await pendingTask.value
        check(!pending.checking && pending.latest == original,"disable invalidates in-flight reply")
        print("AppUpdatesTests PASS: \(assertions) assertions; no real network")
    }
}
