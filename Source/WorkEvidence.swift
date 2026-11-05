import Foundation
import Combine

struct EvidenceFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum FeedbackStatus: String, Codable, CaseIterable, Identifiable {
    case todo, inProgress, review, done
    var id: String { rawValue }
    var label: String {
        switch self { case .todo: return "À traiter"; case .inProgress: return "En cours"; case .review: return "À valider"; case .done: return "Validé" }
    }
}

enum EvidenceValidation {
    static func webURL(_ text: String) -> URL? {
        guard text.count <= 2000, !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
    /// Wall-clock time, not frame-based SMPTE. Empty means no timecode.
    static func milliseconds(_ text: String) throws -> Int? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count), text.count <= 16 else { throw EvidenceFailure("Timecode attendu : mm:ss ou hh:mm:ss, avec .mmm facultatif.") }
        func digits(_ part: Substring) -> Bool { !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) } }
        let seconds = parts.last!.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(seconds.count), digits(seconds[0]), let sec = Int(seconds[0]), sec < 60,
              parts.dropLast().allSatisfy(digits), let min = Int(parts[parts.count - 2]), min < 60 else { throw EvidenceFailure("Minutes et secondes doivent être comprises entre 00 et 59.") }
        let hours = parts.count == 3 ? Int(parts[0])! : 0
        guard hours < 100 else { throw EvidenceFailure("Le timecode doit rester inférieur à 100 heures.") }
        var fraction = 0
        if seconds.count == 2 {
            guard digits(seconds[1]), seconds[1].count <= 3 else { throw EvidenceFailure("Utilise au maximum trois décimales pour les millisecondes.") }
            fraction = Int(seconds[1])! * (seconds[1].count == 1 ? 100 : seconds[1].count == 2 ? 10 : 1)
        }
        return ((hours * 60 + min) * 60 + sec) * 1000 + fraction
    }
    static func timecode(_ ms: Int?) -> String {
        guard let ms else { return "—" }
        let seconds = ms / 1000
        let base = String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        return ms % 1000 == 0 ? base : base + String(format: ".%03d", ms % 1000)
    }
}

struct WorkFeedback: Codable, Identifiable, Equatable {
    var id = UUID()
    var projectID: UUID
    var version: String
    var timecodeMilliseconds: Int?
    var author: String
    var text: String
    var status: FeedbackStatus = .todo
    var sourceURL: String = ""
    var createdAt = Date()
    var updatedAt = Date()
    func validate() throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 3000,
              version.count <= 80, author.count <= 100,
              timecodeMilliseconds.map({ (0..<360_000_000).contains($0) }) ?? true,
              sourceURL.isEmpty || EvidenceValidation.webURL(sourceURL) != nil else { throw EvidenceFailure("Vérifie le retour, sa longueur, le timecode et le lien HTTP(S).") }
    }
}

struct PublicGitHubRepository: Equatable, Sendable {
    let owner: String
    let name: String
    init(url text: String) throws {
        guard let url = EvidenceValidation.webURL(text), url.scheme == "https", url.host?.lowercased() == "github.com",
              url.port == nil, url.query == nil, url.fragment == nil else { throw EvidenceFailure("Colle l’URL HTTPS d’un dépôt public : https://github.com/organisation/depot") }
        let pieces = url.path.split(separator: "/", omittingEmptySubsequences: true)
        guard pieces.count == 2, pieces[0].count <= 100, pieces[1].count <= 100,
              pieces.allSatisfy({ piece in piece != "." && piece != ".." && piece.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 46, 95].contains($0) } }) else { throw EvidenceFailure("Le lien doit désigner le dépôt, sans sous-page ni paramètres.") }
        owner = String(pieces[0]); name = String(pieces[1])
    }
    var url: String { "https://github.com/\(owner)/\(name)" }
    var apiURL: URL { URL(string: "https://api.github.com/repos/\(owner)/\(name)/actions/runs?per_page=5")! }
}

struct GitHubRunEvidence: Codable, Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let branch: String
    let sha: String
    let status: String
    let conclusion: String?
    let url: String
    let updatedAt: Date
    var label: String { conclusion ?? status }
}
struct GitHubEvidenceSnapshot: Codable, Equatable, Sendable {
    let projectID: UUID
    let repositoryURL: String
    let fetchedAt: Date
    let runs: [GitHubRunEvidence]
    func isStale(at now: Date = Date()) -> Bool { now.timeIntervalSince(fetchedAt) > 900 || now < fetchedAt }
}

enum PublicGitHubReader {
    static let bodyLimit = 1_048_576
    static func read(repository: PublicGitHubRepository, projectID: UUID) async throws -> GitHubEvidenceSnapshot {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15; configuration.timeoutIntervalForResource = 20
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: GitHubNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: repository.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Nino-Public-Actions", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw EvidenceFailure("Réponse GitHub invalide.") }
        try validateHTTP(status: response.statusCode, expectedLength: response.expectedContentLength)
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < bodyLimit else { throw EvidenceFailure("Réponse GitHub trop volumineuse.") }
            data.append(byte)
        }
        return try parse(data, repository: repository, projectID: projectID)
    }
    static func validateHTTP(status: Int, expectedLength: Int64) throws {
        guard expectedLength <= bodyLimit else { throw EvidenceFailure("Réponse GitHub trop volumineuse.") }
        switch status {
        case 200: break
        case 401, 404: throw EvidenceFailure("Dépôt introuvable ou privé. Ce connecteur lit uniquement les dépôts publics sans authentification.")
        case 403, 429: throw EvidenceFailure("GitHub refuse temporairement la lecture (quota ou accès). Réessaie plus tard.")
        case 300..<400: throw EvidenceFailure("GitHub redirige ce dépôt. Utilise son URL actuelle ; aucune redirection n’a été suivie.")
        default: throw EvidenceFailure("Lecture GitHub indisponible (HTTP \(status)). Le dernier relevé est conservé.")
        }
    }
    static func parse(_ data: Data, repository: PublicGitHubRepository, projectID: UUID, fetchedAt: Date = Date()) throws -> GitHubEvidenceSnapshot {
        guard data.count <= bodyLimit else { throw EvidenceFailure("Réponse GitHub trop volumineuse.") }
        struct Envelope: Decodable { let workflow_runs: [Run] }
        struct Run: Decodable { let id: Int64; let name: String?; let head_branch: String?; let head_sha: String; let status: String; let conclusion: String?; let html_url: String; let updated_at: String }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.workflow_runs.count <= 5 else { throw EvidenceFailure("GitHub a renvoyé plus de cinq résultats.") }
        let formatter = ISO8601DateFormatter()
        let runs = try envelope.workflow_runs.map { item -> GitHubRunEvidence in
            let expected = repository.url + "/actions/runs/\(item.id)"
            guard item.id > 0, item.name?.count ?? 0 <= 200, item.head_branch?.count ?? 0 <= 300,
                  item.head_sha.count == 40, item.head_sha.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
                  ["completed", "requested", "queued", "pending", "waiting", "in_progress"].contains(item.status),
                  item.conclusion.map({ ["action_required", "cancelled", "failure", "neutral", "success", "skipped", "stale", "timed_out", "startup_failure"].contains($0) }) ?? true,
                  item.html_url.lowercased() == expected.lowercased(), let date = formatter.date(from: item.updated_at) else { throw EvidenceFailure("Métadonnées GitHub incohérentes ; relevé refusé.") }
            return GitHubRunEvidence(id: item.id, name: item.name ?? "Workflow", branch: item.head_branch ?? "", sha: item.head_sha, status: item.status, conclusion: item.conclusion, url: expected, updatedAt: date)
        }
        guard Set(runs.map(\.id)).count == runs.count else { throw EvidenceFailure("Résultats GitHub dupliqués.") }
        return GitHubEvidenceSnapshot(projectID: projectID, repositoryURL: repository.url, fetchedAt: fetchedAt, runs: runs)
    }
}
private final class GitHubNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct WorkEvidenceState: Codable {
    var schemaVersion = 1
    var feedback: [WorkFeedback] = []
    var snapshots: [GitHubEvidenceSnapshot] = []
    func validate() throws {
        guard schemaVersion == 1, feedback.count <= 1500, snapshots.count <= 100,
              Set(feedback.map(\.id)).count == feedback.count,
              Set(snapshots.map(\.projectID)).count == snapshots.count else { throw EvidenceFailure("Format ou capacité du carnet de preuves dépassé.") }
        for item in feedback { try item.validate() }
        for snapshot in snapshots {
            let repository = try PublicGitHubRepository(url: snapshot.repositoryURL)
            guard snapshot.runs.count <= 5 else { throw EvidenceFailure("Relevé GitHub trop volumineux.") }
            for run in snapshot.runs {
                guard run.id > 0, run.name.count <= 200, run.branch.count <= 300, run.sha.count == 40,
                      run.sha.allSatisfy(\.isHexDigit), run.status.count <= 40, run.conclusion?.count ?? 0 <= 40,
                      run.url == repository.url + "/actions/runs/\(run.id)" else { throw EvidenceFailure("Relevé GitHub local invalide.") }
            }
        }
    }
}
struct WorkEvidenceRepository {
    let fileURL: URL
    static let byteLimit = 4_194_304
    func checkPath(create: Bool) throws {
        guard fileURL.isFileURL else { throw EvidenceFailure("Stockage local requis.") }
        let path = fileURL.standardizedFileURL
        guard path.path == path.resolvingSymlinksInPath().path else { throw EvidenceFailure("Le carnet de preuves ne peut pas utiliser un lien symbolique.") }
        if create {
            let parent = fileURL.deletingLastPathComponent()
            guard FileManager.default.fileExists(atPath: parent.deletingLastPathComponent().path) else {
                throw EvidenceFailure("Le disque Nino n’est pas disponible. Rebranche-le avant de sauvegarder.")
            }
            var directory: ObjCBool = false
            if FileManager.default.fileExists(atPath: parent.path, isDirectory: &directory) {
                guard directory.boolValue else { throw EvidenceFailure("Dossier des preuves invalide.") }
            } else {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
            }
        }
    }
    func load() throws -> WorkEvidenceState {
        try checkPath(create: false)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return WorkEvidenceState() }
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= Self.byteLimit else { throw EvidenceFailure("Fichier de preuves invalide ou trop volumineux.") }
        let data = try Data(contentsOf: fileURL)
        guard data.count <= Self.byteLimit else { throw EvidenceFailure("Fichier de preuves trop volumineux.") }
        let state = try JSONDecoder().decode(WorkEvidenceState.self, from: data); try state.validate(); return state
    }
    func save(_ state: WorkEvidenceState) throws {
        try state.validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        guard data.count <= Self.byteLimit else { throw EvidenceFailure("Carnet de preuves plein. Exporte tes retours avant d’en ajouter.") }
        try checkPath(create: true); try data.write(to: fileURL, options: .atomic)
    }
}

@MainActor final class WorkEvidenceStore: ObservableObject {
    var onFeedbackCreated: (() -> Void)?
    var onGitHubRefreshed: (() -> Void)?
    @Published private(set) var state = WorkEvidenceState()
    @Published private(set) var ready = false
    @Published private(set) var issue: String?
    @Published private(set) var refreshingProjectID: UUID?
    private let repository: WorkEvidenceRepository
    init(fileURL: URL) {
        repository = WorkEvidenceRepository(fileURL: fileURL)
        do { state = try repository.load(); ready = true }
        catch { issue = "Carnet non ouvert : \(error.localizedDescription). Le fichier existant est conservé." }
    }
    func feedback(for projectID: UUID) -> [WorkFeedback] { state.feedback.filter { $0.projectID == projectID }.sorted { $0.createdAt > $1.createdAt } }
    func snapshot(for projectID: UUID) -> GitHubEvidenceSnapshot? { state.snapshots.first { $0.projectID == projectID } }
    @discardableResult func add(_ feedback: WorkFeedback) -> Bool { var next = state; next.feedback.append(feedback); let saved = persist(next); if saved { onFeedbackCreated?() }; return saved }
    func setStatus(_ status: FeedbackStatus, id: UUID, projectID: UUID) {
        var next = state
        guard let i = next.feedback.firstIndex(where: { $0.id == id && $0.projectID == projectID }) else { return }
        next.feedback[i].status = status; next.feedback[i].updatedAt = Date(); _ = persist(next)
    }
    private func persist(_ next: WorkEvidenceState) -> Bool {
        guard ready else { return false }
        do { try repository.save(next); state = next; issue = nil; return true }
        catch { issue = error.localizedDescription; return false }
    }
    func refresh(repositoryURL: String, projectID: UUID) async {
        guard ready, refreshingProjectID == nil else { return }
        refreshingProjectID = projectID; defer { refreshingProjectID = nil }
        do {
            let repository = try PublicGitHubRepository(url: repositoryURL)
            let snapshot = try await PublicGitHubReader.read(repository: repository, projectID: projectID)
            var next = state; next.snapshots.removeAll { $0.projectID == projectID }; next.snapshots.append(snapshot); if persist(next) { onGitHubRefreshed?() }
        } catch { issue = "Lecture non actualisée : \(error.localizedDescription)" }
    }
}

enum FeedbackExport {
    static func csv(_ feedback: [WorkFeedback]) -> String {
        func cell(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let protected = trimmed.first.map { "=+-@".contains($0) } == true || text.first == "\t" || text.first == "\r" ? "'" + text : text
            return "\"" + protected.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var rows = [["Version", "Timecode", "Auteur", "Retour", "Statut déclaré", "Source non vérifiée", "Créé", "Modifié"]]
        let iso = ISO8601DateFormatter()
        rows += feedback.map { [$0.version, EvidenceValidation.timecode($0.timecodeMilliseconds), $0.author, $0.text, $0.status.label, $0.sourceURL, iso.string(from: $0.createdAt), iso.string(from: $0.updatedAt)] }
        return rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
    static func markdown(_ feedback: [WorkFeedback], title: String) -> String {
        func literal(_ text: String) -> String { text.map { "\\`*_{}[]<>#|!".contains($0) ? "\\" + String($0) : String($0) }.joined() }
        let iso = ISO8601DateFormatter()
        return "# Retours · \(literal(title))\n\nStatuts saisis manuellement ; les liens sources ne sont pas vérifiés. Timecodes en heures, minutes, secondes, millisecondes (pas en images).\n\n" + feedback.map {
            "## \(literal($0.version.isEmpty ? "Sans version" : $0.version)) · \(EvidenceValidation.timecode($0.timecodeMilliseconds))\n\n- Auteur : \(literal($0.author))\n- Statut déclaré : \($0.status.label)\n- Modifié : \(iso.string(from: $0.updatedAt))\n- Source non vérifiée : \(literal($0.sourceURL))\n\n" + $0.text.components(separatedBy: .newlines).map { "> " + literal($0) }.joined(separator: "\n") + "\n"
        }.joined(separator: "\n")
    }
}
