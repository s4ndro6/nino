import Foundation
import Combine

enum StickyNoteColor: String, Codable, CaseIterable, Identifiable {
    // Existing raw values remain readable by the local persistence format.
    case sand, apricot, rose, sage, sky, lavender
    var id: String { rawValue }
    var title: String {
        switch self { case .sage: return "Menthe"; case .sand: return "Jaune"; case .apricot: return "Abricot"; case .rose: return "Rose"; case .sky: return "Bleu"; case .lavender: return "Lavande" }
    }
}

/// AppKit coordinates, in points. Kept independent of screens for persistence and tests.
struct StickyNoteFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var valid: Bool { [x, y, width, height].allSatisfy(\.isFinite) && width > 0 && height > 0 && abs(x) < 1_000_000 && abs(y) < 1_000_000 && width < 100_000 && height < 100_000 }

    func clamped(to screens: [StickyNoteFrame]) -> StickyNoteFrame {
        let candidates = screens.filter(\.valid)
        guard valid, !candidates.isEmpty else { return self }
        func intersection(_ screen: StickyNoteFrame) -> Double {
            max(0, min(x + width, screen.x + screen.width) - max(x, screen.x)) * max(0, min(y + height, screen.y + screen.height) - max(y, screen.y))
        }
        // Use the screen containing most of the note, or the closest screen when unplugged.
        let screen = candidates.max {
            let a = intersection($0), b = intersection($1)
            if a != b { return a < b }
            func distance(_ s: StickyNoteFrame) -> Double { pow(x + width / 2 - s.x - s.width / 2, 2) + pow(y + height / 2 - s.y - s.height / 2, 2) }
            return distance($0) > distance($1)
        }!
        let w = min(max(280, width), min(640, screen.width))
        let h = min(max(84, height), min(900, screen.height))
        return .init(x: min(max(x, screen.x), screen.x + screen.width - w), y: min(max(y, screen.y), screen.y + screen.height - h), width: w, height: h)
    }
}

struct StickyNote: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = "Nouvelle note"
    var body = ""
    var projectID: UUID?
    var color: StickyNoteColor = .sand
    var pinned = true
    var collapsed = false
    var visible = true
    var frame: StickyNoteFrame?
    var createdAt = Date()
    var updatedAt = Date()
    var trashedAt: Date?
    var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sans titre" : title }
    var markdown: String { "# \(displayTitle.replacingOccurrences(of: "\n", with: " "))\n\n\(body)\n" }
}

struct StickyNoteProject: Identifiable {
    let id: UUID
    let title: String
}

struct StickyNotesDocument: Codable {
    var schemaVersion = 1
    var notes: [StickyNote] = []
}

struct StickyNotesFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct StickyNotesRepository {
    let fileURL: URL
    static let noteLimit = 200
    static let titleLimit = 160
    static let bodyLimit = 20_000
    static let byteLimit = 8_000_000

    private func checkLocation(create: Bool) throws {
        let fm = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        guard fileURL.isFileURL else {
            throw StickyNotesFailure("Le dossier des notes et ses parents ne doivent pas être des liens symboliques.")
        }
        // Inspect every ancestor without URL.standardizedFileURL, which can rewrite
        // the legitimate /private/tmp path to the /tmp symlink on macOS.
        var ancestor = directory
        while ancestor.path != "/" {
            if let attributes = try? fm.attributesOfItem(atPath: ancestor.path), attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw StickyNotesFailure("Un dossier parent des notes est un lien symbolique.")
            }
            let parent = ancestor.deletingLastPathComponent()
            guard parent.path != ancestor.path else { break }
            ancestor = parent
        }
        if !fm.fileExists(atPath: directory.path) {
            guard create, fm.fileExists(atPath: directory.deletingLastPathComponent().path) else { throw StickyNotesFailure("Le disque des notes est indisponible. Rebranche-le puis réessaie.") }
            try fm.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        let folder = try fm.attributesOfItem(atPath: directory.path)
        guard folder[.type] as? FileAttributeType == .typeDirectory else { throw StickyNotesFailure("Le dossier des notes n’est pas un dossier local valide.") }
        // FileManager attributes use lstat; URL resource values may be cached or resolve a link.
        if let attributes = try? fm.attributesOfItem(atPath: fileURL.path), attributes[.type] as? FileAttributeType != .typeRegular {
            throw StickyNotesFailure("Le fichier des notes doit être un fichier local ordinaire.")
        }
    }

    func validate(_ document: StickyNotesDocument) throws {
        guard document.schemaVersion == 1, document.notes.count <= Self.noteLimit,
              Set(document.notes.map(\.id)).count == document.notes.count,
              document.notes.allSatisfy({ $0.title.count <= Self.titleLimit && $0.body.count <= Self.bodyLimit && ($0.frame?.valid ?? true) }) else {
            throw StickyNotesFailure("Format des notes invalide ou limite dépassée (200 notes, titres de 160 caractères, textes de 20 000 caractères).")
        }
    }

    func load() throws -> StickyNotesDocument {
        try checkLocation(create: true)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return StickyNotesDocument() }
        let size = (try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size <= Self.byteLimit else { throw StickyNotesFailure("Le fichier des notes est trop volumineux. Il a été conservé sans modification.") }
        let data = try Data(contentsOf: fileURL)
        guard data.count <= Self.byteLimit else { throw StickyNotesFailure("Le fichier des notes dépasse la limite de lecture.") }
        let document = try JSONDecoder().decode(StickyNotesDocument.self, from: data)
        try validate(document)
        return document
    }

    func save(_ document: StickyNotesDocument) throws {
        try validate(document)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(document)
        guard data.count <= Self.byteLimit else { throw StickyNotesFailure("Les notes dépassent 8 Mo. Exporte puis retire des notes avant de réessayer.") }
        try checkLocation(create: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

@MainActor final class StickyNotesStore: ObservableObject {
    /// Optional, content-free product event. Called only for a new in-memory creation.
    var onCreated: (() -> Void)?
    @Published private(set) var notes: [StickyNote] = []
    @Published private(set) var issue: String?
    @Published private(set) var ready = false
    @Published private(set) var saving = false
    private let repository: StickyNotesRepository
    private let ioQueue = DispatchQueue(label: "app.nino.sticky-notes.storage", qos: .utility)
    private var pendingSave: Task<Void, Never>?
    private var dirty = false
    private var revision = 0
    private var saveSequence = 0
    var hasUnsavedChanges: Bool { dirty }

    init(fileURL: URL) {
        repository = StickyNotesRepository(fileURL: fileURL)
        reload()
    }
    var active: [StickyNote] { notes.filter { $0.trashedAt == nil }.sorted { $0.updatedAt > $1.updatedAt } }
    var trash: [StickyNote] { notes.filter { $0.trashedAt != nil }.sorted { $0.trashedAt! > $1.trashedAt! } }
    func note(_ id: UUID) -> StickyNote? { notes.first { $0.id == id } }
    func reload() {
        guard !dirty else { retrySave(); return }
        do { notes = try repository.load().notes; ready = true; issue = nil }
        catch { ready = false; issue = "Impossible d’ouvrir les notes. Le fichier d’origine est conservé. \(error.localizedDescription)" }
    }
    @discardableResult func create(projectID: UUID? = nil) -> UUID? {
        guard ready else { return nil }
        guard notes.count < StickyNotesRepository.noteLimit else { issue = "200 notes maximum, corbeille comprise. Exporte puis supprime définitivement une ancienne note."; return nil }
        let value = StickyNote(projectID: projectID)
        notes.append(value); changed(); onCreated?(); return value.id
    }
    @discardableResult func update(_ value: StickyNote) -> Bool {
        guard ready, let index = notes.firstIndex(where: { $0.id == value.id }) else { return false }
        var candidate = value
        candidate.createdAt = notes[index].createdAt
        candidate.updatedAt = Date()
        do { try repository.validate(StickyNotesDocument(notes: [candidate])) }
        catch { issue = error.localizedDescription; return false }
        if value == notes[index] { return true }
        notes[index] = candidate; changed(); return true
    }
    func mutate(_ id: UUID, _ edit: (inout StickyNote) -> Void) {
        guard var value = note(id) else { return }; edit(&value); update(value)
    }
    func trash(_ id: UUID) { mutate(id) { $0.trashedAt = Date(); $0.visible = false } }
    func restore(_ id: UUID) { mutate(id) { $0.trashedAt = nil; $0.visible = false } }
    func permanentlyDelete(_ id: UUID) {
        guard ready, note(id)?.trashedAt != nil else { return }
        notes.removeAll { $0.id == id }; changed()
    }
    func setVisible(_ id: UUID, _ value: Bool) { mutate(id) { $0.visible = value } }
    func setPinned(_ id: UUID, _ value: Bool) { mutate(id) { $0.pinned = value } }
    func setCollapsed(_ id: UUID, _ value: Bool) { mutate(id) { $0.collapsed = value } }
    func setFrame(_ id: UUID, _ value: StickyNoteFrame) { mutate(id) { $0.frame = value } }
    func hideAll() {
        guard ready else { return }
        for index in notes.indices { notes[index].visible = false }
        changed()
    }
    private func changed() {
        revision += 1; dirty = true; saving = true
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            self?.saveInBackground()
        }
    }
    private func saveInBackground() {
        guard ready, dirty else { return }
        pendingSave = nil
        saveSequence += 1
        let sequence = saveSequence, version = revision
        let snapshot = StickyNotesDocument(notes: notes), repository = repository
        ioQueue.async { [weak self] in
            let result = Result { try repository.save(snapshot) }
            Task { @MainActor [weak self] in
                guard let self, self.saveSequence == sequence, self.revision == version else { return }
                switch result {
                case .success: self.dirty = false; self.issue = nil
                case .failure(let error): self.issue = "Notes non sauvegardées : \(error.localizedDescription)"
                }
                self.saving = false
            }
        }
    }
    /// Call before termination or changing the data disk. Failed writes retain all edits in memory.
    func flush() {
        pendingSave?.cancel(); pendingSave = nil
        saveSequence += 1 // Ignore completion of an earlier autosave, even for the same revision.
        guard ready, dirty else { saving = false; return }
        let snapshot = StickyNotesDocument(notes: notes), repository = repository
        do { try ioQueue.sync { try repository.save(snapshot) }; dirty = false; issue = nil }
        catch { issue = "Notes non sauvegardées : \(error.localizedDescription)" }
        saving = false
    }
    func retrySave() { if ready { flush() } else { reload() } }
}
