import Foundation

private func check(_ condition: @autoclosure () throws -> Bool, line: UInt = #line) throws {
    let result = try condition()
    precondition(result, "StickyNotes test line \(line)")
}

@main struct StickyNotesTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/nino-sticky-notes-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Notes/notes.json")
        let repo = StickyNotesRepository(fileURL: file)
        let store = StickyNotesStore(fileURL: file)
        try check(store.ready && store.notes.isEmpty)
        let project = UUID()
        let id = store.create(projectID: project)!
        store.mutate(id) { $0.title = "Livraison"; $0.body = "- [ ] Vérifier le rendu\n- [x] Compiler"; $0.color = .sky; $0.frame = .init(x: 220, y: 80, width: 340, height: 360) }
        store.flush()
        try check(store.issue == nil && !store.saving)
        let loaded = StickyNotesStore(fileURL: file)
        try check(loaded.note(id) == store.note(id))
        try check(loaded.note(id)?.projectID == project)
        try check(loaded.note(id)?.markdown == "# Livraison\n\n- [ ] Vérifier le rendu\n- [x] Compiler\n")
        for index in 0..<12 { store.mutate(id) { $0.body = "Saisie rapide \(index)" } }
        for _ in 0..<200 { if !store.saving { break }; try await Task.sleep(for: .milliseconds(10)) }
        try check(!store.hasUnsavedChanges && store.issue == nil)
        try check((try repo.load()).notes.first?.body == "Saisie rapide 11")
        // A forced close flush supersedes the pending background snapshot.
        store.mutate(id) { $0.body = "Dernière saisie avant fermeture" }; store.flush()
        try check((try repo.load()).notes.first?.body == "Dernière saisie avant fermeture")

        loaded.trash(id); loaded.flush()
        try check(loaded.active.isEmpty && loaded.trash.count == 1 && loaded.note(id)?.visible == false)
        let reopenedTrash = StickyNotesStore(fileURL: file)
        reopenedTrash.restore(id); reopenedTrash.flush()
        try check(reopenedTrash.active.count == 1 && reopenedTrash.trash.isEmpty)
        try check(reopenedTrash.note(id)?.body == loaded.note(id)?.body)
        reopenedTrash.permanentlyDelete(id)
        try check(reopenedTrash.note(id) != nil) // Permanent deletion accepts trashed notes only.
        reopenedTrash.setVisible(id, true); reopenedTrash.hideAll(); reopenedTrash.flush()
        try check(reopenedTrash.note(id)?.visible == false)

        let before = try Data(contentsOf: file)
        var invalid = reopenedTrash.note(id)!
        invalid.body = String(repeating: "x", count: StickyNotesRepository.bodyLimit + 1)
        try check(!reopenedTrash.update(invalid))
        reopenedTrash.flush()
        try check(try Data(contentsOf: file) == before)
        do { try repo.save(StickyNotesDocument(notes: [invalid])); fatalError("Accepted oversized note") } catch {}
        do { try repo.save(StickyNotesDocument(notes: [loaded.note(id)!, loaded.note(id)!])); fatalError("Accepted duplicate IDs") } catch {}
        try check(try Data(contentsOf: file) == before)

        let screen = StickyNoteFrame(x: 0, y: 30, width: 1440, height: 850)
        let offscreen = StickyNoteFrame(x: -4000, y: 2000, width: 1500, height: 1400).clamped(to: [screen])
        try check(offscreen.x >= screen.x && offscreen.y >= screen.y)
        try check(offscreen.x + offscreen.width <= screen.x + screen.width && offscreen.y + offscreen.height <= screen.y + screen.height)
        try check(offscreen.width <= 640 && offscreen.height <= 900)
        let left = StickyNoteFrame(x: -1920, y: 0, width: 1920, height: 1080)
        let onLeft = StickyNoteFrame(x: -600, y: 90, width: 340, height: 360)
        try check(onLeft.clamped(to: [screen, left]) == onLeft)
        let unplugged = onLeft.clamped(to: [screen])
        try check(unplugged.x == 0 && unplugged.y == 90)
        let tiny = StickyNoteFrame(x: 0, y: 0, width: 220, height: 180)
        let clampedTiny = onLeft.clamped(to: [tiny])
        try check(clampedTiny.width == 220 && clampedTiny.height == 180)

        // Startup failure must never replace the original file with an empty collection.
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: file)
        let broken = StickyNotesStore(fileURL: file)
        try check(!broken.ready && broken.issue != nil && broken.create() == nil)
        broken.flush(); try check(try Data(contentsOf: file) == corrupt)
        try before.write(to: file); broken.reload()
        try check(broken.ready && broken.note(id) != nil)

        // A failed disk write retains edits and can be retried after the disk returns.
        let notesFolder = file.deletingLastPathComponent()
        let movedFolder = root.appendingPathComponent("OfflineNotes")
        try FileManager.default.moveItem(at: notesFolder, to: movedFolder)
        try Data("blocked directory".utf8).write(to: notesFolder)
        broken.mutate(id) { $0.body = "Retenu en mémoire" }; broken.flush()
        try check(broken.issue != nil && broken.note(id)?.body == "Retenu en mémoire")
        try FileManager.default.removeItem(at: notesFolder)
        try FileManager.default.moveItem(at: movedFolder, to: notesFolder)
        broken.retrySave()
        try check(broken.issue == nil && (try repo.load()).notes.first?.body == "Retenu en mémoire")

        let target = root.appendingPathComponent("unrelated.txt")
        try Data("untouched".utf8).write(to: target)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
        do { try repo.save(StickyNotesDocument()); fatalError("Accepted symlink") } catch {}
        try check(try String(contentsOf: target, encoding: .utf8) == "untouched")
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: notesFolder)
        let throughAncestor = StickyNotesRepository(fileURL: alias.appendingPathComponent("Nested/notes.json"))
        do { try throughAncestor.save(StickyNotesDocument()); fatalError("Accepted ancestor symlink") } catch {}
        try check(!FileManager.default.fileExists(atPath: notesFolder.appendingPathComponent("Nested").path))
        print("PASS StickyNotes: persistence, debounced autosave/latest edit/flush, project/checklist/Markdown, recoverable trash, limits, duplicate IDs, multi-screen clamp, corrupt file preservation, disk retry, file and ancestor symlink refusal")
    }
}
