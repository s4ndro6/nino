import SwiftUI
import AppKit

struct AppUpdatesSettings: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Version installée", value: AppUpdates.installedVersion + " · alpha")
            LabeledContent("Édition", value: Bundle.main.object(forInfoDictionaryKey: "NinoPreviewSession") as? Bool == true ? "Découverte personnelle" : "Nino")
            Button("Afficher l’app ouverte dans le Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
            Toggle("Me prévenir des nouvelles versions", isOn: Binding(get: { updates.automatic }, set: { updates.setAutomatic($0) }))
            Text("Avec ton accord, Nino consulte les versions publiques sur GitHub au maximum une fois par jour. GitHub reçoit une requête réseau (dont l’adresse IP), aucun document, audio ou échange. L’installation et le redémarrage demandent toujours ton accord.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(updates.checking ? "Vérification…" : "Vérifier maintenant") { updates.requestCheck(manual: true) }.disabled(updates.checking)
                if updates.latest != nil { Button("Voir la mise à jour") { updates.showDetails = true }.tint(ninoAccent) }
            }
            if updates.installerReady {
                Button("Rechercher et installer…", systemImage: "arrow.triangle.2.circlepath") { updates.installUpdate() }
            }
            if !updates.installerMessage.isEmpty { Text(updates.installerMessage).font(.caption).foregroundStyle(.secondary) }
            Text(updates.message).font(.caption).foregroundStyle(.secondary)
            if let checked = updates.lastCheck { Text("Dernière vérification réussie : \(checked.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary) }
        }.sheet(isPresented: $updates.showDetails) { AppUpdateDetails(updates: updates) }
    }
}
struct AppUpdateDetails: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Label("Une nouvelle version de Nino", systemImage: "sparkles").font(.title2.weight(.semibold)); Spacer(); Button("Fermer") { updates.showDetails = false } }
            if let release = updates.latest {
                Text("\(AppUpdates.installedVersion) → \(release.version.description)").font(.title3.monospacedDigit()).foregroundStyle(ninoAccent)
                ScrollView { Text(verbatim: release.notes).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 240)
                Text(updates.installerReady ? "Nino télécharge la mise à jour et vérifie sa signature avant de proposer le redémarrage. Termine d’abord les travaux en cours. Tes données restent dans leur bibliothèque. macOS peut encore demander une autorisation pour cette alpha non notariée." : "L’installation intégrée n’est pas disponible dans cette édition. Télécharge le DMG, quitte Nino puis remplace l’app dans Applications. Garde ta bibliothèque et tes réglages personnels.").font(.caption).foregroundStyle(.secondary)
                if updates.installerReady {
                    Button("Installer et relancer", systemImage: "arrow.triangle.2.circlepath") { updates.showDetails = false; updates.installUpdate() }.buttonStyle(.borderedProminent).tint(ninoAccent)
                }
                HStack {
                    Button("Téléchargement manuel", systemImage: "arrow.down.circle") { NSWorkspace.shared.open(release.downloadURL) }
                    Button("Plus tard") { updates.later() }
                    Button("Ignorer cette version") { updates.skip() }
                }
                if !updates.installerMessage.isEmpty { Text(updates.installerMessage).font(.caption).foregroundStyle(.secondary) }
                Link("Notes et sommes de contrôle sur GitHub ↗", destination: release.pageURL).font(.caption)
            } else { Text(updates.message).foregroundStyle(.secondary) }
        }.padding(24).frame(width: 590)
    }
}

struct UpdateConsent: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Me prévenir quand Nino évolue", isOn: Binding(get: { updates.automatic }, set: { updates.setAutomatic($0) }))
            Text("Facultatif : une vérification quotidienne sur GitHub, alphas comprises. GitHub reçoit l’adresse IP, aucun contenu personnel de Nino. Tu choisis ensuite de télécharger, reporter ou ignorer la version.").font(.caption).foregroundStyle(.secondary)
        }.padding(16).background(ninoAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
