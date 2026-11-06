import Foundation
import Combine

/// Public releases only. No account, token, library, or conversation is sent.
struct NinoVersion: Comparable, Equatable, CustomStringConvertible {
    let parts: [Int]
    init?(_ value: String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let segments = text.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, segments.allSatisfy({ !$0.isEmpty && $0.count <= 6 && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              segments.allSatisfy({ $0.count == 1 || $0.first != "0" }) else { return nil }
        parts = segments.compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
    }
    var description: String { parts.map(String.init).joined(separator: ".") }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct NinoRelease: Equatable {
    let version: NinoVersion
    let notes: String
    let downloadURL: URL
    let size: Int
    var pageURL: URL { URL(string: "https://github.com/s4ndro6/nino/releases/tag/v\(version)")! }
}

enum NinoReleaseFeed {
    static let endpoint = URL(string: "https://api.github.com/repos/s4ndro6/nino/releases?per_page=30")!
    struct Asset: Decodable { let name: String; let browser_download_url: String; let size: Int; let state: String? }
    struct Entry: Decodable { let tag_name: String; let draft: Bool; let prerelease: Bool; let body: String?; let assets: [Asset] }
    static func newest(_ data: Data, current: String) throws -> NinoRelease? {
        guard data.count <= 1_048_576, let installed = NinoVersion(current) else { throw Failure.invalidFeed }
        let releases = try JSONDecoder().decode([Entry].self, from: data)
        // Public Nino is an alpha: published prereleases are intentionally eligible.
        return releases.compactMap { entry -> NinoRelease? in
            guard !entry.draft, let version = NinoVersion(entry.tag_name), entry.tag_name == "v\(version)", version > installed else { return nil }
            let name = "Nino-\(version)-macOS-arm64.dmg"
            let expected = "https://github.com/s4ndro6/nino/releases/download/v\(version)/\(name)"
            guard let asset = entry.assets.first(where: { $0.name == name && $0.browser_download_url == expected && $0.size > 0 && $0.size <= 200_000_000 && ($0.state == nil || $0.state == "uploaded") }),
                  let url = URL(string: expected) else { return nil }
            return NinoRelease(version: version, notes: String((entry.body ?? "Consulte les notes de version sur GitHub.").prefix(12_000)), downloadURL: url, size: asset.size)
        }.max { $0.version < $1.version }
    }
    enum Failure: LocalizedError {
        case invalidFeed, unavailable
        var errorDescription: String? { "Vérification indisponible. Réessaie plus tard ; ta version reste utilisable." }
    }
    static func fetch() async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCache = nil; config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 25
        let session = URLSession(configuration: config, delegate: NoUpdateRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Nino-Update-Check", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url == endpoint else { throw Failure.unavailable }
        var data = Data()
        for try await byte in bytes { guard data.count < 1_048_576 else { throw Failure.invalidFeed }; data.append(byte) }
        return data
    }
}
private final class NoUpdateRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor final class AppUpdates: ObservableObject {
    nonisolated static var installedVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.23.0" }
    @Published private(set) var automatic: Bool
    @Published private(set) var checking = false
    @Published private(set) var latest: NinoRelease?
    @Published private(set) var message = "Vérification automatique désactivée."
    @Published private(set) var lastCheck: Date?
    @Published private(set) var revision = 0
    @Published var showDetails = false
    @Published var installerReady = false
    @Published var installerMessage = ""
    var installAction: (() -> Void)?
    func installUpdate() { installAction?() }
    private let defaults: UserDefaults
    private let current: String
    private let fetch: () async throws -> Data
    private let now: () -> Date
    private var generation = 0
    private var task: Task<Void, Never>?
    private var timer: Timer?
    init(defaults: UserDefaults = .standard, current: String = AppUpdates.installedVersion,
         now: @escaping () -> Date = Date.init, fetch: @escaping () async throws -> Data = NinoReleaseFeed.fetch) {
        self.defaults = defaults; self.current = current; self.now = now; self.fetch = fetch
        automatic = defaults.bool(forKey: "updates.automatic")
        lastCheck = defaults.object(forKey: "updates.lastCheck") as? Date
        if let cached = defaults.data(forKey: "updates.feed"), cached.count <= 1_048_576 {
            latest = try? NinoReleaseFeed.newest(cached, current: current)
        }
        if automatic { message = "Recherche des versions publiques, alphas comprises." }
    }
    var hint: Bool {
        guard let latest else { return false }
        let version = latest.version.description
        if defaults.string(forKey: "updates.skipped") == version { return false }
        if defaults.string(forKey: "updates.laterVersion") == version,
           let until = defaults.object(forKey: "updates.laterUntil") as? Date, until > now() { return false }
        return true
    }
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.revision += 1; self?.requestCheck(manual: false) }
        }
        requestCheck(manual: false)
    }
    func setAutomatic(_ enabled: Bool) {
        automatic = enabled; defaults.set(enabled, forKey: "updates.automatic")
        if enabled { requestCheck(manual: false) }
        else {
            generation += 1; task?.cancel(); checking = false
            message = "Vérification automatique désactivée. Tu peux vérifier manuellement."
        }
    }
    func requestCheck(manual: Bool) {
        guard !checking else { return }
        if !manual {
            guard automatic else { return }
            if let last = defaults.object(forKey: "updates.lastAttempt") as? Date, now().timeIntervalSince(last) < 86_400 { return }
        }
        task = Task { await check(manual: manual) }
    }
    func check(manual: Bool) async {
        guard !checking, manual || automatic else { return }
        if !manual, let last = defaults.object(forKey: "updates.lastAttempt") as? Date, now().timeIntervalSince(last) < 86_400 { return }
        checking = true; message = "Vérification sur GitHub…"
        defaults.set(now(), forKey: "updates.lastAttempt")
        let requestGeneration = generation
        defer { if requestGeneration == generation { checking = false } }
        do {
            let data = try await fetch()
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            latest = try NinoReleaseFeed.newest(data, current: current)
            defaults.set(data, forKey: "updates.feed")
            lastCheck = now(); defaults.set(lastCheck, forKey: "updates.lastCheck")
            message = latest.map { "Nino \($0.version) est disponible." } ?? "Tu utilises la dernière version publiée pour Apple Silicon."
            revision += 1
        } catch {
            guard generation == requestGeneration else { return }
            // A stale offer remains in details, but errors never claim that the app is current.
            message = "Impossible de vérifier pour le moment. Réessaie plus tard."
        }
    }
    func later() {
        guard let latest else { return }
        defaults.set(latest.version.description, forKey: "updates.laterVersion")
        defaults.set(now().addingTimeInterval(86_400), forKey: "updates.laterUntil")
        revision += 1; showDetails = false
    }
    func skip() {
        guard let latest else { return }
        defaults.set(latest.version.description, forKey: "updates.skipped")
        revision += 1; showDetails = false
    }
}
