import Foundation

/// Public and personal builds must never replace one another: their data and account identities differ.
enum NativeUpdatePolicy {
    static let feed = "https://nino-companion.vercel.app/appcast.xml"
    static func configurationIssue(_ info: [String: Any], hasPrivateConfiguration: Bool = false) -> String? {
        guard !hasPrivateConfiguration, info["NinoPublicDistribution"] as? Bool == true,
              info["CFBundleIdentifier"] as? String == "app.sandro.nino",
              info["NinoPreviewSession"] as? Bool != true,
              info["NinoPortableStorage"] as? Bool != true else {
            return "Cette édition personnelle conserve sa bibliothèque et ses connexions. Elle ne peut pas être remplacée par la version publique automatiquement."
        }
        guard let key = info["SUPublicEDKey"] as? String,
              let decoded = Data(base64Encoded: key), decoded.count == 32,
              decoded.contains(where: { $0 != 0 }),
              info["SUFeedURL"] as? String == feed,
              info["SUVerifyUpdateBeforeExtraction"] as? Bool == true,
              info["SUAllowsAutomaticUpdates"] as? Bool == false else {
            return "L’installation intégrée attend la configuration de signature par l’éditeur. Le téléchargement manuel reste disponible."
        }
        return nil
    }

    struct Work {
        var recording = false
        var starting = false
        var stopping = false
        var transcribing = false
        var importing = false
        var summarizing = false
        var generating = false
        var checkingDelivery = false
        var connecting = false
        var savingWorkspace = false
        var unsavedNotes = false

        var reason: String? {
            if recording || starting || stopping { return "Termine l’enregistrement avant de relancer Nino." }
            if transcribing || importing { return "Attends la fin de l’import ou de la transcription avant de relancer Nino." }
            if summarizing || generating { return "Attends la réponse de l’assistant avant de relancer Nino." }
            if checkingDelivery { return "Attends la fin de la vérification des fichiers avant de relancer Nino." }
            if connecting { return "Termine la connexion en cours avant de relancer Nino." }
            if savingWorkspace || unsavedNotes { return "Attends la sauvegarde des changements avant de relancer Nino." }
            return nil
        }
    }
}
