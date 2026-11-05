import Foundation
import AppKit
import Darwin

struct QuotaWindow: Identifiable {
    var id: String
    var used: Double
    var reset: Date?
    var remaining: Int { Int((100 - used).rounded()) }
}
struct QuotaSnapshot {
    var windows: [QuotaWindow] = []
    var measured: Date?
    var error: String?
}
struct WorkChat: Identifiable {
    var id: String
    var title: String
    var directory: String
    var updated: Date
    var project: String { URL(fileURLWithPath: directory).lastPathComponent }
}

// A short-lived read-only connection, independent of audio processes.
final class DashboardProcess {
    let process = Process()
    let input = Pipe()
    let output = Pipe()
    private var buffer = Data()
    private var deadline: DispatchWorkItem?
    private var expires: TimeInterval = 0
    init(path: String, arguments: [String], timeout: Double = 45) throws {
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] = "\(home)/.local/bin:\(home)/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = environment
        process.standardInput = input; process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        expires = ProcessInfo.processInfo.systemUptime + timeout
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.process.isRunning else { return }
            self.process.terminate()
            let owned = self.process
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if owned.isRunning { Darwin.kill(owned.processIdentifier, SIGKILL) }
            }
        }
        deadline = work
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: work)
    }
    func close() {
        deadline?.cancel()
        try? input.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
            let owned = process
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if owned.isRunning { Darwin.kill(owned.processIdentifier, SIGKILL) }
            }
        }
        try? output.fileHandleForReading.close()
    }
    deinit { close() }
    private func readChunk() throws -> Data {
        let fd = output.fileHandleForReading.fileDescriptor
        while ProcessInfo.processInfo.systemUptime < expires {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN | POLLHUP), revents: 0)
            let result = Darwin.poll(&descriptor, 1, 200)
            if result < 0 { if errno == EINTR { continue }; throw NinoError("Lecture quota interrompue.") }
            if result == 0 { continue }
            var bytes = [UInt8](repeating: 0, count: 16384)
            let count = Darwin.read(fd, &bytes, bytes.count)
            if count == 0 { return Data() }
            if count < 0 { if errno == EINTR { continue }; throw NinoError("Lecture quota impossible.") }
            return Data(bytes.prefix(count))
        }
        throw NinoError("Le relevé a dépassé son délai. Réessaie dans quelques instants.")
    }
    func send(_ object: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    func response(_ id: Int) throws -> [String: Any] {
        while true {
            if let end = buffer.firstIndex(of: 10) {
                let line = buffer[..<end]; buffer.removeSubrange(...end)
                guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any], json["id"] as? Int == id else { continue }
                guard let result = json["result"] as? [String: Any] else { throw NinoError("Codex ne peut pas fournir ce relevé. Vérifie ta connexion dans Codex.") }
                return result
            }
            let chunk = try readChunk()
            guard !chunk.isEmpty else { throw NinoError("Le relevé Codex a expiré ou le serveur s’est arrêté.") }
            buffer.append(chunk)
            guard buffer.count < 4_000_000 else { throw NinoError("Réponse Codex trop volumineuse.") }
        }
    }
    func document() throws -> Any {
        var data = Data()
        while true {
            let chunk = try readChunk()
            if chunk.isEmpty { break }
            data.append(chunk)
            guard data.count < 2_000_000 else { throw NinoError("Réponse quota trop volumineuse.") }
        }
        guard !data.isEmpty else { throw NinoError("Quota indisponible. Vérifie la connexion Claude Code puis réessaie.") }
        return try JSONSerialization.jsonObject(with: data)
    }
}
enum DashboardReader {
    static func executable(_ name: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.local/bin/\(name)", "\(home)/.npm-global/bin/\(name)", "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static func windows(_ object: [String: Any], claude: Bool) -> [QuotaWindow] {
        ["primary", "secondary", "tertiary"].compactMap { key in
            guard let value = object[key] as? [String: Any], let used = value["usedPercent"] as? Double, used.isFinite, (0...100).contains(used) else { return nil }
            let minutes = (value[claude ? "windowMinutes" : "windowDurationMins"] as? NSNumber)?.intValue
            let label = minutes == 10080 ? "Semaine" : minutes == 300 ? "Session · 5 h" : minutes.map { "Fenêtre · \($0 / 60) h" } ?? (key == "tertiary" ? "Limite complémentaire" : "Quota")
            let reset: Date?
            if let seconds = value["resetsAt"] as? Double { reset = Date(timeIntervalSince1970: seconds) }
            else if let string = value["resetsAt"] as? String { reset = ISO8601DateFormatter().date(from: string) }
            else { reset = nil }
            return QuotaWindow(id: label, used: used, reset: reset)
        }
    }
    static func codex() throws -> (QuotaSnapshot, [WorkChat]?, String?) {
        guard let path = executable("codex") else { throw NinoError("Installe le CLI Codex et connecte ton compte.") }
        let bridge = try DashboardProcess(path: path, arguments: ["app-server"])
        defer { bridge.close() }
        try bridge.send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "nino", "version": "0.4.0"]]])
        _ = try bridge.response(1)
        try bridge.send(["method": "initialized"])
        try bridge.send(["id": 2, "method": "account/rateLimits/read", "params": [:]])
        let limits = try bridge.response(2)
        let byID = limits["rateLimitsByLimitId"] as? [String: Any]
        let quota = byID?["codex"] as? [String: Any] ?? limits["rateLimits"] as? [String: Any] ?? [:]
        let values = windows(quota, claude: false)
        let snapshot = QuotaSnapshot(windows: values, measured: Date(), error: values.isEmpty ? "Aucune limite d’abonnement fournie par Codex." : nil)
        do {
        try bridge.send(["id": 3, "method": "thread/list", "params": ["limit": 30, "sortKey": "updated_at", "useStateDbOnly": true]])
        let result = try bridge.response(3)
        let chats = (result["data"] as? [[String: Any]] ?? []).compactMap { row -> WorkChat? in
            guard let id = row["id"] as? String, UUID(uuidString: id) != nil else { return nil }
            return WorkChat(id: id, title: row["name"] as? String ?? "Chat sans titre", directory: row["cwd"] as? String ?? "", updated: Date(timeIntervalSince1970: row["updatedAt"] as? Double ?? 0))
        }
        return (snapshot, chats, nil)
        } catch { return (snapshot, nil, "Chats non actualisés : " + error.localizedDescription) }
    }
    static func claude() throws -> QuotaSnapshot {
        let helper = NinoPaths.helper.path
        guard FileManager.default.isExecutableFile(atPath: helper) else { throw NinoError("Le connecteur CodexBar est absent. Consulte le guide d’installation.") }
        let bridge = try DashboardProcess(path: helper, arguments: ["usage", "--provider", "claude", "--source", "cli", "--format", "json"], timeout: 60)
        defer { bridge.close() }
        guard let rows = try bridge.document() as? [[String: Any]], let row = rows.first(where: { $0["provider"] as? String == "claude" }), let usage = row["usage"] as? [String: Any] else { throw NinoError("Connecte Claude Code, puis actualise. La lecture /usage n’a pas fourni de quota.") }
        let values = windows(usage, claude: true)
        guard !values.isEmpty else { throw NinoError("Claude n’a fourni aucune limite d’abonnement.") }
        let measured = (usage["updatedAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        return QuotaSnapshot(windows: values, measured: measured, error: measured == nil ? "Date du relevé indisponible." : nil)
    }
}
@MainActor final class TodayStore: ObservableObject {
    @Published var codex = QuotaSnapshot()
    @Published var claude = QuotaSnapshot()
    @Published var chats: [WorkChat] = []
    @Published var chatsError: String?
    @Published var refreshing = false
    @Published var focus: String = UserDefaults.standard.string(forKey: "todayFocus") ?? "" {
        didSet { UserDefaults.standard.set(focus, forKey: "todayFocus") }
    }
    @Published var copied = false
    private var lastAttempt: Date?
    func refresh(force: Bool = false) async {
        guard !refreshing, force || lastAttempt == nil || Date().timeIntervalSince(lastAttempt!) > 300 else { return }
        refreshing = true; lastAttempt = Date()
        async let c = Task.detached { () -> Result<(QuotaSnapshot, [WorkChat]?, String?), Error> in Result { try DashboardReader.codex() } }.value
        async let a = Task.detached { () -> Result<QuotaSnapshot, Error> in Result { try DashboardReader.claude() } }.value
        switch await c {
        case .success(let value):
            codex = value.0
            if let rows = value.1 { chats = rows }
            chatsError = value.2
        case .failure(let error): codex.error = error.localizedDescription; chatsError = "Chats non actualisés : " + error.localizedDescription
        }
        switch await a {
        case .success(let value): claude = value
        case .failure(let error): claude.error = error.localizedDescription
        }
        refreshing = false
    }
    func copyTitle(_ chat: WorkChat) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(chat.title, forType: .string)
        copied = true
    }
}
