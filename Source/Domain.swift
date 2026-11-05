import Foundation

struct Segment: Codable, Identifiable, Equatable {
    var id = UUID()
    var start: Double
    var end: Double
    var text: String
    var speaker: String = ""
}
struct AudioSource: Codable, Identifiable {
    var id = UUID()
    var filename: String
    var label: String
    var offset: Double = 0
}
struct Document: Codable, Identifiable {
    var id = UUID()
    var title: String
    var created = Date()
    var sources: [AudioSource] = []
    var segments: [Segment] = []
    var notes = ""
    var summary = ""
    var status = "Prêt"
    var language = "fr"
    var error: String? = nil
    var transcript: String { segments.map { ($0.speaker.isEmpty ? "" : "\($0.speaker) : ") + $0.text }.joined(separator: "\n") }
}
struct NinoError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
enum ExportFormat: String, CaseIterable { case txt, md, srt, vtt }
enum TranscriptExport {
    static func stamp(_ seconds: Double, separator: String = ",") -> String {
        let value = seconds.isFinite ? max(0, Int((min(seconds, 2_592_000) * 1000).rounded())) : 0
        return String(format: "%02d:%02d:%02d%@%03d", value / 3_600_000, value / 60_000 % 60, value / 1000 % 60, separator, value % 1000)
    }
    static func render(_ doc: Document, as format: ExportFormat) -> String {
        let segments = doc.segments.sorted { $0.start < $1.start }
        switch format {
        case .txt: return doc.transcript
        case .md: return "# \(doc.title)\n\n" + (doc.summary.isEmpty ? "" : "## Résumé\n\n\(doc.summary)\n\n") + segments.map { "**\(stamp($0.start))\($0.speaker.isEmpty ? "" : " · " + $0.speaker)**\n\n\($0.text)" }.joined(separator: "\n\n") + (doc.notes.isEmpty ? "" : "\n\n## Notes\n\n\(doc.notes)")
        case .srt, .vtt:
            let separator = format == .vtt ? "." : ","
            return (format == .vtt ? "WEBVTT\n\n" : "") + segments.enumerated().map { index, line in
                let text = line.text.replacingOccurrences(of: "\r", with: "").components(separatedBy: .newlines).filter { !$0.isEmpty }.joined(separator: "\n")
                return "\(index + 1)\n\(stamp(line.start, separator: separator)) --> \(stamp(max(line.start + 0.01, line.end), separator: separator))\n\(line.speaker.isEmpty ? "" : "[\(line.speaker)] ")\(text)\n"
            }.joined(separator: "\n")
        }
    }
}
enum WhisperJSON {
    static func parse(_ data: Data, speaker: String = "", offset: Double = 0) throws -> [Segment] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let rows = root["transcription"] as? [[String: Any]] else { throw NinoError("Le moteur a renvoyé une transcription illisible.") }
        return try rows.compactMap { row in
            guard let text = row["text"] as? String, let times = row["offsets"] as? [String: Any], let start = times["from"] as? Double, let end = times["to"] as? Double, start.isFinite, end.isFinite, start >= 0, end >= start, end <= 2_592_000_000, offset.isFinite, offset >= 0, offset <= 2_592_000 else { throw NinoError("Horodatages invalides dans la transcription.") }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : Segment(start: offset + start / 1000, end: offset + end / 1000, text: clean, speaker: speaker)
        }
    }
}
struct LibraryRepository {
    let root: URL
    var documents: URL { root.appendingPathComponent("Documents", isDirectory: true) }
    func checkMounted() throws {
        guard FileManager.default.fileExists(atPath: root.path) else { throw NinoError("Le disque Nino n’est pas disponible. Reconnecte le disque contenant Nino.") }
    }
    func folder(_ id: UUID) -> URL { documents.appendingPathComponent(id.uuidString, isDirectory: true) }
    func save(_ doc: Document) throws {
        try checkMounted()
        let path = folder(doc.id)
        if FileManager.default.fileExists(atPath: path.path) {
            guard try path.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw NinoError("Dossier document invalide : lien symbolique.") }
        }
        guard documents.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { throw NinoError("Le dossier Documents doit rester dans Nino.") }
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(doc)
        try data.write(to: path.appendingPathComponent("document.json"), options: .atomic)
    }
    func load(onIssue: (String) -> Void = { _ in }) throws -> [Document] {
        try checkMounted()
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        return try FileManager.default.contentsOfDirectory(atPath: documents.path).filter { UUID(uuidString: $0) != nil }.compactMap { name in
            let directory = documents.appendingPathComponent(name, isDirectory: true)
            let path = directory.appendingPathComponent("document.json")
            guard FileManager.default.fileExists(atPath: path.path) else { return nil }
            do {
                guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw NinoError("Lien symbolique refusé dans la bibliothèque.") }
                let values = try path.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
                guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 20_000_000 else { throw NinoError("Document trop volumineux ou lien symbolique.") }
                let doc = try JSONDecoder().decode(Document.self, from: Data(contentsOf: path))
                guard doc.id.uuidString == directory.lastPathComponent,
                      doc.segments.allSatisfy({ $0.start.isFinite && $0.end.isFinite && $0.start >= 0 && $0.end >= $0.start && $0.end <= 2_592_000 }),
                      doc.sources.allSatisfy({ $0.offset.isFinite && $0.offset >= 0 && $0.offset <= 2_592_000 }) else { throw NinoError("Identité ou horodatages du document invalides.") }
                return doc
            }
            catch { onIssue("Document illisible ignoré : \(directory.lastPathComponent). Les fichiers audio sont conservés. \(error.localizedDescription)"); return nil }
        }.sorted { $0.created > $1.created }
    }
    func sourceURL(_ source: AudioSource, in doc: Document) throws -> URL {
        guard source.filename == URL(fileURLWithPath: source.filename).lastPathComponent, !source.filename.contains("..") else { throw NinoError("Nom de source audio invalide.") }
        let url = folder(doc.id).appendingPathComponent(source.filename)
        if FileManager.default.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  url.resolvingSymlinksInPath().path.hasPrefix(folder(doc.id).resolvingSymlinksInPath().path + "/") else { throw NinoError("Source audio non régulière ou lien symbolique.") }
        }
        return url
    }
}
