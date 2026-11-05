import Foundation
import Combine
import Darwin

struct RepositorySnapshot: Equatable, Sendable {
    let branch: String
    let changedFiles: Int
    let checkedAt: Date
    let root: String
    let latestCommit: String
}

enum RepositoryReadError: LocalizedError {
    case invalidDirectory, notRepository, customFilters, timeout, excessiveOutput, failed
    var errorDescription: String? {
        switch self {
        case .invalidDirectory: return "Choisis un dossier local existant."
        case .notRepository: return "Ce dossier ne contient pas de dépôt Git accessible."
        case .customFilters: return "Ce dépôt configure des filtres Git qui peuvent exécuter du code. Nino désactive ce relevé ; ouvre le dépôt dans ton outil habituel."
        case .timeout: return "Le relevé Git a dépassé huit secondes. Réessaie lorsque le disque est disponible."
        case .excessiveOutput: return "Le dépôt contient trop de changements pour ce relevé."
        case .failed: return "Nino n’a pas pu lire l’état du dépôt. Aucun fichier n’a été modifié."
        }
    }
}

/// A bounded metadata reader. No shell or source content is exposed; Git may inspect the working tree.
enum RepositoryReader {
    static let outputLimit = 1_048_576
    private static let overrides = [
        "-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null",
        "-c", "core.untrackedCache=false", "-c", "submodule.recurse=false",
        "-c", "maintenance.auto=false", "-c", "gc.auto=0",
        "-c", "core.attributesFile=/dev/null"
    ]

    static func read(path: String) throws -> RepositorySnapshot {
        guard path.hasPrefix("/"), !path.contains("\0"), path.utf8.count <= 16_384 else { throw RepositoryReadError.invalidDirectory }
        let folder = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw RepositoryReadError.invalidDirectory }
        let deadline = ProcessInfo.processInfo.systemUptime + 8
        func git(_ arguments: [String]) throws -> CommandResult {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw RepositoryReadError.timeout }
            return try command(executable: "/usr/bin/git", arguments: overrides + arguments, directory: folder, timeout: remaining)
        }
        // Security exception to status-first: even status can execute a clean/process filter.
        // Config parsing itself does not execute values. Includes/worktree config are considered.
        // Do not echo these values: config may contain credentials or other private text.
        let filters = try git(["config", "--includes", "--null", "--get-regexp", "^filter\\."])
        guard [0, 1].contains(filters.code) else { throw RepositoryReadError.failed }
        if filters.code == 0 { try rejectExecutableFilters(filters.data) }
        // No Git operation inspecting the work tree is permitted until the filter check passes.
        let status = try git(["status", "--porcelain=v1", "-z", "--untracked-files=normal", "--ignore-submodules=all"])
        guard status.code == 0 else { throw RepositoryReadError.notRepository }
        let changes = try countChanges(status.data)
        let branchResult = try git(["symbolic-ref", "--quiet", "--short", "HEAD"])
        guard [0, 1].contains(branchResult.code) else { throw RepositoryReadError.failed }
        let commitResult = try git(["rev-parse", "--verify", "--short=12", "HEAD"])
        let commit = text(commitResult.data)
        guard commitResult.code != 0 || (commit.count >= 7 && commit.count <= 64 && commit.allSatisfy({ $0.isHexDigit })) else { throw RepositoryReadError.failed }
        let rootResult = try git(["rev-parse", "--show-toplevel"])
        let root = text(rootResult.data)
        guard rootResult.code == 0, root.hasPrefix("/"), root.utf8.count <= 16_384 else { throw RepositoryReadError.failed }
        let branch = branchResult.code == 0 ? String(text(branchResult.data).prefix(200)) : "HEAD détachée"
        return RepositorySnapshot(branch: branch, changedFiles: changes, checkedAt: Date(), root: root, latestCommit: commitResult.code == 0 ? commit : "")
    }

    static func rejectExecutableFilters(_ data: Data) throws {
        guard data.count <= outputLimit else { throw RepositoryReadError.excessiveOutput }
        guard !data.isEmpty, data.last == 0 else { throw RepositoryReadError.failed }
        for record in data.split(separator: 0) {
            guard let separator = record.firstIndex(of: 10),
                  let key = String(data: record[..<separator], encoding: .utf8),
                  key.hasPrefix("filter."),
                  !key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                // Ambiguous subsection names are refused rather than interpreted inconsistently.
                throw RepositoryReadError.customFilters
            }
            let lower = key.lowercased()
            let value = String(decoding: record[record.index(after: separator)...], as: UTF8.self)
            if lower.hasSuffix(".clean") || lower.hasSuffix(".process") {
                if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw RepositoryReadError.customFilters }
            } else if !lower.hasSuffix(".smudge") && !lower.hasSuffix(".required") {
                // Includes an embedded newline in a driver name split before its actual key.
                throw RepositoryReadError.customFilters
            }
        }
    }

    /// Porcelain -z rename/copy records carry a second filename; count the record once.
    static func countChanges(_ data: Data) throws -> Int {
        guard data.count <= outputLimit else { throw RepositoryReadError.excessiveOutput }
        if data.isEmpty { return 0 }
        guard data.last == 0 else { throw RepositoryReadError.failed }
        let records = data.split(separator: 0, omittingEmptySubsequences: false)
        var count = 0, index = 0
        while index < records.count - 1 {
            let record = Array(records[index])
            guard record.count >= 4, record[2] == 32 else { throw RepositoryReadError.failed }
            count += 1
            let renamed = record[0] == 82 || record[1] == 82 || record[0] == 67 || record[1] == 67
            index += renamed ? 2 : 1
            guard index <= records.count - 1 else { throw RepositoryReadError.failed }
        }
        return count
    }

    private static func text(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
    }

    struct CommandResult { let code: Int32; let data: Data }

    // Internal seam also used by synthetic deadline/output-limit tests. No command comes from UI text.
    static func command(executable: String, arguments: [String], directory: URL, timeout: TimeInterval = 8, limit: Int = outputLimit) throws -> CommandResult {
        try Task.checkCancellation()
        let process = Process(), output = Pipe(), finished = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = ["PATH": "/usr/bin:/bin", "LC_ALL": "C", "GIT_OPTIONAL_LOCKS": "0", "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_ATTR_NOSYSTEM": "1", "GIT_NO_LAZY_FETCH": "1", "GIT_TERMINAL_PROMPT": "0", "GIT_PAGER": "cat"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in finished.signal() }
        let deadline = ProcessInfo.processInfo.systemUptime + max(0.01, timeout)
        defer {
            if process.isRunning {
                process.terminate()
                if finished.wait(timeout: .now() + 0.2) == .timedOut, process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                    _ = finished.wait(timeout: .now() + 0.5)
                }
            }
            try? output.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
        }
        do { try process.run() } catch { throw RepositoryReadError.failed }
        try? output.fileHandleForWriting.close()
        let fd = output.fileHandleForReading.fileDescriptor
        var collected = Data(), ended = false
        while !ended {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw RepositoryReadError.timeout }
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
            let wait = Darwin.poll(&descriptor, 1, 50)
            if wait < 0 { if errno == EINTR { continue }; throw RepositoryReadError.failed }
            if wait == 0 { continue }
            if descriptor.revents & Int16(POLLERR | POLLNVAL) != 0 { throw RepositoryReadError.failed }
            var buffer = [UInt8](repeating: 0, count: 16_384)
            let received = Darwin.read(fd, &buffer, buffer.count)
            if received < 0 { if errno == EINTR { continue }; throw RepositoryReadError.failed }
            if received == 0 { ended = true; continue }
            guard collected.count + received <= limit else { throw RepositoryReadError.excessiveOutput }
            collected.append(contentsOf: buffer.prefix(received))
        }
        let remaining = max(0, deadline - ProcessInfo.processInfo.systemUptime)
        if process.isRunning, finished.wait(timeout: .now() + remaining) == .timedOut { throw RepositoryReadError.timeout }
        try Task.checkCancellation()
        return CommandResult(code: process.terminationStatus, data: collected)
    }
}

@MainActor final class RepositoryConnector: ObservableObject {
    @Published private(set) var snapshot: RepositorySnapshot?
    @Published private(set) var checking = false
    @Published private(set) var issue: String?
    private var generation = UUID()
    private var task: Task<RepositorySnapshot, Error>?

    func refresh(path: String) async {
        guard !checking else { return }
        let current = UUID(); generation = current
        checking = true; issue = nil; snapshot = nil
        let work = Task.detached(priority: .utility) { try RepositoryReader.read(path: path) }
        task = work
        do {
            let value = try await work.value
            guard generation == current else { return }
            snapshot = value
        } catch {
            guard generation == current else { return }
            if !(error is CancellationError) { issue = error.localizedDescription }
        }
        guard generation == current else { return }
        checking = false; task = nil
    }

    /// Call whenever the selected repository changes; cancels the old read and rejects its late result.
    func clear() {
        generation = UUID(); task?.cancel(); task = nil
        snapshot = nil; issue = nil; checking = false
    }
}
