import SwiftUI
import AppKit

struct WorkspaceView: View {
    @ObservedObject var store: NinoStore
    @ObservedObject var work: WorkspaceStore
    @StateObject private var git = RepositoryConnector()
    @NinoState private var editing: WorkProject?
    @NinoState private var confirmDelete = false
    @NinoState private var chatPreview: WorkChat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var activeProfile: WorkProfile? { work.activeProfileID.flatMap(WorkProfile.init(rawValue:)) }
    private var developmentTools: Bool { activeProfile?.isDevelopment ?? true }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    spaceSelector
                    if let issue = work.issue {
                        HStack(alignment: .top) { Image(systemName: "exclamationmark.circle"); Text(issue).textSelection(.enabled); if work.ready { Button("Réessayer") { work.retrySave() } } }
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !work.ready {
                        if work.issue == nil { HStack { ProgressView(); Text("Ouverture de ton espace de travail…") }.padding(.vertical, 40) }
                    } else if let project = work.current {
                        if geometry.size.width > 780 {
                            HStack(alignment: .top, spacing: 26) { mission(project).frame(maxWidth: .infinity); context(project).frame(width: 264) }
                        } else { mission(project); context(project) }
                    } else { empty; templates }
                    if let project = work.current {
                        HStack {
                            Button("Post-it de ce projet", systemImage: "note.text.badge.plus") {
                                if let id = store.notes.create(projectID: project.id) { store.openStickyNote?(id) }
                            }
                            Button("Tous les post-it") { store.page = "notes" }
                        }
                        WorkEvidenceView(evidence: store.evidence, projectID: project.id, projectTitle: project.title)
                    }
                    quickActions
                }.padding(geometry.size.width > 780 ? 34 : 24).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $chatPreview) { ChatPreview(chat: $0) }
        .sheet(item: $editing) { project in WorkEditor(project: project) { updated in work.upsert(updated) } }
        .confirmationDialog("Supprimer cette fiche de travail ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer la fiche", role: .destructive) { work.removeCurrent() }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Le dépôt, les documents et les conversations restent intacts.") }
        .onChange(of: work.current?.repositoryPath) { _, _ in git.clear() }
        .onChange(of: work.current?.id) { _, _ in git.clear() }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: work.current?.id)
    }
    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(activeProfile?.studioLabel ?? "TES TRAVAUX GÉNÉRAUX").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(ninoAccent)
                Text(work.current == nil ? "Un endroit pour avancer." : "On reprend ici.").font(.system(size: 31, weight: .semibold, design: .rounded)).tracking(-0.7)
                Text(activeProfile?.detail ?? "Tes anciennes fiches sont ici. Tu peux les déplacer vers un métier.").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            CompanionView(mood: work.activity?.state == "working" && work.activity?.stale == false ? .thinking : .idle, energy: store.companionEnergy).frame(width: 78, height: 70).accessibilityHidden(true)
        }
    }
    private var spaceSelector: some View {
        HStack(alignment: .center, spacing: 12) {
            Menu {
                ForEach(WorkProfile.allCases) { profile in Button { store.selectWorkProfile(profile) } label: { Label(profile.title, systemImage: profile.icon) } }
                Divider()
                Button("Général · \(work.generalCount) fiche(s)") { work.activateProfile(nil) }
            } label: { Label(activeProfile?.title ?? "Général", systemImage: activeProfile?.icon ?? "tray.full").font(.system(size: 13, weight: .medium)) }
            .menuStyle(.borderlessButton).fixedSize().disabled(!store.canConfigure)
            Spacer()
            if work.current != nil {
                Menu {
                    Button("Fiche vide") { editing = work.newProject() }
                    if let profile = activeProfile { ForEach(profile.workflows) { template in Button(template.title) { editing = template.project(profile: profile) } } }
                } label: { Label("Nouveau travail", systemImage: "plus").font(.caption) }.menuStyle(.borderlessButton).fixedSize()
            }
        }.padding(.vertical, 3)
    }
    private var templates: some View {
        Group {
            if let profile = activeProfile {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Text("Pars d’un modèle").font(.system(size: 16, weight: .semibold)); Spacer(); Text("À adapter avant de créer").font(.system(size: 10)).foregroundStyle(.secondary) }
                    ForEach(profile.workflows) { template in
                        Button { editing = template.project(profile: profile) } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: profile.icon).font(.system(size: 21, weight: .light)).foregroundStyle(ninoAccent).frame(width: 30)
                                VStack(alignment: .leading, spacing: 6) { Text(template.title).font(.system(size: 15, weight: .medium)); Text(template.detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true); Text(template.software).font(.system(size: 10)).foregroundStyle(ninoAccent.opacity(0.8)) }
                                Spacer(minLength: 4); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }
    private var empty: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus").font(.system(size: 36, weight: .light)).foregroundStyle(ninoAccent)
            Text("Commence par ce qui\nt’occupe aujourd’hui.").font(.system(size: 26, weight: .medium)).tracking(-0.5)
            Text("Un ticket, une vidéo, une idée. Garde son brief, ses liens et ses étapes ensemble. Nino t’aide à retrouver le fil.")
                .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).frame(maxWidth: 470, alignment: .leading)
            Button("Créer une fiche vide", systemImage: "plus") { editing = work.newProject() }.buttonStyle(NinoPrimaryStyle())
            Text("Local, sans compte obligatoire. Les connexions viennent quand tu en as besoin.").font(.caption).foregroundStyle(.secondary)
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading).background(ninoAccent.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
    }
    private func mission(_ project: WorkProject) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Menu {
                    ForEach(work.visibleProjects) { p in Button(p.title) { work.select(p.id) } }
                    Divider(); Button("Nouveau travail…") { editing = work.newProject() }
                } label: { Label("Travail en cours", systemImage: "square.stack.3d.up").font(.caption) }
                .menuStyle(.borderlessButton).fixedSize()
                Spacer()
                Text(work.saving ? "Enregistrement…" : work.issue == nil ? "Enregistré sur ce Mac" : "Non enregistré")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: project.title).font(.system(size: 26, weight: .semibold, design: .rounded)).textSelection(.enabled)
                if !project.brief.isEmpty { Text(verbatim: project.brief).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(5).textSelection(.enabled) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("PROCHAINE ACTION", systemImage: "arrow.turn.down.right").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(ninoAccent)
                Text(verbatim: project.nextAction.isEmpty ? "Précise le premier petit pas dans ta fiche." : project.nextAction).font(.system(size: 16, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(ninoAccent.opacity(0.075), in: RoundedRectangle(cornerRadius: 14))
            ViewThatFits {
                HStack(spacing: 12) { focusButton; assistantButton(project) }
                VStack(alignment: .leading, spacing: 12) { focusButton; assistantButton(project) }
            }
            Divider()
            HStack { Text("Étapes").font(.headline); Spacer(); Text("\(project.completedCount) / \(project.tasks.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            if project.tasks.isEmpty { Text("Ajoute quelques étapes à ta fiche pour suivre ce qui reste à faire.").font(.caption).foregroundStyle(.secondary) }
            ForEach(project.tasks) { task in
                Button { work.toggleStep(task.id) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: task.done ? "checkmark.circle.fill" : "circle").foregroundStyle(task.done ? ninoAccent : .secondary).font(.system(size: 18))
                        Text(verbatim: task.title).strikethrough(task.done).foregroundStyle(task.done ? .secondary : .primary).frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                    }.font(.system(size: 13)).padding(.vertical, 3).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel((task.done ? "Réouvrir : " : "Terminer : ") + task.title)
            }
            HStack {
                Button("Modifier la fiche", systemImage: "pencil") { editing = project }
                Spacer()
                Menu {
                    Button("Copier le contexte") { store.copy(project.contextText) }
                    Button("Exporter le brief…") { exportBrief(project) }
                    Menu("Déplacer vers un autre espace") {
                        ForEach(WorkProfile.allCases) { profile in Button(profile.title) { work.moveCurrent(to: profile.rawValue) }.disabled(profile.rawValue == project.profileID) }
                        Button("Général") { work.moveCurrent(to: nil) }.disabled(project.profileID == nil)
                    }
                    Button("Supprimer la fiche…", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Actions du travail")
            }.font(.caption)
        }.padding(24).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.07)))
    }
    private var focusButton: some View { Button("Me concentrer", systemImage: "timer") { store.openNotchTimer?() }.buttonStyle(NinoPrimaryStyle()) }
    private func assistantButton(_ project: WorkProject) -> some View {
        Button("Préparer la suite", systemImage: "sparkles") {
            guard !store.agent.working else { store.notice = "L’assistant termine sa réponse. Réessaie ensuite."; return }
            store.agent.input = "Aide-moi à avancer : repère les informations manquantes, puis propose trois actions concrètes. Ne consulte pas les liens.\n\n" + String(project.contextText.prefix(10500)); store.page = "agent"
        }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(ninoAccent)
    }
    private func context(_ project: WorkProject) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dans ton contexte").font(.system(size: 16, weight: .semibold))
                if project.links.isEmpty { Text(developmentTools ? "Ton ticket, ton Figma, ta recette : ajoute les liens dans la fiche." : "Références, dossier partagé, lien de visionnage : garde-les dans ta fiche.").font(.caption).foregroundStyle(.secondary) }
                ForEach(project.links) { link in
                    if let url = link.safeURL { Link(destination: url) { HStack { Image(systemName: "arrow.up.right"); VStack(alignment: .leading, spacing: 3) { Text(verbatim: link.label).foregroundStyle(.primary); Text(url.host ?? "").font(.system(size: 10)).foregroundStyle(.secondary) }; Spacer() }.font(.system(size: 12)).padding(.vertical, 3) } }
                }
            }
            Divider()
            if developmentTools {
            VStack(alignment: .leading, spacing: 10) {
                Label("Dépôt local", systemImage: "point.3.connected.trianglepath.dotted").font(.system(size: 13, weight: .semibold))
                if !project.repositoryPath.isEmpty {
                    Text(URL(fileURLWithPath: project.repositoryPath).lastPathComponent).font(.caption).textSelection(.enabled)
                    if let snapshot = git.snapshot {
                        Text(verbatim: snapshot.branch).font(.system(size: 12, design: .monospaced)).foregroundStyle(ninoAccent)
                        Text("\(snapshot.changedFiles) fichier(s) modifié(s)").font(.caption)
                        Text("Relevé à \(snapshot.checkedAt.formatted(date: .omitted, time: .shortened)) · lecture seule").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Button(git.checking ? "Vérification…" : "Vérifier le dépôt") { Task { await git.refresh(path: project.repositoryPath) } }.disabled(git.checking)
                } else { Text("Vérifie la branche et les changements sans quitter Nino.").font(.caption).foregroundStyle(.secondary) }
                if let issue = git.issue { Text(issue).font(.caption).foregroundStyle(.orange) }
                Button(project.repositoryPath.isEmpty ? "Choisir un dépôt…" : "Changer de dépôt…") { chooseRepository() }.buttonStyle(.plain).foregroundStyle(ninoAccent).font(.caption)
                if !project.repositoryPath.isEmpty { Button("Détacher le dépôt") { work.setRepository(""); git.clear() }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary) }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Label("Conversation associée", systemImage: "bubble.left.and.text.bubble.right").font(.system(size: 13, weight: .semibold))
                if let chat = project.chat {
                    Text(verbatim: chat.title).font(.caption).lineLimit(3)
                    Button("Lire les derniers échanges") { chatPreview = WorkChat(id: chat.id, title: chat.title, directory: chat.directory, updated: chat.updated) }.font(.caption)
                }
                Button(project.chat == nil ? "Choisir dans mes chats Codex" : "Changer de conversation") { store.page = "today" }.font(.caption).buttonStyle(.plain).foregroundStyle(ninoAccent)
            }
            } else { creativeTools(project) }
            Divider()
            WorkActivityView(work: work)
            Button("Gérer mes connexions", systemImage: "link") { store.page = "connections" }.font(.caption)
        }.padding(.vertical, 6)
    }
    private func creativeTools(_ project: WorkProject) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(activeProfile?.companionApps ?? "Mes outils", systemImage: activeProfile?.icon ?? "square.grid.2x2").font(.system(size: 13, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            if activeProfile == .editor || activeProfile == .creator {
                Text("Importe un audio ou une vidéo, corrige la transcription et exporte les sous-titres depuis Documents.").font(.caption).foregroundStyle(.secondary)
                Button("Importer un média…", systemImage: "square.and.arrow.down") { store.chooseFiles() }.disabled(!store.canCapture)
                Button("Mes transcriptions · SRT / VTT") { store.page = "library" }
            }
            if activeProfile == .creator { Button("Ouvrir le prompteur") { store.page = "prompter" } }
            if activeProfile == .designer {
                Text("Prépare le brief ici, crée dans ton logiciel, puis suis tes variantes et retours dans cette fiche.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Exporter mon brief…", systemImage: "square.and.arrow.up") { exportBrief(project) }
            Text("Les échanges passent par tes fichiers et tes liens. Nino ne pilote pas Adobe ou DaVinci.").font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.font(.caption)
    }
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("À portée de main").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                if developmentTools { shortcut("Quotas et chats", "gauge.with.dots.needle.33percent", "today") }
                else { shortcut("Assistant de travail", "sparkles", "agent") }
                shortcut("Mes transcriptions", "text.alignleft", "library")
                shortcut("Appel et notes", "waveform", "call")
                shortcut("Personnaliser Nino", "slider.horizontal.3", "settings")
            }
            Text("Les fiches sont séparées par activité. La bibliothèque de médias et les comptes connectés restent communs sur ce Mac.").font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func exportBrief(_ project: WorkProject) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Brief-Nino.md"; panel.title = "Exporter le brief"; panel.canCreateDirectories = true
        let completion: (NSApplication.ModalResponse) -> Void = { result in
            guard result == .OK, let url = panel.url else { return }
            do { try project.markdown.write(to: url, atomically: true, encoding: .utf8) }
            catch { store.error = "Export impossible : \(error.localizedDescription)" }
        }
        if let parent = NSApp.keyWindow, !(parent is NSPanel) { panel.beginSheetModal(for: parent, completionHandler: completion) } else { panel.begin(completionHandler: completion) }
    }
    private func shortcut(_ title: String, _ icon: String, _ page: String) -> some View {
        Button { store.page = page } label: { HStack(spacing: 8) { Image(systemName: icon).foregroundStyle(ninoAccent); Text(title).font(.system(size: 11)); Spacer() }.padding(13).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain)
    }
    private func chooseRepository() {
        let projectID = work.current?.id
        let parent = NSApp.keyWindow
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = "Associer ce dépôt"
        panel.message = "Nino lira uniquement la branche, le nombre de changements et l’identifiant du commit. Aucun fichier source n’est partagé avec le MCP."
        let completion: (NSApplication.ModalResponse) -> Void = { result in Task { @MainActor in
            guard result == .OK, let url = panel.url, work.current?.id == projectID else { return }
            work.setRepository(url.path); git.clear()
        } }
        if let parent, !(parent is NSPanel) { panel.beginSheetModal(for: parent, completionHandler: completion) } else { panel.begin(completionHandler: completion) }
    }
}

struct WorkActivityView: View {
    @ObservedObject var work: WorkspaceStore
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Activité des agents", systemImage: "antenna.radiowaves.left.and.right").font(.system(size: 13, weight: .semibold))
            if let event = work.activity, work.sharing {
                Text(event.label).foregroundStyle(event.stale ? Color.secondary : ninoAccent).font(.headline)
                Text(verbatim: event.message).font(.caption).fixedSize(horizontal: false, vertical: true)
                Text("Signalé par \(event.agent) à \(event.reportedAt.formatted(date: .omitted, time: .shortened))").font(.system(size: 10)).foregroundStyle(.secondary)
                Text("État déclaré par l’agent, à vérifier dans son résultat.").font(.system(size: 10)).foregroundStyle(.secondary)
            } else { Text(work.sharing ? "En attente du premier signal MCP. Le partage seul ne connecte pas un agent." : "Connecte ton outil IA au MCP de Nino pour recevoir ses signaux d’avancement.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

struct WorkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @NinoState var project: WorkProject
    var save: (WorkProject) -> Bool
    @NinoState private var newStep = ""
    @NinoState private var linkLabel = ""
    @NinoState private var linkURL = ""
    @NinoState private var issue: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(project.title.isEmpty ? "Un nouveau travail" : "Ta fiche de travail").font(.system(size: 23, weight: .semibold, design: .rounded)); Spacer(); Button("Annuler") { dismiss() } }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field("Titre", hint: "Ex. Corriger la page Formation", text: $project.title)
                    VStack(alignment: .leading, spacing: 7) { Text("Brief").font(.caption).foregroundStyle(.secondary); TextEditor(text: $project.brief).font(.system(size: 13)).frame(height: 90).padding(8).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel("Brief du travail") }
                    field("Prochaine action", hint: "Le premier petit pas", text: $project.nextAction)
                    Divider()
                    Text("Étapes").font(.headline)
                    ForEach($project.tasks) { $task in HStack { TextField("Étape", text: $task.title); Button { project.tasks.removeAll { $0.id == task.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Retirer l’étape " + task.title) } }
                    HStack { TextField("Ajouter une étape", text: $newStep).onSubmit(addStep); Button("Ajouter", action: addStep).disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || project.tasks.count >= 30) }
                    Divider()
                    Text("Références").font(.headline)
                    ForEach(project.links) { link in HStack { VStack(alignment: .leading) { Text(verbatim: link.label); Text(verbatim: link.url).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Button { project.links.removeAll { $0.id == link.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Retirer " + link.label) } }
                    field("Nom du lien", hint: "Ticket, Figma, recette, conversation…", text: $linkLabel)
                    HStack { TextField("https://…", text: $linkURL).accessibilityLabel("Adresse du lien"); Button("Ajouter le lien", action: addLink).disabled(linkLabel.isEmpty || linkURL.isEmpty || project.links.count >= 12) }
                    if let issue { Text(issue).font(.caption).foregroundStyle(.orange) }
                }.textFieldStyle(.roundedBorder).padding(24)
            }
            Divider()
            HStack { Text("Conservé localement. Partage MCP facultatif.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Enregistrer") { commit() }.buttonStyle(NinoPrimaryStyle()).keyboardShortcut(.defaultAction) }.padding(20)
        }.frame(width: 570, height: 570).preferredColorScheme(.dark)
    }
    private func field(_ label: String, hint: String, text: Binding<String>) -> some View { VStack(alignment: .leading, spacing: 6) { Text(label).font(.caption).foregroundStyle(.secondary); TextField(hint, text: text).accessibilityLabel(label) } }
    private func addStep() { let title = newStep.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty, title.count <= 300, project.tasks.count < 30 else { issue = "Une étape doit contenir entre 1 et 300 caractères."; return }; project.tasks.append(WorkStep(title: title)); newStep = ""; issue = nil }
    private func addLink() { let reference = WorkReference(label: linkLabel.trimmingCharacters(in: .whitespacesAndNewlines), url: linkURL.trimmingCharacters(in: .whitespacesAndNewlines)); guard !reference.label.isEmpty, reference.label.count <= 80, reference.url.count <= 2000, reference.safeURL != nil, project.links.count < 12 else { issue = "Ajoute un nom court et une adresse HTTP(S) sans identifiants."; return }; project.links.append(reference); linkLabel = ""; linkURL = ""; issue = nil }
    private func commit() {
        if !newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { addStep(); if !newStep.isEmpty { return } }
        if !linkLabel.isEmpty || !linkURL.isEmpty { addLink(); if !linkLabel.isEmpty || !linkURL.isEmpty { return } }
        do { _ = try project.validated(); if save(project) { dismiss() } else { issue = "La fiche n’a pas pu être enregistrée." } } catch { issue = error.localizedDescription }
    }
}

struct NotchWorkSummary: View {
    @ObservedObject var work: WorkspaceStore
    var open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: work.activity?.state == "waiting" ? "hand.raised" : "rectangle.stack").foregroundStyle(ninoAccent)
                VStack(alignment: .leading, spacing: 4) { Text(verbatim: work.current?.title ?? "Quel est ton prochain travail ?").font(.system(size: 12, weight: .semibold)).lineLimit(1); Text(verbatim: work.activity?.label ?? work.current?.nextAction ?? "Réunis ton brief, tes liens et tes étapes.").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
                Spacer(); Image(systemName: "arrow.up.right").font(.caption)
            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).help("Ouvrir le travail en cours")
    }
}
