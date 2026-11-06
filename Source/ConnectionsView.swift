import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ConnectionsView: View {
    @ObservedObject var store: NinoStore
    @StateObject private var setup = SetupModel()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("CONNEXIONS").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(ninoAccent)
                    Text("Nino, avec tes outils.").font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.6)
                    Text("Choisis ce que tu relies et ce que tu partages. Chaque accès a une utilité précise.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                ModelPreparationView(store: store, download: store.modelDownload)
                IntelligenceConnectionView(settings: store.agent.settings)
                MCPConnectionView(work: store.work)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Label("Codex et Claude Code", systemImage: "terminal").font(.title3.weight(.semibold))
                    Text("Tes quotas et les conversations enregistrées. Pour les signaux d’avancement, utilise le MCP de Nino ci-dessus.").font(.caption).foregroundStyle(.secondary)
                    SetupConnectionsView(setup: setup)
                }
                Divider()
                GoogleConnectionsView(account: store.google)
                DisclosureGroup("Micro, transcription et stockage") { SetupCapabilitiesView(showModel: false, setup: setup, store: store).padding(.top, 16) }
                Text("Aucun serveur MCP tiers n’est exécuté automatiquement. Nino expose son propre connecteur ; il n’est pas encore un client MCP généraliste.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(30).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

struct MCPConnectionView: View {
    @ObservedObject var work: WorkspaceStore
    @NinoState private var message: String?
    @NinoState private var showContext = false
    @NinoState private var confirmShare = false
    private var executable: String { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/nino-mcp").path }
    private var installed: Bool { FileManager.default.isExecutableFile(atPath: executable) }
    private var config: String {
        let object: [String: Any] = ["mcpServers": ["nino": ["command": executable, "args": ["--workspace", work.repository.directory.path]]]]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted").font(.system(size: 26)).foregroundStyle(ninoAccent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nino devient ton connecteur MCP").font(.system(size: 19, weight: .semibold, design: .rounded))
                    Text("Ton agent retrouve ton travail et te signale son avancement.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Label(work.saving ? "Mise à jour du partage…" : work.issue != nil ? "État du partage non confirmé" : work.sharing ? "Partage activé pour cette session" : "Partage désactivé", systemImage: work.sharing ? "checkmark.shield" : "lock")
                .font(.caption).foregroundStyle(work.sharing ? ninoAccent : .secondary)
            if !installed { Text("Le serveur MCP n’est pas inclus dans cette compilation.").font(.caption).foregroundStyle(.orange) }
            if work.current == nil { Text("Crée d’abord une fiche de travail depuis Mon Nino.").font(.caption).foregroundStyle(.secondary) }
            Text("Seule la fiche sélectionnée est partagée : brief, prochaine action, étapes et liens. Les fichiers du dépôt, mails, enregistrements et identifiants restent exclus. L’outil IA connecté peut transmettre ce contexte à son fournisseur.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ViewThatFits {
                HStack(spacing: 12) { shareButton; previewButton }
                VStack(alignment: .leading, spacing: 12) { shareButton; previewButton }
            }
            if showContext, let project = work.current {
                Text(project.contextText).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Brancher un outil IA").font(.system(size: 13, weight: .semibold))
                Text("1. Copie la configuration dans les serveurs MCP de ton outil.\n2. Active le partage de la fiche ici.\n3. Demande-lui de lire ton travail Nino, puis de signaler son avancement.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ViewThatFits {
                    HStack(spacing: 12) { configButton; exportButton }
                    VStack(alignment: .leading, spacing: 12) { configButton; exportButton }
                }
                Text("Le partage s’arrête au changement de travail et à la fermeture de Nino. En cas de crash ou de disque inaccessible, l’accès expire au plus tard après cinq minutes. Un signal « terminé » vient de l’agent : ce n’est pas une validation de livraison.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let message { Text(message).font(.caption).foregroundStyle(ninoAccent) }
            if let issue = work.issue { Text(issue).font(.caption).foregroundStyle(.orange) }
        }.padding(24).background(ninoAccent.opacity(0.045), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(ninoAccent.opacity(0.16)))
        .confirmationDialog("Partager cette fiche avec tes outils MCP ?", isPresented: $confirmShare, titleVisibility: .visible) {
            Button("Activer le partage de cette fiche") { work.setSharing(true) }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Les clients MCP que tu configures pourront lire le brief et les liens, et signaler un état. Vérifie que la fiche ne contient pas de secret. Aucun fichier du dépôt n’est partagé.") }
    }
    private var shareButton: some View {
        Button(work.sharing ? "Arrêter le partage" : "Partager cette fiche…") { if work.sharing { work.setSharing(false) } else { confirmShare = true } }
            .buttonStyle(NinoPrimaryStyle()).disabled(!installed || !work.ready || work.current == nil || work.saving)
    }
    private var previewButton: some View { Button(showContext ? "Masquer le contexte" : "Voir exactement ce qui est partagé") { showContext.toggle() }.buttonStyle(.plain).font(.caption).disabled(work.current == nil) }
    private var configButton: some View { Button("Copier la configuration MCP", systemImage: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(config, forType: .string); message = "Configuration copiée. Ajoute-la dans les réglages MCP de ton outil." }.font(.caption).disabled(!installed) }
    private var exportButton: some View { Button("Exporter…") { export() }.font(.caption).disabled(!installed) }
    private func export() {
        let parent = NSApp.keyWindow
        let panel = NSSavePanel(); panel.nameFieldStringValue = "nino-mcp.json"; panel.allowedContentTypes = [.json]
        let completion: (NSApplication.ModalResponse) -> Void = { response in guard response == .OK, let url = panel.url else { return }; do { try config.write(to: url, atomically: true, encoding: .utf8); message = "Configuration exportée. Aucune configuration d’un autre outil n’a été modifiée." } catch { message = "Export impossible : " + error.localizedDescription } }
        if let parent, !(parent is NSPanel) { panel.beginSheetModal(for: parent, completionHandler: completion) } else { panel.begin(completionHandler: completion) }
    }
}
