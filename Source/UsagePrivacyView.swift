import SwiftUI

struct UsagePrivacyView: View {
    @ObservedObject var analytics: UsageAnalytics
    @NinoState private var details = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.raised.fill").font(.system(size: 22)).foregroundStyle(ninoAccent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Aider Nino à s’améliorer").font(.system(size: 18, weight: .semibold))
                    Text("Facultatif. Ton choix ne change aucune fonctionnalité.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Avec ton accord, Nino compte les fonctions utilisées chaque jour : import, transcription, notes, minuteur… Aucun contenu, nom, adresse mail, fichier, audio ou conversation n’est collecté.")
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            if !analytics.hasEndpoint {
                Label("Préparation locale · aucun serveur configuré · aucun envoi", systemImage: "internaldrive").font(.caption).foregroundStyle(ninoAccent)
            }
            if let host = analytics.endpoint?.host {
                Label("Destinataire : \(host)", systemImage: "network").font(.caption).foregroundStyle(.secondary)
            }
            if analytics.consent == .undecided {
                HStack(spacing: 12) {
                    Button("Oui, conserver les compteurs") { analytics.setConsent(.accepted) }.buttonStyle(.bordered)
                    Button("Non merci") { analytics.setConsent(.declined) }.buttonStyle(.bordered)
                }.font(.caption)
            } else {
                Label(analytics.consent == .accepted ? "Compteurs autorisés sur ce Mac" : "Compteurs désactivés", systemImage: analytics.consent == .accepted ? "checkmark.circle" : "hand.raised").font(.caption)
                HStack(spacing: 12) {
                    if analytics.consent == .accepted {
                        Button("Retirer mon accord") { analytics.setConsent(.declined) }.buttonStyle(.bordered)
                        Button("Effacer les compteurs locaux") { analytics.purgePending() }.buttonStyle(.bordered)
                    } else {
                        Button("Autoriser les compteurs") { analytics.setConsent(.accepted) }.buttonStyle(.bordered)
                    }
                }.font(.caption)
            }
            if analytics.consent == .accepted {
                HStack {
                    Text("\(analytics.pendingEventCount) utilisations comptées localement").font(.caption).monospacedDigit()
                    Spacer()
                    if analytics.hasEndpoint {
                        Button(analytics.isUploading ? "Envoi…" : "Envoyer ce lot") { Task { await analytics.uploadPending() } }
                            .disabled(analytics.isUploading || analytics.pendingEventCount == 0).font(.caption)
                    }
                }
                Text("Aucun envoi automatique. Tu peux retirer ton accord à tout moment.").font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Quelles données, et pourquoi ?", isExpanded: $details) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Objectif : savoir quelles fonctions méritent d’être améliorées, en comptant des utilisations, jamais des personnes uniques.")
                    Text("Un lot contient seulement le jour UTC, le type d’action, la version majeure de Nino, un compteur, la version de cet accord et son jour. Un identifiant aléatoire par lot empêche de compter deux fois une nouvelle tentative. Aucun identifiant permanent de ton Mac ou de ton compte.")
                    Text("Les compteurs en attente sont purgés après 30 jours au prochain lancement ou à la prochaine utilisation de Nino. Si l’app est fermée, aucun nettoyage ne tourne en arrière-plan. Le serveur local de démonstration purge les agrégats et les identifiants de lots après 90 jours, une fois par jour tant qu’il fonctionne, ou au redémarrage. Si des données ont déjà été reçues, leur agrégation sans identité ne permet pas de retrouver et retirer ta contribution individuellement.")
                    Text("Retirer l’accord arrête la collecte, annule l’envoi en cours et efface la file locale. Un lot déjà parti peut néanmoins avoir été reçu. Ce choix est distinct des conditions d’utilisation et des permissions du micro.")
                }.font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            }.font(.caption)
            if let status = analytics.status { Text(status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }.padding(20).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }
}
