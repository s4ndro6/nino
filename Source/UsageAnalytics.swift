import Foundation
import Combine
import CoreFoundation
import Darwin

// No content, account identity, persistent installation ID or user-supplied value belongs here.
enum UsageEvent: String, Codable, CaseIterable {
    case recordingFailed = "recording_failed", transcriptionFailed = "transcription_failed"
    case appOpened = "app_opened", recordingStarted = "recording_started", recordingCompleted = "recording_completed"
    case transcriptionCompleted = "transcription_completed", documentImported = "document_imported", documentExported = "document_exported"
    case timerStarted = "timer_started", stickyNoteCreated = "sticky_note_created", assistantUsed = "assistant_used", connectorConnected = "connector_connected"
    case onboardingCompleted = "onboarding_completed", projectCreated = "project_created", feedbackCreated = "feedback_created", githubRefreshed = "github_refreshed"
}
enum UsageConsentChoice: String, Codable { case undecided, declined, accepted }
struct UsageConsentRecord: Codable {
    let policyVersion: Int
    let choice: UsageConsentChoice
    let decidedAtDay: String
}
struct UsageCounter: Codable, Equatable {
    let day: String
    let event: UsageEvent
    let majorVersion: Int
    var count: Int
    enum CodingKeys: String, CodingKey { case day, event, count; case majorVersion = "major_version" }
}
struct UsageBatch: Codable, Equatable {
    let schemaVersion: Int
    let policyVersion: Int
    let consentedAtDay: String
    let batchID: String
    let counters: [UsageCounter]
    enum CodingKeys: String, CodingKey {
        case counters; case schemaVersion = "schema_version", policyVersion = "policy_version", consentedAtDay = "consented_at_day", batchID = "batch_id"
    }
}
private struct UsageQueue: Codable, Equatable { var counters: [UsageCounter] = []; var pending: UsageBatch? }
enum UsageAnalyticsError: LocalizedError {
    case invalidEndpoint, invalidAcknowledgement, oversizedResponse, httpFailure, invalidQueue
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "L’adresse de mesure n’est pas une adresse HTTPS valide. Aucun envoi."
        case .invalidAcknowledgement: return "Le serveur n’a pas confirmé ce lot. Il reste disponible pour une nouvelle tentative."
        case .oversizedResponse: return "La réponse du serveur dépasse la limite autorisée."
        case .httpFailure: return "L’envoi n’a pas été confirmé. Le lot est conservé, sans relance automatique."
        case .invalidQueue: return "Le fichier de compteurs local est invalide. Il n’a pas été envoyé."
        }
    }
}

private final class UsageSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust { completionHandler(.performDefaultHandling, nil) }
        else { completionHandler(.cancelAuthenticationChallenge, nil) }
    }
}

@MainActor final class UsageAnalytics: ObservableObject {
    typealias Transport = @Sendable (URL, Data) async throws -> Data
    static let consentVersion = 1
    static let maxQueueBytes = 65_536
    static let maxCounters = 256
    static let maxBatchCounters = 128
    static let maxCount = 1_000
    @Published private(set) var consent = UsageConsentChoice.undecided
    @Published private(set) var pendingEventCount = 0
    @Published private(set) var isUploading = false
    @Published private(set) var status: String?
    let endpoint: URL?
    var hasEndpoint: Bool { endpoint != nil }
    private let root: URL
    private let folder: URL
    private let majorVersion: Int
    private let transport: Transport
    private let now: () -> Date
    private var consentRecord: UsageConsentRecord?
    private var queue = UsageQueue()
    private var generation = UUID()
    private var upload: Task<Data, Error>?
    private var consentURL: URL { folder.appendingPathComponent("usage-consent.json") }
    private var queueURL: URL { folder.appendingPathComponent("usage-queue.json") }
    init(root: URL, endpoint: URL? = nil, majorVersion: Int = 0, now: @escaping () -> Date = Date.init, transport: Transport? = nil) {
        self.root = root.standardizedFileURL
        folder = root.standardizedFileURL.appendingPathComponent("Privacy", isDirectory: true)
        self.endpoint = endpoint; self.majorVersion = min(999, max(0, majorVersion)); self.now = now
        self.transport = transport ?? { endpoint, body in try await Self.send(endpoint: endpoint, body: body) }
        load()
    }
    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    private static func validDay(_ value: String) -> Bool {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        guard value.count == 10, let date = formatter.date(from: value) else { return false }; return formatter.string(from: date) == value
    }
    private func valid(_ counter: UsageCounter) -> Bool {
        let today = Self.day(now()), earliest = Self.day(now().addingTimeInterval(-30 * 86_400))
        return Self.validDay(counter.day) && counter.day >= earliest && counter.day <= today && counter.day >= (consentRecord?.decidedAtDay ?? today)
            && (0...999).contains(counter.majorVersion) && (1...Self.maxCount).contains(counter.count)
    }
    private func load() {
        guard let data = try? boundedRead(consentURL, maximum: 2_048), let record = try? JSONDecoder().decode(UsageConsentRecord.self, from: data), record.policyVersion == Self.consentVersion,
              Self.validDay(record.decidedAtDay), record.decidedAtDay <= Self.day(now()) else { try? deleteQueue(); return }
        consent = record.choice; consentRecord = record
        guard consent == .accepted else { try? deleteQueue(); return }
        guard FileManager.default.fileExists(atPath: queueURL.path) else { return }
        do {
            let decoded = try JSONDecoder().decode(UsageQueue.self, from: boundedRead(queueURL, maximum: Self.maxQueueBytes))
            guard decoded.counters.count <= Self.maxCounters, (decoded.pending?.counters.count ?? 0) <= Self.maxBatchCounters else { throw UsageAnalyticsError.invalidQueue }
            queue.counters = decoded.counters.filter(valid)
            if let pending = decoded.pending, pending.schemaVersion == 1, pending.policyVersion == Self.consentVersion,
               pending.consentedAtDay == record.decidedAtDay, UUID(uuidString: pending.batchID) != nil, !pending.counters.isEmpty, pending.counters.allSatisfy(valid) { queue.pending = pending }
            // Expiry is persisted on launch, not only hidden in the interface.
            try write(queue, to: queueURL, maximum: Self.maxQueueBytes)
            refreshCount()
        } catch { queue = UsageQueue(); try? deleteQueue(); status = UsageAnalyticsError.invalidQueue.localizedDescription }
    }
    /// Refuse symlinks at every existing ancestor, including the caller's root and Privacy.
    private func validatePath(_ url: URL) throws {
        guard root.isFileURL, url.isFileURL, url == consentURL || url == queueURL else { throw UsageAnalyticsError.invalidQueue }
        var current = URL(fileURLWithPath: "/", isDirectory: true)
        let components = url.standardizedFileURL.pathComponents.dropFirst()
        for (index, component) in components.enumerated() {
            current.appendPathComponent(component)
            var info = stat()
            if lstat(current.path, &info) != 0 {
                guard errno == ENOENT, current.path == folder.path || current.path == url.path else { throw UsageAnalyticsError.invalidQueue }
                continue
            }
            let kind = info.st_mode & S_IFMT
            if index == components.count - 1 {
                guard kind == S_IFREG, info.st_nlink == 1 else { throw UsageAnalyticsError.invalidQueue }
            } else {
                guard kind == S_IFDIR else { throw UsageAnalyticsError.invalidQueue }
            }
        }
    }
    private func deleteQueue() throws {
        try validatePath(queueURL)
        if FileManager.default.fileExists(atPath: queueURL.path) { try FileManager.default.removeItem(at: queueURL) }
    }
    private func boundedRead(_ url: URL, maximum: Int) throws -> Data {
        try validatePath(url)
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? Int.max) <= maximum else { throw UsageAnalyticsError.invalidQueue }
        let data = try Data(contentsOf: url); guard data.count <= maximum else { throw UsageAnalyticsError.invalidQueue }; return data
    }
    private func write<T: Encodable>(_ value: T, to url: URL, maximum: Int) throws {
        try validatePath(url)
        let data = try JSONEncoder().encode(value); guard data.count <= maximum else { throw UsageAnalyticsError.invalidQueue }
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        try validatePath(url)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    /// Returns false if the user's choice could not be saved; the UI must not silently continue.
    @discardableResult func setConsent(_ choice: UsageConsentChoice) -> Bool {
        if choice == .accepted && consent == .accepted { return true }
        if choice != .accepted {
            generation = UUID(); upload?.cancel(); upload = nil; isUploading = false; consent = choice; queue = UsageQueue(); refreshCount()
        }
        let record = UsageConsentRecord(policyVersion: Self.consentVersion, choice: choice, decidedAtDay: Self.day(now()))
        do {
            // A fresh opt-in never resurrects a queue left by a failed withdrawal cleanup.
            if choice == .accepted { try deleteQueue() }
            try write(record, to: consentURL, maximum: 2_048)
            if choice != .accepted { try deleteQueue() }
            if choice == .accepted, consent != .accepted { queue = UsageQueue(); refreshCount() }
            consentRecord = record; consent = choice
            status = choice == .accepted ? "Choix enregistré. Seuls des compteurs d’usage sont conservés sur ce Mac. Aucun envoi automatique." : "Choix enregistré. Aucun nouveau compteur n’est collecté ; les compteurs locaux ont été effacés."
            return true
        } catch {
            status = "Le choix ou l’effacement n’a pas pu être sauvegardé sur le disque : \(error.localizedDescription). La collecte est arrêtée pour cette session."
            consent = .declined; generation = UUID(); upload?.cancel(); upload = nil; isUploading = false
            return false
        }
    }
    private func expirePending() throws {
        let previous = queue
        queue.counters = queue.counters.filter(valid)
        if let pending = queue.pending, !pending.counters.allSatisfy(valid) { queue.pending = nil }
        if queue != previous {
            do { try write(queue, to: queueURL, maximum: Self.maxQueueBytes); refreshCount() }
            catch { queue = previous; throw error }
        }
    }
    func track(_ event: UsageEvent) {
        guard consent == .accepted, consentRecord?.policyVersion == Self.consentVersion else { return }
        do { try expirePending() } catch { status = "La purge des compteurs expirés a échoué."; return }
        let old = queue
        let day = Self.day(now())
        if let index = queue.counters.firstIndex(where: { $0.day == day && $0.event == event && $0.majorVersion == majorVersion }) {
            guard queue.counters[index].count < Self.maxCount else { return }; queue.counters[index].count += 1
        } else {
            guard queue.counters.count < Self.maxCounters else { status = "La limite locale est atteinte. Aucun nouveau compteur n’est ajouté."; return }
            queue.counters.append(UsageCounter(day: day, event: event, majorVersion: majorVersion, count: 1))
        }
        do { try write(queue, to: queueURL, maximum: Self.maxQueueBytes); refreshCount() }
        catch { queue = old; status = "Impossible de conserver ce compteur localement." }
    }
    func purgePending() {
        generation = UUID(); upload?.cancel(); upload = nil; isUploading = false; queue = UsageQueue(); refreshCount()
        do {
            try deleteQueue()
            status = "Compteurs locaux effacés. Les totaux déjà reçus par un serveur ne peuvent pas être rattachés à toi pour les retirer individuellement."
        } catch { status = "L’effacement local a échoué : \(error.localizedDescription)" }
    }
    private func refreshCount() { pendingEventCount = queue.counters.reduce(0) { $0 + $1.count } + (queue.pending?.counters.reduce(0) { $0 + $1.count } ?? 0) }
    func uploadPending() async {
        guard consent == .accepted, !isUploading else { return }
        guard let endpoint else { status = "Préparation locale : aucun serveur n’est configuré, aucun envoi n’est possible."; return }
        guard Self.validEndpoint(endpoint) else { status = UsageAnalyticsError.invalidEndpoint.localizedDescription; return }
        guard let record = consentRecord, record.policyVersion == Self.consentVersion else { return }
        let token = generation
        do {
            // Drop expired counters before any request; never replay a batch outside the retention window.
            try expirePending()
            if queue.pending == nil {
                let counters = Array(queue.counters.prefix(Self.maxBatchCounters))
                guard !counters.isEmpty else { status = "Aucun compteur à envoyer."; refreshCount(); return }
                queue.pending = UsageBatch(schemaVersion: 1, policyVersion: Self.consentVersion, consentedAtDay: record.decidedAtDay, batchID: UUID().uuidString.lowercased(), counters: counters)
                queue.counters.removeFirst(counters.count)
            }
            try write(queue, to: queueURL, maximum: Self.maxQueueBytes)
            guard let batch = queue.pending else { return }
            let body = try JSONEncoder().encode(batch)
            isUploading = true; status = "Envoi du lot choisi…"
            let transport = self.transport
            let task = Task { try await transport(endpoint, body) }; upload = task
            defer { if generation == token { upload = nil; isUploading = false } }
            let response = try await withTaskCancellationHandler(operation: { let result = try await task.value; try Task.checkCancellation(); return result }, onCancel: { task.cancel() })
            guard generation == token, consent == .accepted else { return }
            try Self.validateAck(response, for: batch)
            let acknowledged = queue.pending; queue.pending = nil
            do { try write(queue, to: queueURL, maximum: Self.maxQueueBytes) } catch { queue.pending = acknowledged; throw error }
            refreshCount()
            status = "Lot reçu. Aucun autre envoi ne sera lancé automatiquement."
        } catch is CancellationError { if generation == token, consent == .accepted { status = "Envoi annulé. Une réception par le serveur reste possible si l’envoi avait commencé." } }
        catch { if generation == token, consent == .accepted { status = error.localizedDescription } }
    }
    static func validEndpoint(_ url: URL) -> Bool { url.scheme == "https" && url.host?.isEmpty == false && url.user == nil && url.password == nil && url.query == nil && url.fragment == nil && url.path == "/v1/usage" }
    static func validateAck(_ data: Data, for batch: UsageBatch) throws {
        guard data.count <= 4_096, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == Set(["schema_version", "batch_id", "accepted_count", "duplicate"]),
              let version = object["schema_version"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version.doubleValue == 1,
              object["batch_id"] as? String == batch.batchID,
              let count = object["accepted_count"] as? NSNumber, CFGetTypeID(count) != CFBooleanGetTypeID(), count.doubleValue == Double(batch.counters.reduce(0) { $0 + $1.count }),
              let duplicate = object["duplicate"] as? NSNumber, CFGetTypeID(duplicate) == CFBooleanGetTypeID() else { throw UsageAnalyticsError.invalidAcknowledgement }
    }
    nonisolated private static func send(endpoint: URL, body: Data) async throws -> Data {
        guard body.count <= 65_536 else { throw UsageAnalyticsError.invalidQueue }
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false; config.urlCredentialStorage = nil; config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData; config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config, delegate: UsageSessionDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.mimeType == "application/json", http.expectedContentLength <= 4_096 else { throw UsageAnalyticsError.httpFailure }
        var data = Data()
        for try await byte in bytes { try Task.checkCancellation(); guard data.count < 4_096 else { throw UsageAnalyticsError.oversizedResponse }; data.append(byte) }
        return data
    }
}
