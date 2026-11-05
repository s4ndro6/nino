import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor enum StickyNoteExporter {
    static func export(_ note: StickyNote, completion: @escaping (String?) -> Void) {
        let panel = NSSavePanel()
        panel.title = "Exporter la note en Markdown"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        let clean = note.displayTitle.components(separatedBy: CharacterSet(charactersIn: "/:\n\r")).joined(separator: "-")
        panel.nameFieldStringValue = String(clean.prefix(100)) + ".md"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try note.markdown.write(to: url, atomically: true, encoding: .utf8); completion(nil) }
            catch { completion("Export impossible : \(error.localizedDescription)") }
        }
    }
}

struct StickyNotesView: View {
    @ObservedObject var store: StickyNotesStore
    var projects: [StickyNoteProject] = []
    var createProjectID: UUID? = nil
    var onOpen: (UUID) -> Void
    var onHideAll: () -> Void
    @NinoState private var query = ""
    @NinoState private var showingTrash = false
    @NinoState private var projectFilter: UUID?
    @NinoState private var deleting: StickyNote?
    @NinoState private var exportIssue: String?

    private var results: [StickyNote] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (showingTrash ? store.trash : store.active).filter { note in
            (projectFilter == nil || note.projectID == projectFilter) && (text.isEmpty || note.title.localizedStandardContains(text) || note.body.localizedStandardContains(text))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if let issue = store.issue {
                    HStack { Label(issue, systemImage: "exclamationmark.triangle"); Button("Réessayer") { store.retrySave() } }
                        .font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                if let exportIssue { Text(exportIssue).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
                filters
                if !store.ready {
                    Text("Les notes restent protégées jusqu’à la réouverture du fichier local.").foregroundStyle(.secondary)
                } else if results.isEmpty {
                    ContentUnavailableView(showingTrash ? "La corbeille est vide" : query.isEmpty ? "Garde une idée sous les yeux" : "Aucune note trouvée", systemImage: showingTrash ? "trash" : "note.text", description: Text(showingTrash ? "Une note retirée peut être restaurée ici." : "Une consigne de cours, une checklist de livraison ou ta prochaine action. Tout reste sur ton disque."))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 420), spacing: 22)], spacing: 24) {
                        ForEach(results) { note in card(note) }
                    }
                }
                Text("Les notes flottantes peuvent apparaître dans un partage d’écran. Masque-les avant de partager.").font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 1200, alignment: .leading).frame(maxWidth: .infinity)
        }
        .confirmationDialog("Supprimer définitivement cette note ?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Supprimer définitivement", role: .destructive) { if let deleting { store.permanentlyDelete(deleting.id) }; deleting = nil }
            Button("Annuler", role: .cancel) { deleting = nil }
        } message: { Text("Cette suppression ne pourra pas être annulée. Exporte la note si tu souhaites la garder.") }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("À PORTÉE DE MAIN").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(ninoAccent)
            Text("Une idée. Une petite note.").font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.6)
            Text("Des notes locales, détachables et reliées à tes projets.").font(.system(size: 13)).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { actions; Spacer(); saveState }
                VStack(alignment: .leading, spacing: 12) { actions; saveState }
            }
        }
    }
    private var actions: some View {
        HStack {
            Button { if let id = store.create(projectID: createProjectID) { onOpen(id) } } label: { Label("Nouvelle note", systemImage: "plus") }
                .buttonStyle(.borderedProminent).tint(ninoAccent).disabled(!store.ready)
            Button(action: onHideAll) { Label("Tout masquer", systemImage: "eye.slash") }.help("Masquer les notes flottantes, sans les supprimer")
        }
    }
    private var saveState: some View {
        Label(store.saving ? "Sauvegarde…" : store.issue == nil ? "Sur ton disque" : "À vérifier", systemImage: store.saving ? "arrow.triangle.2.circlepath" : store.issue == nil ? "internaldrive" : "exclamationmark.circle")
            .font(.caption).foregroundStyle(.secondary).accessibilityLabel(store.saving ? "Sauvegarde en cours" : store.issue == nil ? "Notes sauvegardées localement" : "Sauvegarde à vérifier")
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Chercher dans les notes", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("Rechercher une note")
            HStack {
                Picker("Emplacement", selection: $showingTrash) { Text("Notes (\(store.active.count))").tag(false); Text("Corbeille (\(store.trash.count))").tag(true) }.pickerStyle(.segmented).frame(maxWidth: 320)
                if !projects.isEmpty {
                    Picker("Projet", selection: $projectFilter) {
                        Text("Tous les projets").tag(UUID?.none)
                        ForEach(projects) { Text($0.title).tag(Optional($0.id)) }
                    }.labelsHidden().frame(maxWidth: 220).accessibilityLabel("Filtrer par projet")
                }
            }
        }
    }
    private func card(_ note: StickyNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(note.displayTitle).font(.system(size: 18, weight: .semibold, design: .rounded)).tracking(-0.3).lineLimit(2)
                Spacer()
                if note.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(note.color.tint).accessibilityLabel("Épinglée au premier plan") }
            }
            Text(note.body.isEmpty ? "Une note prête pour ta prochaine idée." : note.body).font(.system(size: 13)).lineSpacing(4).foregroundStyle(note.color.secondaryInk).lineLimit(5).frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            if let id = note.projectID { Label(projects.first(where: { $0.id == id })?.title ?? "Projet archivé", systemImage: "folder").font(.caption2).foregroundStyle(note.color.tint).lineLimit(1) }
            Rectangle().fill(note.color.tint.opacity(0.18)).frame(height: 0.7)
            HStack {
                if showingTrash {
                    Button("Restaurer") { store.restore(note.id) }
                    Spacer()
                    Button { deleting = note } label: { Image(systemName: "trash") }.accessibilityLabel("Supprimer définitivement \(note.displayTitle)").help("Supprimer définitivement")
                } else {
                    Button("Ouvrir") { onOpen(note.id) }
                    Spacer()
                    Button { store.trash(note.id) } label: { Image(systemName: "trash") }.accessibilityLabel("Mettre \(note.displayTitle) à la corbeille").help("Mettre à la corbeille")
                }
                Button { StickyNoteExporter.export(note) { exportIssue = $0 } } label: { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Exporter \(note.displayTitle) en Markdown").help("Exporter en Markdown")
            }.buttonStyle(.borderless).font(.system(size: 11, weight: .medium))
        }.padding(.horizontal, 22).padding(.top, 37).padding(.bottom, 21)
            .foregroundStyle(note.color.ink).tint(note.color.tint)
            .environment(\.colorScheme, .light)
            .background(StickyPaperSurface(color: note.color))
            .overlay(alignment: .top) { StickyPaperTape().padding(.top, 5) }
            .shadow(color: .black.opacity(0.13), radius: 2, x: 0, y: 2)
            .shadow(color: .black.opacity(0.12), radius: 9, x: 1, y: 7)
    }
}

/// The same editor is hosted by each detached panel. All bindings edit the latest stored value.
struct StickyNoteEditor: View {
    @ObservedObject var store: StickyNotesStore
    let id: UUID
    var projects: [StickyNoteProject] = []
    @NinoState private var checklistMode = false
    @NinoState private var exportIssue: String?
    private var note: StickyNote? { store.note(id) }
    private func binding<T>(_ path: WritableKeyPath<StickyNote, T>, fallback: T) -> Binding<T> {
        Binding(get: { note?[keyPath: path] ?? fallback }, set: { value in store.mutate(id) { $0[keyPath: path] = value } })
    }
    var body: some View {
        if let note {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    StickyPaperDragHandle().frame(maxWidth: .infinity, minHeight: 17, maxHeight: 17)
                    Button { store.setVisible(id, false); store.flush() } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 24, height: 24).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(note.color.secondaryInk)
                        .accessibilityLabel("Fermer la note sans la supprimer").help("Fermer la note · ⌘W").keyboardShortcut("w", modifiers: .command)
                }.overlay { StickyPaperTape().offset(y: -2) }
                HStack(spacing: 10) {
                    TextField("Titre", text: Binding(get: { self.note?.title ?? "" }, set: { value in store.mutate(id) { $0.title = String(value.prefix(StickyNotesRepository.titleLimit)) } }))
                        .font(.system(size: 18, weight: .semibold, design: .rounded)).textFieldStyle(.plain).accessibilityLabel("Titre de la note")
                    Button { store.setCollapsed(id, !note.collapsed) } label: { Image(systemName: note.collapsed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right").frame(width: 24, height: 24).contentShape(Rectangle()) }
                        .accessibilityLabel(note.collapsed ? "Déplier la note" : "Replier la note").help(note.collapsed ? "Déplier" : "Replier")
                    Menu {
                        Toggle("Toujours au premier plan", isOn: binding(\.pinned, fallback: true))
                        Picker("Couleur", selection: binding(\.color, fallback: .sand)) { ForEach(StickyNoteColor.allCases) { Text($0.title).tag($0) } }
                        if !projects.isEmpty {
                            Picker("Projet", selection: binding(\.projectID, fallback: nil)) {
                                Text("Sans projet").tag(UUID?.none)
                                ForEach(projects) { Text($0.title).tag(Optional($0.id)) }
                            }
                        }
                        Button("Exporter en Markdown") { StickyNoteExporter.export(note) { exportIssue = $0 } }
                        Divider()
                        Button("Masquer cette note") { store.setVisible(id, false); store.flush() }
                        Button("Mettre à la corbeille", role: .destructive) { store.trash(id); store.flush() }
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24, height: 24).accessibilityLabel("Options de la note")
                }.buttonStyle(.plain)
                if !note.collapsed {
                    if let projectID = note.projectID { Label(projects.first(where: { $0.id == projectID })?.title ?? "Projet lié", systemImage: "folder").font(.caption2).foregroundStyle(note.color.tint).lineLimit(1) }
                    HStack {
                        Button { checklistMode.toggle() } label: {
                            Label(checklistMode ? "Modifier" : "Checklist", systemImage: checklistMode ? "pencil" : "checklist")
                                .font(.system(size: 11, weight: .medium))
                        }.help(checklistMode ? "Revenir au texte" : "Cocher les étapes de la note")
                        Button { store.mutate(id) { value in if value.body.count + 7 <= StickyNotesRepository.bodyLimit { value.body += value.body.isEmpty ? "- [ ] " : "\n- [ ] " } } } label: { Label("Étape", systemImage: "plus") }.font(.caption).help("Insérer une case à cocher Markdown")
                        Spacer()
                    }.buttonStyle(.plain).foregroundStyle(note.color.tint)
                    if checklistMode {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(note.body.components(separatedBy: "\n").enumerated()), id: \.offset) { line in
                                    if line.element.hasPrefix("- [ ] ") || line.element.hasPrefix("- [x] ") || line.element.hasPrefix("- [X] ") {
                                        Toggle(String(line.element.dropFirst(6)), isOn: Binding(get: { line.element.lowercased().hasPrefix("- [x] ") }, set: { checked in
                                            store.mutate(id) { value in
                                                var lines = value.body.components(separatedBy: "\n")
                                                guard lines.indices.contains(line.offset) else { return }
                                                lines[line.offset] = (checked ? "- [x] " : "- [ ] ") + String(lines[line.offset].dropFirst(6)); value.body = lines.joined(separator: "\n")
                                            }
                                        })).toggleStyle(.checkbox)
                                    } else { Text(line.element.isEmpty ? " " : line.element).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                                }
                            }.font(.system(size: 14)).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }
                    } else {
                        TextEditor(text: Binding(get: { self.note?.body ?? "" }, set: { value in store.mutate(id) { $0.body = String(value.prefix(StickyNotesRepository.bodyLimit)) } }))
                            .font(.system(size: 14)).lineSpacing(4).foregroundStyle(note.color.ink).scrollContentBackground(.hidden).accessibilityLabel("Texte de la note, Markdown et cases à cocher acceptés")
                    }
                    HStack {
                        Text(store.saving ? "Sauvegarde…" : store.issue == nil ? "Enregistrée" : "Non sauvegardée")
                        Spacer()
                        Text("\(note.body.count)/\(StickyNotesRepository.bodyLimit)")
                    }.font(.system(size: 10)).foregroundStyle(note.color.secondaryInk)
                }
                if let issue = store.issue ?? exportIssue {
                    HStack { Text(issue).lineLimit(note.collapsed ? 1 : 3); Button("Réessayer") { store.retrySave() } }.font(.caption2).foregroundStyle(Color(red: 0.56, green: 0.15, blue: 0.08))
                }
            }.padding(.horizontal, 18).padding(.top, 9).padding(.bottom, note.collapsed ? 10 : 19)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .foregroundStyle(note.color.ink)
                .background(StickyPaperSurface(color: note.color, folded: !note.collapsed))
                .preferredColorScheme(.light)
                .tint(note.color.tint)
                .ignoresSafeArea()
        }
    }
}
