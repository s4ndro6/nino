import Foundation

func check(_ condition: @autoclosure () throws -> Bool, line: UInt = #line) throws { let value = try condition(); precondition(value, "test line \(line)") }

@main struct WorkspaceTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/nino-workspace-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = WorkspaceRepository(directory: root.appendingPathComponent("Workspace"))
        try check(try repo.load().projects.isEmpty)
        var p = WorkProject(); p.title = "Recette synthétique"; p.updatedAt = Date(timeIntervalSince1970: 1700000000); p.brief = "Aucune donnée privée"; p.tasks = [WorkStep(title: "Vérifier le rendu")]
        p.links = [WorkReference(label: "Documentation", url: "https://example.com")]
        var state = WorkspaceState(); state.projects = [p]; state.selectedID = p.id
        try repo.save(state)
        let loaded = try repo.load(); try check(loaded.projects == [p]); try check(loaded.selectedID == p.id)
        try check(WorkReference(label: "Malicious", url: "file:///etc/passwd").safeURL == nil)
        try check(WorkReference(label: "Credentials", url: "https://user:password@example.com").safeURL == nil)
        let session = UUID(); try repo.share(p, enabled: true, session: session)
        let snapshot = try JSONSerialization.jsonObject(with: repo.read("context.json")) as! [String: Any]
        let project = snapshot["project"] as! [String: Any]
        try check(project["repositoryPath"] == nil && project["chat"] == nil)
        try check(Set(project.keys) == Set(["id", "title", "brief", "nextAction", "tasks", "links"]))
        try repo.share(nil, enabled: false, session: UUID())
        try check(String(data: try repo.read("context.json"), encoding: .utf8)!.contains("false"))
        var invalid = p; invalid.title = ""; do { _ = try invalid.validated(); fatalError("invalid project accepted") } catch {}
        let before = try repo.read("workspace.json")
        var huge = state; huge.projects = Array(repeating: p, count: 10000)
        do { try repo.save(huge); fatalError("oversized save accepted") } catch {}
        try check(try repo.read("workspace.json") == before)
        // An invalid state must fail without deleting valid files.
        try repo.write(Data("{broken".utf8), name: "workspace.json")
        try repo.share(p, enabled: true, session: session)
        let store = WorkspaceStore(root: root)
        for _ in 0..<100 { if store.issue != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        try check(store.issue != nil && !store.ready)
        let revoked = try JSONSerialization.jsonObject(with: repo.read("context.json")) as! [String: Any]
        try check(revoked["sharingEnabled"] as? Bool == false)
        try repo.save(state)
        let healthy = WorkspaceStore(root: root)
        for _ in 0..<100 { if healthy.ready { break }; try await Task.sleep(for: .milliseconds(10)) }
        try check(healthy.ready && healthy.current?.id == p.id)
        healthy.toggleStep(p.tasks[0].id)
        for _ in 0..<100 { if !healthy.saving { break }; try await Task.sleep(for: .milliseconds(10)) }
        try check(try repo.load().projects[0].tasks[0].done)
        healthy.setSharing(true)
        for _ in 0..<100 { if !healthy.saving { break }; try await Task.sleep(for: .milliseconds(10)) }
        try check(healthy.sharing)
        var second = WorkProject(); second.title = "Autre travail"; try check(healthy.upsert(second)); try check(!healthy.sharing)
        for _ in 0..<100 { if !healthy.saving { break }; try await Task.sleep(for: .milliseconds(10)) }
        let switched = try JSONSerialization.jsonObject(with: repo.read("context.json")) as! [String: Any]
        try check(switched["sharingEnabled"] as? Bool == false)
        let target = root.appendingPathComponent("secret"); try Data("secret".utf8).write(to: target)
        try FileManager.default.removeItem(at: repo.directory.appendingPathComponent("context.json"))
        try FileManager.default.createSymbolicLink(at: repo.directory.appendingPathComponent("context.json"), withDestinationURL: target)
        do { try repo.share(p, enabled: true, session: session); fatalError("symlink accepted") } catch {}
        try check(try String(contentsOf: target, encoding: .utf8) == "secret")
        print("PASS Workspace: persistence, URL validation, allowlist, revoke, size cap, corrupt startup, tasks, project switch, symlinks")
    }
}
