import AppKit

/// Optional personal MTMR bridge. Exposes generic state only, never audio or chat text.
@MainActor final class TouchBarBridge {
    private weak var store: NinoStore?
    private var timer: Timer?
    private var last = ""
    private var written = Date.distantPast
    private let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/MTMR")
    init(store: NinoStore) {
        self.store = store
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("nino.enabled").path) else { return }
        publish()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { @MainActor in self?.publish() } }
    }
    func publish() {
        guard let store, FileManager.default.fileExists(atPath: folder.appendingPathComponent("nino.enabled").path) else { return }
        let mode: String
        let title: String
        if store.isStarting { mode = "think"; title = "Préparation" }
        else if store.isStopping { mode = "think"; title = "Finalisation" }
        else if store.recordingID != nil { mode = store.documents.first(where: { $0.id == store.recordingID })?.title.hasPrefix("Appel") == true ? "call" : "record"; title = "Enregistrement" }
        else if store.busyID != nil { mode = "transcribe"; title = "Transcription" }
        else if store.summaryBusy || store.assistant.thinking || store.agent.working { mode = "think"; title = "Réflexion locale" }
        else if store.error != nil { mode = "error"; title = "À vérifier" }
        else if store.delivery.running { mode = "think"; title = "Contrôle local" }
        else if store.notice != nil && store.latestTranscript != nil { mode = "ready"; title = "Texte prêt" }
        else if let event = store.work.activity, store.work.sharing, !event.stale {
            switch event.state {
            case "working": mode = "think"; title = "Agent · en cours"
            case "waiting": mode = "idle"; title = "Agent · à toi de jouer"
            case "completed": mode = "ready"; title = "Agent · terminé"
            default: mode = "error"; title = "Agent · à vérifier"
            }
        }
        else if store.timerEnd != nil { mode = "timer"; title = "Concentration" }
        else { mode = "idle"; title = "Nino" }
        let text = title + "\n" + mode + "\n" + (NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? "static" : store.companionEnergy == .calm ? "calm" : "animate")
        guard text != last || Date().timeIntervalSince(written) > 10 else { return }
        do {
            try text.write(to: folder.appendingPathComponent("nino-status.txt"), atomically: true, encoding: .utf8)
            last = text; written = Date()
        } catch { /* Touch Bar failure must never interrupt recording. */ }
    }
    deinit { timer?.invalidate() }
}
