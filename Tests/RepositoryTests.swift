import Foundation

@main struct RepositoryTests {
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("nino-repository-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        func git(_ args: [String], mustSucceed: Bool = true) throws {
            // Check status even before init (expected failure for a new synthetic directory).
            _ = try RepositoryReader.command(executable: "/usr/bin/git", arguments: ["-c", "core.fsmonitor=false", "status", "--porcelain"], directory: folder)
            let result = try RepositoryReader.command(executable: "/usr/bin/git", arguments: args, directory: folder)
            if mustSucceed { precondition(result.code == 0, "Synthetic Git setup failed") }
        }
        do { _ = try RepositoryReader.read(path: folder.path); preconditionFailure("Non-repository accepted") } catch RepositoryReadError.notRepository {}
        do { _ = try RepositoryReader.read(path: "relative"); preconditionFailure("Relative path accepted") } catch RepositoryReadError.invalidDirectory {}
        try git(["init", "-b", "main"])
        let unborn = try RepositoryReader.read(path: folder.path)
        precondition(unborn.branch == "main" && unborn.latestCommit.isEmpty && unborn.changedFiles == 0)
        try "a".write(to: folder.appendingPathComponent("tracked space.txt"), atomically: true, encoding: .utf8)
        try git(["add", "--", "tracked space.txt"])
        try git(["-c", "user.name=Nino Test", "-c", "user.email=nino-test@example.invalid", "-c", "commit.gpgsign=false", "commit", "-m", "Synthetic fixture"])
        let clean = try RepositoryReader.read(path: folder.path)
        precondition(clean.changedFiles == 0 && clean.latestCommit.count >= 12)
        try "b".write(to: folder.appendingPathComponent("tracked space.txt"), atomically: true, encoding: .utf8)
        try "c".write(to: folder.appendingPathComponent("untracked space.txt"), atomically: true, encoding: .utf8)
        let dirty = try RepositoryReader.read(path: folder.path)
        precondition(dirty.changedFiles == 2)
        let sentinel = folder.appendingPathComponent("hook-was-executed")
        let hook = folder.appendingPathComponent(".git/fixture-fsmonitor")
        let quoted = "'" + sentinel.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        try ("#!/bin/sh\n/usr/bin/touch " + quoted + "\n").write(to: hook, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        try git(["config", "core.fsmonitor", hook.path])
        _ = try RepositoryReader.read(path: folder.path)
        precondition(!FileManager.default.fileExists(atPath: sentinel.path), "Repository hook was executed")
        let renameCount = try RepositoryReader.countChanges(Data("R  new name\0old name\0?? new file\0".utf8))
        precondition(renameCount == 2)
        do { _ = try RepositoryReader.countChanges(Data(repeating: 32, count: RepositoryReader.outputLimit + 1)); preconditionFailure("Excessive output accepted") } catch RepositoryReadError.excessiveOutput {}
        let began = Date()
        do { _ = try RepositoryReader.command(executable: "/bin/sleep", arguments: ["5"], directory: folder, timeout: 0.15); preconditionFailure("Timeout ignored") } catch RepositoryReadError.timeout {}
        precondition(Date().timeIntervalSince(began) < 2)
        do { _ = try RepositoryReader.command(executable: "/usr/bin/yes", arguments: ["fixture"], directory: folder, limit: 1024); preconditionFailure("Output bound ignored") } catch RepositoryReadError.excessiveOutput {}
        let connector = RepositoryConnector()
        await connector.refresh(path: folder.path)
        let observed = connector.snapshot
        precondition(observed?.changedFiles == 2)
        connector.clear()
        let cleared = connector.snapshot
        precondition(cleared == nil)

        // A same-size edit causes status to hash tracked content, which normally executes clean filters.
        // Build the fixture first, then configure its hostile filter without another unsafe status.
        let safeOverrides = ["-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-c", "core.attributesFile=/dev/null"]
        let attrs = folder.appendingPathComponent(".gitattributes")
        try "\"tracked space.txt\" filter=probe\n".write(to: attrs, atomically: true, encoding: .utf8)
        let cleanMarker = folder.appendingPathComponent("clean-filter-executed")
        let cleanCommand = "touch '" + cleanMarker.path.replacingOccurrences(of: "'", with: "'\\''") + "'; cat"
        _ = try RepositoryReader.command(executable: "/usr/bin/git", arguments: safeOverrides + ["status", "--porcelain"], directory: folder)
        let configured = try RepositoryReader.command(executable: "/usr/bin/git", arguments: ["config", "filter.probe.clean", cleanCommand], directory: folder)
        precondition(configured.code == 0)
        do { _ = try RepositoryReader.read(path: folder.path); preconditionFailure("Executable clean filter accepted") } catch RepositoryReadError.customFilters {}
        precondition(!FileManager.default.fileExists(atPath: cleanMarker.path), "Clean filter executed")
        await connector.refresh(path: folder.path)
        precondition(connector.snapshot == nil && connector.issue?.contains("filtres Git") == true)
        precondition(!FileManager.default.fileExists(atPath: cleanMarker.path), "Connector executed clean filter")

        // Config-only cleanup is intentional: running status here would execute the malicious fixture.
        _ = try RepositoryReader.command(executable: "/usr/bin/git", arguments: ["config", "--unset", "filter.probe.clean"], directory: folder)
        let include = folder.appendingPathComponent(".git/nino-included-config")
        try "[filter \"probe\"]\n\tprocess = touch never-execute-this\n".write(to: include, atomically: true, encoding: .utf8)
        _ = try RepositoryReader.command(executable: "/usr/bin/git", arguments: safeOverrides + ["status", "--porcelain"], directory: folder)
        _ = try RepositoryReader.command(executable: "/usr/bin/git", arguments: ["config", "include.path", include.path], directory: folder)
        do { _ = try RepositoryReader.read(path: folder.path); preconditionFailure("Included process filter accepted") } catch RepositoryReadError.customFilters {}
        precondition(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("never-execute-this").path))
        try RepositoryReader.rejectExecutableFilters(Data("filter.probe.clean\n\0filter.probe.process\n \0".utf8))
        print("PASS: repository metadata and bounds; fsmonitor blocked; executable clean/process filters (including included config) refused with visible reason; no fixture commands executed.")
    }
}
