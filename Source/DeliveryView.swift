import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension DeliveryVerdict {
    var icon: String { self == .pass ? "checkmark.circle.fill" : self == .fail ? "exclamationmark.circle.fill" : "questionmark.circle" }
    var color: Color { self == .pass ? ninoAccent : self == .fail ? .orange : .secondary }
    var label: String { self == .pass ? "Vérifié" : self == .fail ? "Écart" : "Non vérifié" }
}
@MainActor extension DeliveryStore {
    func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.resolvesAliases = false
        panel.title = "Choisir le dossier des exports"; panel.prompt = "Vérifier ce dossier"
        panel.message = "Nino lit uniquement les fichiers nommés dans tes critères. Aucun fichier n’est modifié."
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            Task { @MainActor in if response == .OK, let url = panel.url { self?.select(folder: url) } }
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.mainWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
    func openFolder() {
        guard let folder else { return }
        do { try DeliveryInspector.safeFolder(folder); NSWorkspace.shared.open(folder) }
        catch { issue = error.localizedDescription }
    }
    func reveal(_ name: String) {
        guard let folder else { return }
        do { NSWorkspace.shared.activateFileViewerSelecting([try DeliveryInspector.safeFile(folder, name: name)]) }
        catch { issue = error.localizedDescription }
    }
    func exportReport() {
        guard let report else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Controle-livraison.md"; panel.allowedContentTypes = [.plainText]
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do { try report.markdown.write(to: url, atomically: true, encoding: .utf8) }
            catch { Task { @MainActor in self?.issue = error.localizedDescription } }
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.mainWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
}

struct DeliveryView: View {
    @ObservedObject var delivery: DeliveryStore
    @NinoState private var editing: DeliveryRequirement?
    @NinoState private var preset: String?
    @NinoState private var dropping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { size in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .center, spacing: 22) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("AVANT L’ENVOI").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(ninoAccent)
                            Text("Prêt à livrer ?").font(.system(size: 32, weight: .semibold, design: .rounded))
                            Text(delivery.contextTitle).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        CompanionView(mood: delivery.running ? .thinking : delivery.report.map { $0.failures == 0 && $0.unknowns == 0 ? .success : .error } ?? .documents).frame(width: 92, height: 85).accessibilityHidden(true)
                    }
                    if let issue = delivery.issue { Label(issue, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
                    folderStrip
                    if size.size.width > 850 {
                        HStack(alignment: .top, spacing: 28) { criteria.frame(width: 315); Divider(); results.frame(maxWidth: .infinity, alignment: .leading) }
                    } else { criteria; Divider(); results }
                }.padding(size.size.width > 850 ? 32 : 24).frame(maxWidth: 1150, alignment: .leading).frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $editing) { rule in
            DeliveryRuleEditor(rule: rule) { updated in
                var plan = delivery.plan
                if let i = plan.requirements.firstIndex(where: { $0.id == updated.id }) { plan.requirements[i] = updated }
                else { plan.requirements.append(updated) }
                delivery.update(plan)
            }
        }
        .confirmationDialog("Remplacer les critères actuels ?", isPresented: Binding(get: { preset != nil }, set: { if !$0 { preset = nil } }), titleVisibility: .visible) {
            Button("Utiliser ce modèle") {
                var plan = preset == "video" ? DeliveryPlan.video : preset == "images" ? .images : .empty
                plan.brief = delivery.plan.brief; delivery.update(plan); preset = nil
            }
            Button("Annuler", role: .cancel) { preset = nil }
        } message: { Text("Les noms et les limites sont des exemples à adapter au brief. Le texte du brief sera conservé.") }
    }
    private var folderStrip: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 14) {
                Image(systemName: "folder.badge.gearshape").font(.system(size: 28, weight: .light)).foregroundStyle(ninoAccent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(delivery.folder?.lastPathComponent ?? "Dépose ton dossier d’exports ici").font(.system(size: 16, weight: .semibold)).lineLimit(2)
                    Text(delivery.folder?.path ?? "Ou choisis-le dans le Finder. Lecture locale uniquement.").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button(delivery.folder == nil ? "Choisir…" : "Changer…") { delivery.chooseFolder() }.disabled(delivery.running)
            }
            HStack {
                if delivery.running {
                    ProgressView().controlSize(.small); Text(delivery.progress).font(.caption).lineLimit(1)
                    Spacer(); Button("Annuler") { delivery.cancel() }
                } else {
                    Button(delivery.report == nil ? "Vérifier ma livraison" : "Relancer le contrôle", systemImage: "checkmark.seal") { delivery.run() }
                        .buttonStyle(NinoPrimaryStyle()).disabled(delivery.folder == nil || !delivery.plan.valid)
                    Spacer()
                    if delivery.folder != nil { Button("Ouvrir le dossier") { delivery.openFolder() }.font(.caption) }
                }
            }
            if !delivery.plan.valid { Text("Ajoute au moins un fichier, sans nom en double. Corrige les critères avant de vérifier.").font(.caption).foregroundStyle(.orange) }
        }.padding(20).background(ninoAccent.opacity(dropping ? 0.16 : 0.055), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ninoAccent.opacity(dropping ? 0.8 : 0.2), style: StrokeStyle(lineWidth: 1, dash: delivery.folder == nil ? [5, 5] : [])))
            .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
                guard !delivery.running, providers.count == 1, let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in Task { @MainActor in if let url, !delivery.running { delivery.select(folder: url) } } }
                return true
            }
    }
    private var criteria: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text("Ce qui est attendu").font(.system(size: 19, weight: .semibold, design: .rounded)); Spacer() }
            Text("Les noms doivent correspondre exactement aux fichiers à la racine du dossier choisi.").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Menu("Partir d’un modèle") {
                Button("Vidéo · horizontal + vertical + SRT") { preset = "video" }
                Button("Visuels · carré + story") { preset = "images" }
                Button("Un fichier libre") { preset = "file" }
            }.disabled(delivery.running)
            DisclosureGroup("Mon brief · référence") {
                TextEditor(text: Binding(get: { delivery.plan.brief }, set: { var plan = delivery.plan; plan.brief = String($0.prefix(6000)); delivery.update(plan) })).font(.system(size: 12)).frame(height: 85).padding(6).background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8)).disabled(delivery.running)
                Text("Recopie ses exigences dans les critères ci-dessous. Ce texte libre n’est pas analysé automatiquement.").font(.system(size: 11)).foregroundStyle(.secondary)
            }.font(.system(size: 12))
            ForEach(delivery.plan.requirements) { rule in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: rule.kind == .video ? "film" : rule.kind == .image ? "photo" : "doc").foregroundStyle(ninoAccent).frame(width: 20).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rule.name).font(.system(size: 13, weight: .medium)).lineLimit(2)
                        Text(summary(rule)).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 14) {
                            Button("Modifier") { editing = rule }
                            Button("Retirer") { var plan = delivery.plan; plan.requirements.removeAll { $0.id == rule.id }; delivery.update(plan) }
                        }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(ninoAccent)
                    }; Spacer(minLength: 0)
                }.padding(.vertical, 9).disabled(delivery.running)
                Divider()
            }
            Button("Ajouter un fichier attendu", systemImage: "plus") { editing = DeliveryRequirement(name: "") }.disabled(delivery.running || delivery.plan.requirements.count >= 30)
        }
    }
    private var results: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let report = delivery.report {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(report.title).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(report.failures > 0 ? .orange : report.unknowns > 0 ? .primary : ninoAccent)
                        Text("\(report.passed) / \(report.files.count) fichiers conformes aux critères saisis").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text(report.date, format: .dateTime.hour().minute().second()).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }; Spacer(minLength: 4)
                    Button { delivery.exportReport() } label: { Image(systemName: "square.and.arrow.up") }.help("Exporter le rapport").accessibilityLabel("Exporter le rapport")
                }
                ForEach(report.files) { file in
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Label(file.name, systemImage: file.verdict.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(file.verdict.color).lineLimit(2)
                            Spacer()
                            if file.canReveal { Button { delivery.reveal(file.name) } label: { Image(systemName: "folder") }.buttonStyle(.plain).help("Afficher \(file.name) dans le Finder").accessibilityLabel("Afficher \(file.name) dans le Finder") }
                        }
                        ForEach(file.checks) { check in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: check.verdict.icon).foregroundStyle(check.verdict.color).frame(width: 15).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(check.title) · \(check.verdict.label)").font(.system(size: 12, weight: .medium))
                                    Text(check.detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                                }
                            }
                        }
                    }.padding(.vertical, 6)
                    Divider()
                }
                Text("Instantané : relance après toute modification. Les critères techniques ne valident ni le contenu créatif ni la qualité sonore.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Image(systemName: delivery.running ? "doc.text.magnifyingglass" : "checklist").font(.system(size: 32, weight: .light)).foregroundStyle(ninoAccent).padding(.top, 15)
                Text(delivery.running ? "Je regarde les fichiers." : "Un contrôle, des faits.").font(.system(size: 22, weight: .medium, design: .rounded))
                Text("Dimensions, poids, durée et présence d’une piste audio. Un fichier manquant apparaît comme un écart ; un média illisible reste non vérifié.").font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("Les sous-titres et autres fichiers libres sont contrôlés pour leur présence et leur poids uniquement.").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: delivery.running)
    }
    private func summary(_ r: DeliveryRequirement) -> String {
        var pieces = [r.kind.label]
        if r.kind != .file { pieces.append("\(r.width == 0 ? "libre" : String(r.width)) × \(r.height == 0 ? "libre" : String(r.height)) px") }
        if r.maxSeconds > 0 && r.kind == .video { pieces.append("≤ \(r.maxSeconds.formatted()) s") }
        if r.maxMB > 0 { pieces.append("≤ \(r.maxMB.formatted()) Mo") }
        if r.needsAudio && r.kind == .video { pieces.append("avec piste audio") }
        if r.kind == .file { pieces.append("présence et poids") }
        return pieces.joined(separator: " · ")
    }
}

private struct DeliveryRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @NinoState private var rule: DeliveryRequirement
    @NinoState private var width: String
    @NinoState private var height: String
    @NinoState private var seconds: String
    @NinoState private var megabytes: String
    let save: (DeliveryRequirement) -> Void
    init(rule: DeliveryRequirement, save: @escaping (DeliveryRequirement) -> Void) {
        _rule = NinoState(initialValue: rule); _width = NinoState(initialValue: String(rule.width)); _height = NinoState(initialValue: String(rule.height))
        _seconds = NinoState(initialValue: String(rule.maxSeconds)); _megabytes = NinoState(initialValue: String(rule.maxMB)); self.save = save
    }
    private var candidate: DeliveryRequirement? {
        guard let w = Int(width), let h = Int(height), let s = Double(seconds.replacingOccurrences(of: ",", with: ".")), let mb = Double(megabytes.replacingOccurrences(of: ",", with: ".")) else { return nil }
        var result = rule; result.width = rule.kind == .file ? 0 : w; result.height = rule.kind == .file ? 0 : h
        result.maxSeconds = rule.kind == .video ? s : 0; result.maxMB = mb; result.needsAudio = rule.kind == .video && rule.needsAudio
        return result.valid ? result : nil
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Un fichier attendu").font(.system(size: 24, weight: .semibold, design: .rounded))
            Form {
                TextField("Nom exact, extension comprise", text: $rule.name)
                Picker("Type de contrôle", selection: $rule.kind) { ForEach(DeliveryKind.allCases) { Text($0.label).tag($0) } }
                if rule.kind != .file { TextField("Largeur (px)", text: $width); TextField("Hauteur (px)", text: $height) }
                if rule.kind == .video { TextField("Durée maximale (s)", text: $seconds); Toggle("Une piste audio est requise", isOn: $rule.needsAudio) }
                TextField("Poids maximal (Mo)", text: $megabytes)
            }.textFieldStyle(.roundedBorder)
            Text("0 = aucune limite. 1 Mo = 1 000 000 octets. Un fichier doit être à la racine du dossier, sans sous-chemin ni lien symbolique.").font(.caption).foregroundStyle(.secondary)
            if candidate == nil { Text("Vérifie le nom et les valeurs numériques (positives ou nulles).").font(.caption).foregroundStyle(.orange) }
            HStack { Button("Annuler") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Enregistrer le critère") { if let candidate { save(candidate); dismiss() } }.buttonStyle(NinoPrimaryStyle()).disabled(candidate == nil).keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 480)
    }
}

struct DeliveryNotch: View {
    @ObservedObject var delivery: DeliveryStore
    var configure: () -> Void
    var tools: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                CompanionView(mood: delivery.running ? .thinking : delivery.report.map { $0.failures == 0 && $0.unknowns == 0 ? .success : .error } ?? .documents).frame(width: 76, height: 70).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(delivery.running ? "Je vérifie ta livraison" : delivery.report?.title ?? "Prêt à livrer ?").font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(delivery.contextTitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if delivery.running { ProgressView().controlSize(.small); Text(delivery.progress).font(.caption).lineLimit(1) }
            else if let report = delivery.report {
                let checks = report.files.flatMap { file in file.checks.filter { $0.verdict != .pass }.map { (file.name, $0) } }
                if checks.isEmpty { Label("\(report.passed) fichiers contrôlés", systemImage: "checkmark.seal").foregroundStyle(ninoAccent) }
                else {
                    ForEach(Array(checks.prefix(2).enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: item.1.verdict.icon).foregroundStyle(item.1.verdict.color)
                            VStack(alignment: .leading, spacing: 4) { Text(item.0).font(.system(size: 12, weight: .medium)).lineLimit(1); Text(item.1.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2) }
                        }
                    }
                }
                Text("Instantané à \(report.date.formatted(date: .omitted, time: .shortened)) · relancer après modification").font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text(delivery.folder == nil ? "Choisis les fichiers attendus et le dossier d’exports. Nino te montre les écarts avant l’envoi." : "\(delivery.plan.requirements.count) fichiers attendus dans \(delivery.folder!.lastPathComponent).").font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(3)
            }
            if let issue = delivery.issue { Text(issue).font(.system(size: 11)).foregroundStyle(.orange).lineLimit(2) }
            Spacer(minLength: 0)
            HStack {
                Button(delivery.report == nil ? "Préparer le contrôle" : "Voir les écarts") { configure() }.buttonStyle(NinoPrimaryStyle())
                if delivery.running { Button("Annuler") { delivery.cancel() } }
                else if delivery.folder != nil { Button("Vérifier") { delivery.run() }.disabled(!delivery.plan.valid) }
                Spacer(minLength: 0)
                Button { delivery.openFolder() } label: { Image(systemName: "folder") }.disabled(delivery.folder == nil).help("Ouvrir le dossier").accessibilityLabel("Ouvrir le dossier")
            }.font(.system(size: 12))
            HStack { Label("Contrôle local", systemImage: "lock.shield").foregroundStyle(.secondary); Spacer(); Button("Tous les outils") { tools() }.buttonStyle(.plain).foregroundStyle(ninoAccent) }.font(.system(size: 11))
        }.padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 18).frame(height: 390)
    }
}
