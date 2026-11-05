import SwiftUI
import AppKit

struct AppUpdatesSettings: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Version installée", value: AppUpdates.installedVersion + " · alpha")
            Toggle("Me prévenir des nouvelles versions", isOn: Binding(get: { updates.automatic }, set: { updates.setAutomatic($0) }))
            Text("Avec ton accord, Nino consulte les versions publiques sur GitHub au maximum une fois par jour. GitHub reçoit une requête réseau (dont l’adresse IP), aucun document, audio ou échange. Aucun téléchargement ni remplacement automatique.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(updates.checking ? "Vérification…" : "Vérifier maintenant") { updates.requestCheck(manual: true) }.disabled(updates.checking)
                if updates.latest != nil { Button("Voir la mise à jour") { updates.showDetails = true }.tint(ninoAccent) }
            }
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
                Text("Télécharge le DMG, termine tes enregistrements et tes travaux, quitte Nino puis remplace-le dans Applications. Tes notes restent dans leur bibliothèque, en dehors de l’app. Cette alpha n’est pas notariée par Apple.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Télécharger la mise à jour", systemImage: "arrow.down.circle") { NSWorkspace.shared.open(release.downloadURL) }.buttonStyle(.borderedProminent).tint(ninoAccent)
                    Button("Plus tard") { updates.later() }
                    Button("Ignorer cette version") { updates.skip() }
                }
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
