import Foundation

/// Cocoa must receive exactly one answer, and work may start while the external disk is saving.
@MainActor final class TerminationGate {
    enum Decision { case cancel, later }
    private var pending: UUID?
    private var deadline: Task<Void, Never>?

    func request(timeout: UInt64 = 3_000_000_000, flush: @escaping () -> Void,
                 blocker: @escaping () -> String?, revoke: (@escaping @MainActor (Bool) -> Void) -> Void,
                 report: @escaping (String) -> Void, reply: @escaping (Bool) -> Void) -> Decision {
        guard pending == nil else { return .later }
        flush()
        if let issue = blocker() { report(issue); return .cancel }
        let token = UUID()
        pending = token
        let finish: (Bool, String?) -> Void = { [weak self] success, issue in
            guard let self, self.pending == token else { return }
            self.pending = nil; self.deadline?.cancel(); self.deadline = nil
            if let issue { report(issue) }
            reply(success)
        }
        deadline = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: timeout) } catch { return }
            finish(false, "Le disque ne répond pas. Fermeture annulée pour protéger les changements en attente.")
        }
        revoke { success in
            // Always answer after applicationShouldTerminate returned .terminateLater.
            Task { @MainActor in
                guard self.pending == token else { return }
                guard success else {
                    finish(false, "Le disque ne permet pas de confirmer la sauvegarde. Nino reste ouvert.")
                    return
                }
                flush()
                if let issue = blocker() { finish(false, issue) }
                else { finish(true, nil) }
            }
        }
        return .later
    }
}
