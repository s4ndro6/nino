import AppKit
import Sparkle

/// Sparkle owns download, EdDSA validation, replacement and relaunch. Nino owns consent and work guards.
/// Background discovery stays in AppUpdates; this controller only starts from an explicit click.
@MainActor final class NativeUpdates: NSObject, SPUUpdaterDelegate {
    private weak var model: AppUpdates?
    private var controller: SPUStandardUpdaterController?
    private let blockingReason: () -> String?
    private let flushNotes: () -> Void

    init(model: AppUpdates, blockingReason: @escaping () -> String?, flushNotes: @escaping () -> Void) {
        self.model = model
        self.blockingReason = blockingReason
        self.flushNotes = flushNotes
        super.init()
        if let issue = NativeUpdatePolicy.configurationIssue(Bundle.main.infoDictionary ?? [:],
                hasPrivateConfiguration: Bundle.main.url(forResource: "GoogleDesktopOAuth", withExtension: "plist") != nil) {
            model.installerMessage = issue
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        // No timer or background installation here, even if older preferences enabled Sparkle.
        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false
        do {
            try controller.updater.start()
            model.installerReady = true
            model.installerMessage = "Installation intégrée disponible. Nino te demandera de confirmer avant de télécharger et de redémarrer."
            model.installAction = { [weak self] in self?.checkAndInstall() }
        } catch {
            model.installerMessage = "L’installation intégrée ne peut pas démarrer : \(error.localizedDescription)"
        }
    }

    private func checkAndInstall() {
        guard let controller else { return }
        if let issue = blockingReason() { explain(issue); return }
        guard controller.updater.canCheckForUpdates else {
            explain("Une recherche ou une installation est déjà ouverte. Termine-la dans la fenêtre de mise à jour.")
            return
        }
        model?.installerMessage = "Recherche d’une mise à jour à installer…"
        controller.checkForUpdates(nil)
    }

    func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
        flushNotes()
        if let issue = blockingReason() { explain(issue); return false }
        return true
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        model?.installerMessage = "Mise à jour non installée : \(error.localizedDescription)"
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if error == nil { model?.installerMessage = "Recherche terminée. Les mises à jour sont installées uniquement avec ton accord." }
    }

    private func explain(_ message: String) {
        model?.installerMessage = message
        let alert = NSAlert()
        alert.messageText = "Nino reste ouvert"
        alert.informativeText = message
        alert.addButton(withTitle: "Revenir à Nino")
        alert.runModal()
    }
}
