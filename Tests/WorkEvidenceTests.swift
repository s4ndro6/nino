import Foundation

private func check(_ value: @autoclosure () throws -> Bool, line: UInt = #line) throws { let result = try value(); precondition(result, "Evidence test line \(line)") }
private func rejects(_ body: () throws -> Void, line: UInt = #line) { do { try body(); preconditionFailure("Expected rejection line \(line)") } catch {} }

@main struct WorkEvidenceTests {
    @MainActor static func main() async throws {
        try check(try EvidenceValidation.milliseconds("") == nil)
        try check(try EvidenceValidation.milliseconds("01:23.5") == 83500)
        try check(try EvidenceValidation.milliseconds("01:02:03.004") == 3723004)
        try check(EvidenceValidation.timecode(3723004) == "01:02:03.004")
        for invalid in ["60:00", "00:60", "-1:00", "01:02:03:04", "100:00:00", "0:1.1234", "NaN", "1:", "0:1."] { rejects { _ = try EvidenceValidation.milliseconds(invalid) } }
        for invalid in ["file:///etc/passwd", "javascript:alert(1)", "https://u:p@example.com", "https://example.com\n"] { try check(EvidenceValidation.webURL(invalid) == nil) }
        try check(EvidenceValidation.webURL("https://example.com/feedback") != nil)
        let repo = try PublicGitHubRepository(url: "https://github.com/octo-org/demo")
        try check(repo.apiURL.absoluteString == "https://api.github.com/repos/octo-org/demo/actions/runs?per_page=5")
        for invalid in ["http://github.com/a/b", "https://github.com.evil.test/a/b", "https://github.com/a/b?token=secret", "https://github.com/a/b/actions", "https://github.com/a/%2E%2E", "https://github.com:443/a/b", "https://x@github.com/a/b"] { rejects { _ = try PublicGitHubRepository(url: invalid) } }
        for status in [301, 302, 401, 404, 403, 429, 500] { rejects { try PublicGitHubReader.validateHTTP(status: status, expectedLength: -1) } }
        rejects { try PublicGitHubReader.validateHTTP(status: 200, expectedLength: Int64(PublicGitHubReader.bodyLimit + 1)) }
        let id = UUID()
        let json = """
        {"workflow_runs":[{"id":123,"name":"Build","head_branch":"main","head_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","status":"completed","conclusion":"success","html_url":"https://github.com/octo-org/demo/actions/runs/123","updated_at":"2026-11-05T12:00:00Z"}]}
        """
        let snapshot = try PublicGitHubReader.parse(Data(json.utf8), repository: repo, projectID: id, fetchedAt: Date(timeIntervalSince1970: 1000))
        try check(snapshot.runs.first?.conclusion == "success")
        try check(!snapshot.isStale(at: Date(timeIntervalSince1970: 1500)))
        try check(snapshot.isStale(at: Date(timeIntervalSince1970: 2000)))
        for (original, replacement) in [("https://github.com/octo-org/demo/actions/runs/123", "https://evil.test/123"), ("success", "invented"), ("2026-11-05T12:00:00Z", "invalid"), ("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "bad-sha")] {
            rejects { _ = try PublicGitHubReader.parse(Data(json.replacingOccurrences(of: original, with: replacement).utf8), repository: repo, projectID: id) }
        }
        rejects { _ = try PublicGitHubReader.parse(Data(repeating: 32, count: PublicGitHubReader.bodyLimit + 1), repository: repo, projectID: id) }
        let root = URL(fileURLWithPath: "/private/tmp/nino-evidence-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("evidence.json")
        let repository = WorkEvidenceRepository(fileURL: file)
        let store = WorkEvidenceStore(fileURL: file)
        try check(store.ready)
        let item = WorkFeedback(projectID: id, version: "V03", timecodeMilliseconds: 83500, author: "=IMPORTXML(\"x\")", text: "Corriger la transition\nEt le titre", sourceURL: "https://example.com/feedback")
        try check(store.add(item))
        let other = UUID(); try check(store.feedback(for: other).isEmpty)
        store.setStatus(.done, id: item.id, projectID: other)
        try check(store.feedback(for: id).first?.status == .todo)
        store.setStatus(.review, id: item.id, projectID: id)
        try check(try repository.load().feedback.first?.status == .review)
        var state = try repository.load(); state.snapshots = [snapshot]; try repository.save(state)
        try check(try repository.load().snapshots == [snapshot])
        var invalid = item; invalid.text = String(repeating: "x", count: 3001)
        let before = try Data(contentsOf: file)
        try check(!store.add(invalid)); try check(try Data(contentsOf: file) == before)
        var tooMany = WorkEvidenceState(); tooMany.feedback = Array(repeating: item, count: 1501)
        rejects { try repository.save(tooMany) }; try check(try Data(contentsOf: file) == before)
        let csv = FeedbackExport.csv([item]); try check(csv.contains("\"'=IMPORTXML(\"\"x\"\")\"")); try check(csv.contains("00:01:23.500"))
        let md = FeedbackExport.markdown([item], title: "[Malicious](javascript:)")
        try check(md.contains("\\[Malicious\\]")); try check(md.contains("> Et le titre"))
        try Data("{broken".utf8).write(to: file)
        let broken = WorkEvidenceStore(fileURL: file); try check(!broken.ready && broken.issue != nil)
        try check(!broken.add(item)); try check(try String(contentsOf: file, encoding: .utf8) == "{broken")
        let symlink = root.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: file)
        rejects { _ = try WorkEvidenceRepository(fileURL: symlink).load() }
        print("PASS WorkEvidence: timecodes, safe URLs, fixed GitHub endpoint, HTTP/size bounds, parsing, stale snapshots, isolation, atomic persistence, corruption preservation, CSV injection, Markdown escaping, symlinks")
    }
}
