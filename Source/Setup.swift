import SwiftUI
import AVFoundation
import CoreGraphics
import UniformTypeIdentifiers

@MainActor final class SetupModel: ObservableObject {
    @Published var codex = "Non vérifié"
    @Published var claude = "Non vérifié"
    @Published var checking: String?
    @Published var message: String?
    @Published var copyingModel = false
    func verify(_ provider: String) async {
        guard checking == nil else { return }
        checking=provider; defer { checking=nil }
        do {
            let count = try await Task.detached(priority:.userInitiated) {
                if provider == "codex" { return try DashboardReader.codex().0.windows.count }
                return try DashboardReader.claude().windows.count
            }.value
            let result = count > 0 ? "Connexion vérifiée · limites accessibles" : "Connecté · aucune limite retournée"
            if provider == "codex" { codex=result } else { claude=result }
        } catch {
            if provider == "codex" { codex=error.localizedDescription } else { claude=error.localizedDescription }
        }
    }
    func connect(_ provider: String) {
        guard let executable=DashboardReader.executable(provider) else {
            message="Installe d’abord l’outil officiel, puis reviens vérifier la connexion."
            openGuide(provider); return
        }
        // Only a known executable and fixed arguments; no credentials or user text in the script.
        let quoted="'" + executable.replacingOccurrences(of:"'",with:"'\\''") + "'"
        let command=provider == "codex" ? "login" : "auth login"
        let script="#!/bin/zsh\nexport PATH=\"$HOME/.local/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin\"\n\(quoted) \(command)\nprint '\nReviens dans Nino puis clique Vérifier. Tu peux fermer cette fenêtre.'\n"
        do {
            let folder=FileManager.default.temporaryDirectory.appendingPathComponent("nino-login-"+UUID().uuidString,isDirectory:true)
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let url=folder.appendingPathComponent("Connexion-\(provider).command")
            try script.write(to:url,atomically:true,encoding:.utf8)
            try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:url.path)
            NSWorkspace.shared.open([url],withApplicationAt:URL(fileURLWithPath:"/System/Applications/Utilities/Terminal.app"),configuration:NSWorkspace.OpenConfiguration()) { _, error in
                if let error { Task { @MainActor in self.message=error.localizedDescription } }
            }
            message="La connexion se termine dans l’outil officiel et ton navigateur. Nino ne reçoit pas ton mot de passe. Reviens ensuite cliquer Vérifier."
        } catch { message=error.localizedDescription }
    }
    func openGuide(_ provider: String) {
        let link=provider == "codex" ? "https://learn.chatgpt.com/docs/auth" : "https://code.claude.com/docs/en/setup"
        if let url=URL(string:link) { NSWorkspace.shared.open(url) }
    }
    func chooseModel(_ store: NinoStore) {
        guard !copyingModel, !store.modelDownload.running, store.canCapture else { return }
        let panel=NSOpenPanel();panel.title="Choisir un modèle Whisper GGML";panel.allowedContentTypes=[UTType(filenameExtension:"bin") ?? .data];panel.canChooseDirectories=false
        guard panel.runModal() == .OK, let source=panel.url else { return }
        let destination=store.root.appendingPathComponent("Models").appendingPathComponent(source.lastPathComponent)
        copyingModel=true; store.copying=true
        Task {
            defer { copyingModel=false; store.copying=false }
            do {
                let props=try source.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
                guard props.isRegularFile == true, props.isSymbolicLink != true else { throw NinoError("Choisis un fichier modèle ordinaire.") }
                guard destination.resolvingSymlinksInPath().path.hasPrefix(store.root.resolvingSymlinksInPath().path + "/") else { throw NinoError("Le modèle doit rester dans le dossier Nino.") }
                if source.standardizedFileURL != destination.standardizedFileURL {
                    try await Task.detached(priority:.userInitiated) {
                        _ = try NinoPaths.prepareModelFolder(root: destination.deletingLastPathComponent().deletingLastPathComponent())
                        try FileManager.default.copyItem(at:source,to:destination)
                    }.value
                }
                store.model=source.lastPathComponent;store.saveSettings();message="Modèle ajouté. La transcription est prête si les moteurs audio sont installés."
            } catch { message=error.localizedDescription }
        }
    }
}

struct SetupConnectionsView: View {
    @ObservedObject var setup: SetupModel
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            connector("Codex / ChatGPT", "Quotas d’abonnement et chats enregistrés sur ce Mac.", "codex",setup.codex)
            connector("Claude / Claude Code", "Quotas de ton abonnement, via le connecteur local CodexBar.", "claude",setup.claude)
            Text("Pas de compte Nino à créer. Ces connexions sont facultatives. Une session déjà présente peut être vérifiée ; Se connecter ouvre la connexion officielle dans Terminal puis le navigateur.").font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if let message=setup.message { Text(message).font(.system(size:12)).foregroundStyle(ninoAccent).fixedSize(horizontal:false,vertical:true) }
        }
    }
    func connector(_ title:String,_ detail:String,_ provider:String,_ status:String)->some View {
        VStack(alignment:.leading,spacing:10) {
            Text(title).font(.system(size:17,weight:.semibold))
            Text(detail).font(.system(size:12)).foregroundStyle(.secondary)
            Label(setup.checking == provider ? "Vérification…" : status,systemImage:status.hasPrefix("Connexion vérifiée") ? "checkmark.circle" : "link").font(.system(size:11)).foregroundStyle(ninoAccent).fixedSize(horizontal:false,vertical:true)
            HStack {
                Button("Se connecter") { setup.connect(provider) }.buttonStyle(NinoPrimaryStyle())
                Button("Vérifier") { Task { await setup.verify(provider) } }.disabled(setup.checking != nil)
                Button("Installation") { setup.openGuide(provider) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:14))
    }
}

struct SetupCapabilitiesView: View {
    var showModel = true
    @ObservedObject var setup: SetupModel
    @ObservedObject var store: NinoStore
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            if store.libraryLoading { capability("Bibliothèque", "L’accès au dossier Documents attend une confirmation macOS.") { Button("Choisir le dossier…") { store.requestLibraryAccess() }.disabled(store.libraryAccessRequested) } }
            if showModel { ModelPreparationView(store: store, download: store.modelDownload) }
            DisclosureGroup("J’ai déjà un modèle Whisper .bin") {
                Button(setup.copyingModel ? "Copie…" : "Choisir un modèle…") { setup.chooseModel(store) }.disabled(setup.copyingModel || store.modelDownload.running)
            }.font(.caption)
            VoicePermissionsView()
            Text("Tu peux tout passer : le minuteur, les documents et le prompteur manuel restent accessibles. Rien ne s’enregistre sans une action de ta part.").font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if let message=setup.message { Text(message).font(.caption).foregroundStyle(ninoAccent) }
        }
    }
    func capability<Content:View>(_ title:String,_ detail:String,@ViewBuilder action:()->Content)->some View {
        VStack(alignment:.leading,spacing:7) { Text(title).font(.system(size:14,weight:.semibold));Text(detail).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true);action().font(.system(size:12)) }.frame(maxWidth:.infinity,alignment:.leading)
            .padding(.bottom,8)
    }
}
struct SetupPage: View {
    @ObservedObject var store:NinoStore
    @StateObject private var setup=SetupModel()
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:24) {
            Text("Connexions et préparation").font(.system(size:30,weight:.semibold))
            SetupCapabilitiesView(setup:setup,store:store)
            Divider()
            GoogleConnectionsView(account:store.google)
            Divider()
            SetupConnectionsView(setup:setup)
        }.padding(32) }
    }
}

struct VoicePermissionsView: View {
    @ObservedObject private var permissions = VoicePermissions.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Préparer la voix").font(.system(size: 16, weight: .semibold))
            Text("Un parcours pour le micro, la reconnaissance locale et le son des appels. macOS te demande un accord distinct pour chaque accès.").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                permission("Micro", ready: permissions.microphone == .authorized, kind: .microphone)
                permission("Direct", ready: permissions.speech == .authorized, kind: .speech)
                permission("Son du Mac", ready: permissions.screen, kind: .systemAudio)
            }
            if permissions.preparing {
                HStack { ProgressView().controlSize(.small); Text(permissions.phase ?? "Préparation…"); Spacer(); Button("Annuler") { permissions.cancelPendingRequest() } }.font(.caption)
            } else {
                HStack {
                    Button("Préparer les accès audio") { Task { await permissions.prepareVoice() } }.buttonStyle(.borderedProminent).tint(ninoAccent)
                    Button("Actualiser") { permissions.refresh() }.buttonStyle(.plain)
                }.font(.caption)
            }
            if let message = permissions.message { Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            Text("Aucun enregistrement ici. Tu peux passer cette étape ; documents, minuteur et lecture manuelle restent disponibles.").font(.caption).foregroundStyle(.secondary)
        }.padding(16).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
            .onAppear { permissions.refresh() }
    }
    private func permission(_ title: String, ready: Bool, kind: VoicePermissions.Kind) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: ready ? "checkmark.circle.fill" : "circle").foregroundStyle(ready ? ninoAccent : Color.secondary)
            Text(permissionStatus(kind, ready: ready)).font(.caption2).foregroundStyle(.secondary)
            if !ready { Button("Réglages") { permissions.openSettings(for: kind) }.buttonStyle(.plain).foregroundStyle(ninoAccent) }
        }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func permissionStatus(_ kind: VoicePermissions.Kind, ready: Bool) -> String {
        if ready { return "Autorisé" }
        switch kind {
        case .microphone:
            switch permissions.microphone { case .denied: return "Refusé"; case .restricted: return "Restreint par macOS"; default: return "À demander" }
        case .speech:
            switch permissions.speech { case .denied: return "Refusé"; case .restricted: return "Restreint par macOS"; default: return "À demander" }
        case .systemAudio: return "À autoriser dans macOS"
        }
    }

}
