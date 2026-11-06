import Foundation
import CryptoKit
import Combine

struct LocalWhisperModel: Identifiable, Sendable {
    let id: String
    let title: String
    let bytes: Int64
    let sha256: String
    var filename: String { "ggml-\(id).bin" }
    var url: URL { URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/\(filename)")! }
    static let base = LocalWhisperModel(id: "base", title: "Équilibré · 148 Mo", bytes: 147951465, sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")
    static let tiny = LocalWhisperModel(id: "tiny", title: "Léger · 78 Mo", bytes: 77691713, sha256: "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21")
    static let choices = [base, tiny]

    func verify(_ url: URL, checkCancellation: () throws -> Void = {}) throws {
        let properties = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true,
              Int64(properties.fileSize ?? 0) == bytes else { throw NinoError("Le modèle reçu est incomplet. Réessaie le téléchargement.") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while true {
            try checkCancellation()
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hash.update(data: chunk)
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else { throw NinoError("L’empreinte du modèle ne correspond pas. Aucun modèle n’a été installé.") }
    }
}

private final class ModelDownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let maximum: Int64
    let report: @Sendable (Double) -> Void
    init(maximum: Int64, report: @escaping @Sendable (Double) -> Void) { self.maximum = maximum; self.report = report }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesWritten <= maximum, totalBytesExpectedToWrite <= maximum else { downloadTask.cancel(); return }
        report(min(1, Double(totalBytesWritten) / Double(maximum)))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" ? request : nil)
    }
}

@MainActor final class TranscriptionModelDownload: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var progress = 0.0
    @Published private(set) var message: String?
    private var task: Task<Void, Never>?
    func cancel() { task?.cancel() }
    func start(_ model: LocalWhisperModel, root: URL, completed: @escaping (String) -> Void) {
        guard !running else { return }
        running = true; progress = 0; message = "Téléchargement depuis Hugging Face…"
        task = Task {
            defer { running = false; task = nil }
            do {
                let folder = try NinoPaths.prepareModelFolder(root: root)
                let destination = folder.appendingPathComponent(model.filename)
                var existingValid = false
                if FileManager.default.fileExists(atPath: destination.path) {
                    let properties = try destination.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard properties.isRegularFile == true, properties.isSymbolicLink != true else { throw NinoError("Le chemin du modèle doit être un fichier ordinaire, pas un lien.") }
                    do { try await Task.detached(priority: .utility) { try model.verify(destination) }.value; existingValid = true }
                    catch is NinoError { message = "Le modèle existant est incomplet. Téléchargement d’une nouvelle copie…" }
                    try Task.checkCancellation()
                }
                if !existingValid {
                    let capacity = try folder.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity ?? 0
                    guard Int64(capacity) > model.bytes * 2 else { throw NinoError("Libère au moins \(model.bytes * 2 / 1_000_000) Mo sur le disque de Nino, puis réessaie.") }
                    let config = URLSessionConfiguration.ephemeral
                    config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 1800
                    let session = URLSession(configuration: config)
                    defer { session.invalidateAndCancel() }
                    let delegate = ModelDownloadProgress(maximum: model.bytes) { [weak self] value in
                        Task { @MainActor in self?.progress = value }
                    }
                    let (temporary, response) = try await session.download(from: model.url, delegate: delegate)
                    defer { try? FileManager.default.removeItem(at: temporary) }
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url?.scheme == "https" else { throw NinoError("Le serveur du modèle n’est pas disponible. Réessaie plus tard.") }
                    message = "Vérification du modèle…"
                    let verification = Task.detached(priority: .utility) { try model.verify(temporary) { try Task.checkCancellation() } }
                    try await withTaskCancellationHandler(operation: { try await verification.value }, onCancel: { verification.cancel() })
                    try Task.checkCancellation()
                    // Recheck the volume after networking; never recreate an unplugged library.
                    _ = try NinoPaths.prepareModelFolder(root: root)
                    let staging = folder.appendingPathComponent(".model-\(UUID().uuidString).partial")
                    defer { try? FileManager.default.removeItem(at: staging) }
                    try FileManager.default.moveItem(at: temporary, to: staging)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: staging.path)
                    try Task.checkCancellation()
                    if FileManager.default.fileExists(atPath: destination.path) {
                        let properties = try destination.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                        guard properties.isRegularFile == true, properties.isSymbolicLink != true else { throw NinoError("Le chemin du modèle a changé pendant le téléchargement.") }
                        let backup = folder.appendingPathComponent(model.filename + ".recovery-" + UUID().uuidString)
                        try FileManager.default.moveItem(at: destination, to: backup)
                        do { try FileManager.default.moveItem(at: staging, to: destination) }
                        catch { try? FileManager.default.moveItem(at: backup, to: destination); throw error }
                    } else { try FileManager.default.moveItem(at: staging, to: destination) }
                }
                completed(model.filename)
                progress = 1; message = "Modèle prêt. Tu peux transcrire hors ligne."
            } catch {
                message = Task.isCancelled || error is CancellationError ? "Téléchargement annulé. L’enregistrement reste disponible." : "Installation impossible : \(error.localizedDescription) Tu peux réessayer ou continuer sans modèle."
            }
        }
    }
}

enum TranscriptionRuntime {
    static var executable: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/whisper-cli") }
    static var ready: Bool { FileManager.default.isExecutableFile(atPath: executable.path) }
    static func modelReady(_ url: URL) -> Bool {
        guard let properties = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              properties.isRegularFile == true, properties.isSymbolicLink != true,
              (properties.fileSize ?? 0) > 1_000_000,
              let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)) == Data([0x6c, 0x6d, 0x67, 0x67])
    }
}
