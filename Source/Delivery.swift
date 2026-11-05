import Foundation
import AVFoundation
import ImageIO
import Combine

enum DeliveryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case video, image, file
    var id: String { rawValue }
    var label: String { switch self { case .video: return "Vidéo"; case .image: return "Image"; case .file: return "Fichier" } }
}
struct DeliveryRequirement: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name = "livrable.pdf"
    var kind = DeliveryKind.file
    var width = 0
    var height = 0
    var maxSeconds = 0.0
    var maxMB = 0.0 // Decimal MB, matching the UI.
    var needsAudio = false
    var valid: Bool {
        !name.isEmpty && name.count <= 200 && !name.hasPrefix(".") && !name.contains("/") && !name.contains("\\") &&
        !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) &&
        (0...32768).contains(width) && (0...32768).contains(height) &&
        maxSeconds.isFinite && (0...86400).contains(maxSeconds) && maxMB.isFinite && (0...100000).contains(maxMB)
    }
}
struct DeliveryPlan: Codable, Equatable, Sendable {
    var brief = ""
    var requirements: [DeliveryRequirement] = []
    var valid: Bool { brief.count <= 6000 && (1...30).contains(requirements.count) && requirements.allSatisfy(\.valid) && Set(requirements.map(\.id)).count == requirements.count && Set(requirements.map { $0.name.lowercased() }).count == requirements.count }
    static var video: Self { Self(requirements: [
        DeliveryRequirement(name: "horizontal.mp4", kind: .video, width: 1920, height: 1080, maxSeconds: 60, maxMB: 100, needsAudio: true),
        DeliveryRequirement(name: "vertical.mp4", kind: .video, width: 1080, height: 1920, maxSeconds: 60, maxMB: 100, needsAudio: true),
        DeliveryRequirement(name: "sous-titres.srt", kind: .file)]) }
    static var images: Self { Self(requirements: [DeliveryRequirement(name: "carre.png", kind: .image, width: 1080, height: 1080, maxMB: 10), DeliveryRequirement(name: "story.png", kind: .image, width: 1080, height: 1920, maxMB: 10)]) }
    static var empty: Self { Self(requirements: [DeliveryRequirement()]) }
}
enum DeliveryVerdict: String, Sendable { case pass, fail, unknown }
struct DeliveryCheck: Identifiable, Sendable {
    var id = UUID()
    let title: String
    let verdict: DeliveryVerdict
    let detail: String
}
struct DeliveryFileResult: Identifiable, Sendable {
    let id: UUID
    let name: String
    let checks: [DeliveryCheck]
    let canReveal: Bool
    var verdict: DeliveryVerdict { checks.contains { $0.verdict == .fail } ? .fail : checks.contains { $0.verdict == .unknown } ? .unknown : .pass }
}
struct DeliveryReport: Sendable {
    let date: Date
    let files: [DeliveryFileResult]
    var failures: Int { files.flatMap(\.checks).filter { $0.verdict == .fail }.count }
    var unknowns: Int { files.flatMap(\.checks).filter { $0.verdict == .unknown }.count }
    var passed: Int { files.filter { $0.verdict == .pass }.count }
    var title: String { failures > 0 ? "\(failures) écart\(failures > 1 ? "s" : "") à traiter" : unknowns > 0 ? "\(unknowns) contrôle\(unknowns > 1 ? "s" : "") incomplet\(unknowns > 1 ? "s" : "")" : "Critères vérifiés" }
    var markdown: String {
        "# Contrôle de livraison\n\nDate : \(ISO8601DateFormatter().string(from: date))\n\n\(title)\n\n" + files.map { file in
            "## \(file.name)\n" + file.checks.map { "- [\($0.verdict == .pass ? "OK" : $0.verdict == .fail ? "ÉCART" : "NON VÉRIFIÉ")] \($0.title) : \($0.detail)" }.joined(separator: "\n")
        }.joined(separator: "\n\n") + "\n\nInstantané des fichiers au moment du contrôle. Les règles sont saisies par l’utilisateur ; le brief libre n’est pas interprété. Ni qualité créative, ni audibilité, ni conformité complète du contenu ne sont garanties. Relancer après toute modification.\n"
    }
}
struct DeliveryFailure: LocalizedError { let message: String; var errorDescription: String? { message } }
struct DeliveryMetadata: Sendable {
    var width: Int?
    var height: Int?
    var seconds: Double?
    var audio: Bool?
    var readable = false
}

/// Read-only, exact filename matching. No shell, recursive scan or cloud request.
enum DeliveryInspector {
    static func safeFolder(_ folder: URL) throws {
        guard folder.isFileURL, folder.standardizedFileURL.path == folder.resolvingSymlinksInPath().path else { throw DeliveryFailure(message: "Choisis un dossier local direct, sans lien symbolique.") }
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw DeliveryFailure(message: "Ce chemin n’est pas un dossier accessible.") }
    }
    static func safeFile(_ folder: URL, name: String) throws -> URL {
        try safeFolder(folder)
        let rule = DeliveryRequirement(name: name)
        guard rule.valid else { throw DeliveryFailure(message: "Nom de fichier invalide.") }
        let url = folder.appendingPathComponent(name)
        guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().path else { throw DeliveryFailure(message: "Lien symbolique ignoré.") }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw DeliveryFailure(message: "Fichier régulier attendu ; dossiers et liens sont ignorés.") }
        return url
    }
    struct Fingerprint: Equatable {
        let size: Int
        let modified: Date
        let inode: UInt64
    }
    static func fingerprint(_ url: URL) throws -> Fingerprint {
        let values = try FileManager.default.attributesOfItem(atPath: url.path)
        guard values[.type] as? FileAttributeType == .typeRegular,
              let size = values[.size] as? NSNumber, let date = values[.modificationDate] as? Date,
              let inode = values[.systemFileNumber] as? NSNumber else { throw DeliveryFailure(message: "État du fichier non vérifiable.") }
        return Fingerprint(size: size.intValue, modified: date, inode: inode.uint64Value)
    }
    static func inspect(folder: URL, rule: DeliveryRequirement, metadataReader: @Sendable (URL, DeliveryKind) async throws -> DeliveryMetadata = metadata) async throws -> DeliveryFileResult {
        try Task.checkCancellation()
        var checks: [DeliveryCheck] = []
        let url: URL
        do { url = try safeFile(folder, name: rule.name) }
        catch {
            let ns = error as NSError
            let missing = ns.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(ns.code)
            return DeliveryFileResult(id: rule.id, name: rule.name, checks: [.init(title: "Présence", verdict: missing ? .fail : .unknown, detail: missing ? "Fichier attendu absent du dossier choisi." : "Lecture impossible : \(error.localizedDescription)")], canReveal: false)
        }
        let before = try fingerprint(url)
        let bytes = before.size
        checks.append(.init(title: "Présence", verdict: bytes > 0 ? .pass : .fail, detail: bytes > 0 ? "Fichier présent · \(String(format: "%.2f", Double(bytes) / 1_000_000)) Mo." : "Le fichier est vide."))
        if rule.maxMB > 0 { checks.append(.init(title: "Poids", verdict: Double(bytes) <= rule.maxMB * 1_000_000 ? .pass : .fail, detail: "\(String(format: "%.2f", Double(bytes) / 1_000_000)) Mo · maximum \(rule.maxMB.formatted()) Mo.")) }
        if rule.kind != .file {
            let metadata: DeliveryMetadata
            do { metadata = try await metadataReader(url, rule.kind) }
            catch is CancellationError { throw CancellationError() }
            catch { metadata = DeliveryMetadata() }
            checks += evaluate(rule: rule, metadata: metadata)
        }
        let after = try fingerprint(url)
        if before != after {
            checks = [.init(title: "Fichier en cours de modification", verdict: .unknown, detail: "L’export a changé pendant le contrôle. Attends sa fin et relance.")]
        }
        return DeliveryFileResult(id: rule.id, name: rule.name, checks: checks, canReveal: true)
    }
    static func evaluate(rule: DeliveryRequirement, metadata m: DeliveryMetadata) -> [DeliveryCheck] {
        guard m.readable else { return [.init(title: "Métadonnées", verdict: .unknown, detail: "Média illisible ou format non pris en charge. Aucun critère média n’est validé.")] }
        var result: [DeliveryCheck] = [.init(title: "Métadonnées", verdict: .pass, detail: "\(rule.kind.label) reconnue. Pas de décodage intégral du contenu.")]
        if rule.width > 0 || rule.height > 0 {
            if let w = m.width, let h = m.height {
                let matches = (rule.width == 0 || rule.width == w) && (rule.height == 0 || rule.height == h)
                result.append(.init(title: "Dimensions", verdict: matches ? .pass : .fail, detail: "\(w) × \(h) px · attendu \(rule.width > 0 ? String(rule.width) : "libre") × \(rule.height > 0 ? String(rule.height) : "libre") px."))
            } else { result.append(.init(title: "Dimensions", verdict: .unknown, detail: "Dimensions non disponibles.")) }
        }
        if rule.kind == .video && rule.maxSeconds > 0 {
            if let seconds = m.seconds, seconds.isFinite, seconds > 0 {
                result.append(.init(title: "Durée", verdict: seconds <= rule.maxSeconds + 0.001 ? .pass : .fail, detail: "\(String(format: "%.2f", seconds)) s · maximum \(rule.maxSeconds.formatted()) s."))
            } else { result.append(.init(title: "Durée", verdict: .unknown, detail: "Durée non disponible.")) }
        }
        if rule.kind == .video && rule.needsAudio {
            result.append(.init(title: "Piste audio", verdict: m.audio.map { $0 ? .pass : .fail } ?? .unknown, detail: m.audio == true ? "Piste présente. Le silence et la qualité sonore ne sont pas analysés." : m.audio == false ? "Aucune piste audio dans ce fichier." : "Présence audio non vérifiable."))
        }
        return result
    }
    static func displayDimensions(size: CGSize, transform: CGAffineTransform) -> (Int, Int)? {
        let rect = CGRect(origin: .zero, size: size).applying(transform)
        let w = abs(rect.width).rounded(), h = abs(rect.height).rounded()
        guard w.isFinite, h.isFinite, w > 0, h > 0, w <= 100000, h <= 100000 else { return nil }
        return (Int(w), Int(h))
    }
    static func metadata(_ url: URL, kind: DeliveryKind) async throws -> DeliveryMetadata {
        if kind == .image {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else { return DeliveryMetadata() }
            let rotated = (5...8).contains(p[kCGImagePropertyOrientation] as? Int ?? 1)
            return DeliveryMetadata(width: rotated ? h : w, height: rotated ? w : h, readable: true)
        }
        let asset = AVURLAsset(url: url, options: [AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue])
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: DeliveryMetadata.self) { group in
                group.addTask {
                    let video = try await asset.loadTracks(withMediaType: .video)
                    guard let track = video.first else { return DeliveryMetadata() }
                    let (size, transform) = try await track.load(.naturalSize, .preferredTransform)
                    let dimensions = displayDimensions(size: size, transform: transform)
                    let duration = try? await asset.load(.duration)
                    let audio = try? await asset.loadTracks(withMediaType: .audio)
                    return DeliveryMetadata(width: dimensions?.0, height: dimensions?.1, seconds: duration?.seconds, audio: audio.map { !$0.isEmpty }, readable: true)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 12_000_000_000)
                    asset.cancelLoading()
                    throw DeliveryFailure(message: "Lecture du média trop longue.")
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
        } onCancel: { asset.cancelLoading() }
    }
}

@MainActor final class DeliveryStore: ObservableObject {
    @Published private(set) var plan = DeliveryPlan.empty
    @Published private(set) var folder: URL?
    @Published private(set) var report: DeliveryReport?
    @Published private(set) var running = false
    @Published private(set) var progress = ""
    @Published private(set) var contextTitle = "Ma livraison"
    @Published var issue: String?
    private var contextKey = "general"
    private var plans: [String: DeliveryPlan] = [:]
    private var job: Task<Void, Never>?
    private var revision = UUID()
    private let file: URL
    private let io = DispatchQueue(label: "app.nino.delivery.persistence", qos: .utility)
    private var persistenceAvailable = true
    var engaged: Bool { folder != nil || report != nil || running }
    init(file: URL) {
        self.file = file
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                guard file.standardizedFileURL.path == file.resolvingSymlinksInPath().path else { throw DeliveryFailure(message: "Fichier de critères invalide.") }
                let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 1_000_000 else { throw DeliveryFailure(message: "Fichier de critères trop volumineux.") }
                let decoded = try JSONDecoder().decode([String: DeliveryPlan].self, from: Data(contentsOf: file))
                guard decoded.count <= 100, decoded.keys.allSatisfy({ $0.count <= 100 }), decoded.values.allSatisfy({ $0.requirements.count <= 30 && $0.brief.count <= 6000 && $0.requirements.allSatisfy(\.valid) }) else { throw DeliveryFailure(message: "Format des critères invalide.") }
                plans = decoded
            }
        } catch { issue = "Critères conservés mais non chargés : \(error.localizedDescription)"; persistenceAvailable = false }
    }
    func activate(key: String, title: String) {
        contextTitle = title
        guard key != contextKey else { return }
        cancel(); folder = nil; report = nil; contextKey = key
        plan = plans[key] ?? .empty
    }
    func update(_ value: DeliveryPlan) {
        guard !running, value.requirements.count <= 30, value.brief.count <= 6000 else { return }
        plan = value; report = nil
        guard persistenceAvailable else { return }
        plans[contextKey] = value
        guard plans.count <= 100, let data = try? JSONEncoder().encode(plans), data.count <= 1_000_000 else { issue = "Limite de stockage des critères atteinte."; return }
        let file = file
        io.async { [weak self] in
            do {
                let parent = file.deletingLastPathComponent()
                guard parent.standardizedFileURL.path == parent.resolvingSymlinksInPath().path, file.standardizedFileURL.path == file.resolvingSymlinksInPath().path else { throw DeliveryFailure(message: "Lien symbolique refusé pour les critères.") }
                guard FileManager.default.fileExists(atPath: parent.deletingLastPathComponent().path) else { throw DeliveryFailure(message: "Disque de Nino indisponible.") }
                if !FileManager.default.fileExists(atPath: parent.path) {
                    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                }
                try data.write(to: file, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            } catch { Task { @MainActor in self?.issue = "Enregistrement des critères impossible : \(error.localizedDescription)" } }
        }
    }
    func select(folder: URL) {
        cancel(); report = nil
        do { try DeliveryInspector.safeFolder(folder); self.folder = folder; issue = nil }
        catch { self.folder = nil; issue = error.localizedDescription }
    }
    func cancel() { revision = UUID(); job?.cancel(); job = nil; running = false; progress = "" }
    func run() {
        guard !running, let folder, plan.valid else { issue = "Vérifie les noms exacts, les valeurs positives et les doublons, puis choisis un dossier."; return }
        cancel(); report = nil; issue = nil; running = true
        let token = revision, rules = plan.requirements
        job = Task { [weak self] in
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            do {
                try DeliveryInspector.safeFolder(folder)
                var files: [DeliveryFileResult] = []
                for (index, rule) in rules.enumerated() {
                    try Task.checkCancellation()
                    guard let self, self.revision == token else { return }
                    self.progress = "\(index + 1) / \(rules.count) · \(rule.name)"
                    files.append(try await DeliveryInspector.inspect(folder: folder, rule: rule))
                }
                try Task.checkCancellation()
                guard let self, self.revision == token else { return }
                self.report = DeliveryReport(date: Date(), files: files); self.running = false; self.job = nil; self.progress = ""
            } catch {
                guard let self, self.revision == token else { return }
                self.running = false; self.job = nil
                if !(error is CancellationError) { self.issue = error.localizedDescription }
            }
        }
    }
}
