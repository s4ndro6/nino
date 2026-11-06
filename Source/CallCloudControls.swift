import SwiftUI

struct CallCloudControls: View {
    @ObservedObject var assistant: CallAssistant
    @ObservedObject var settings: IntelligenceSettings
    var openConnections: () -> Void
    @NinoState private var pendingRoute: CallCloudRoute?
    @NinoState private var pendingSession = UUID()
    @NinoState private var confirming = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(assistant.engineTitle, systemImage: assistant.cloudRoute == nil ? "desktopcomputer" : "cloud")
                    .font(.system(size: 13, weight: .semibold)).lineLimit(2)
                Spacer()
                if assistant.cloudRoute != nil {
                    Button("Revenir en local") { assistant.disableCloud() }
                } else if settings.provider != .apple && !settings.model.isEmpty {
                    Button("Utiliser le cloud pour cet appel…") {
                        pendingRoute = CallCloudRoute(provider: settings.provider, model: settings.model)
                        pendingSession = assistant.sessionID
                        confirming = true
                    }.disabled(!assistant.canUseCloud)
                } else {
                    Button("Configurer une IA cloud") { openConnections() }
                }
            }
            Text(assistant.cloudRoute == nil
                 ? "Questions détectées → contexte de l’appel → proposition dans l’encoche. Aucun nouvel extrait envoyé à OpenAI ou Claude."
                 : "\(assistant.cloudRequests)/20 demandes cloud pour cet appel · extraits de transcription transmis au fournisseur · facturation API. Tout échec de génération automatique met les suggestions en pause.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Mémoire : \(assistant.memoryPassages) passages en mémoire sur ce Mac. Nino sélectionne les passages liés à la question et les paroles récentes ; cette sélection n’est pas exhaustive.\(assistant.memoryDiscarded > 0 ? " Les passages les plus anciens ont été retirés à la limite de mémoire." : "") Nouvelle mémoire à chaque appel.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !assistant.sessionActive && settings.provider != .apple {
                Text("Démarre l’appel, puis active le cloud si nécessaire. Apple Intelligence reste le choix par défaut.").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(14).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: assistant.sessionActive) { _, _ in confirming = false; pendingRoute = nil }
        .alert("Envoyer du texte de cet appel ?", isPresented: $confirming) {
            Button("Annuler", role: .cancel) { pendingRoute = nil }
            Button("Activer pour cet appel") {
                if let route = pendingRoute, route.provider == settings.provider, route.model == settings.model {
                    _ = assistant.authorizeCloud(route, sessionID: pendingSession)
                }
                pendingRoute = nil
            }
        } message: {
            Text("\(pendingRoute?.title ?? "Fournisseur cloud") recevra tes questions, ton contexte et des passages anciens/récents de la transcription. L’audio n’est pas envoyé. Jusqu’à 20 demandes facturées par l’API ; ton abonnement ChatGPT/Claude ne finance pas ces appels API. L’accord expire à l’arrêt de l’appel. Les réponses restent des brouillons à vérifier.")
        }
    }
}
