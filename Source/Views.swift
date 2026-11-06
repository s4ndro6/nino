import SwiftUI
import AVKit
import UniformTypeIdentifiers

typealias NinoState<Value> = SwiftUI.State<Value>

let ninoAccent = Color(red: 0.48, green: 0.78, blue: 0.64)

struct NinoPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.black.opacity(enabled ? 0.9 : 0.45)).padding(.horizontal, 14).padding(.vertical, 8)
            .background(ninoAccent.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
struct BrandMark: View {
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32).fill(ninoAccent)
            HStack(spacing: size * 0.12) {
                Capsule().fill(Color.black.opacity(0.85)).frame(width: size * 0.09, height: size * 0.28)
                Capsule().fill(Color.black.opacity(0.85)).frame(width: size * 0.09, height: size * 0.18)
            }.rotationEffect(.degrees(-8))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}
struct NinoRootView: View {
    @ObservedObject var store: NinoStore
    var body: some View {
        GeometryReader { geometry in
            Group {
                if store.showOnboarding { OnboardingView(store:store) }
                else {
                    HStack(spacing:0) {
                        if geometry.size.width < 900 { compactSidebar.frame(width:70) }
                        else { ScrollView { sidebar.frame(minHeight:geometry.size.height) }.frame(width:210) }
                        Divider()
                        workspaceContent.frame(maxWidth:.infinity,maxHeight:.infinity)
                    }
                }
            }
            .background(Color(nsColor:.windowBackgroundColor)).tint(ninoAccent).preferredColorScheme(.dark)
            .overlay(alignment:.bottom) {
                if store.libraryLoading && !store.showOnboarding {
                    HStack(spacing:10) { ProgressView().controlSize(.small);Text("Bibliothèque en attente d’accès au disque.").font(.caption);Button("Choisir le dossier…") { store.requestLibraryAccess() }.disabled(store.libraryAccessRequested).font(.caption) }.padding(12).background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)).padding(18)
                } else if let message=store.notice {
                    HStack { Image(systemName:"checkmark.circle.fill").foregroundStyle(ninoAccent);Text(message);Button { store.notice=nil } label: { Image(systemName:"xmark") }.buttonStyle(.plain) }.padding(12).background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)).padding(18)
                }
            }
        }.frame(minWidth:680,minHeight:540)
        .alert("Nino",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error=nil}})) { Button("OK") { store.error=nil } } message: {Text(store.error ?? "")}
    }
    @ViewBuilder var workspaceContent:some View {
        switch store.page {
        case "delivery": DeliveryView(delivery: store.delivery)
        case "privacy": ScrollView { VStack(alignment: .leading, spacing: 24) { Text("Tes données, tes choix.").font(.system(size: 30, weight: .semibold)); UsagePrivacyView(analytics: store.analytics) }.padding(32).frame(maxWidth: 850) }
        case "agent":LocalAgentView(store:store,agent:store.agent)
        case "notes": StickyNotesView(store: store.notes, projects: store.work.state.projects.map { StickyNoteProject(id: $0.id, title: $0.title) }, createProjectID: store.work.current?.id, onOpen: { store.openStickyNote?($0) }, onHideAll: { store.hideStickyNotes?() })
        case "home":WorkspaceView(store:store, work:store.work)
        case "today":TodayView(today:store.today, attention:store.attention) { chat in
            guard var project = store.work.current else { store.notice = "Crée d’abord une fiche depuis Mon Nino."; return }
            project.chat = WorkChatReference(id: chat.id, title: String(chat.title.prefix(500)), directory: chat.directory, updated: chat.updated)
            if store.work.upsert(project) { store.notice = "Conversation associée à ton travail." }
        }
        case "prompter":PrompterSettingsView(store:store)
        case "call":CallPage(store:store,assistant:store.assistant)
        case "timer":TimerPage(store:store)
        case "connections":ConnectionsView(store:store)
        case "settings":SettingsPage(store:store)
        default:library
        }
    }
    var compactSidebar:some View {
        ScrollView {
            VStack(spacing:9) {
                BrandMark(size:28).padding(.vertical,12)
                compactNav("home","Mon Nino","house")
                compactNav("delivery","Vérifier ma livraison","checkmark.seal")
                compactNav("notes","Post-it","note.text")
                compactNav("agent","Assistant","sparkles")
                compactNav("today","Aujourd’hui","sun.max")
                compactNav("library","Documents","doc.text")
                compactNav("timer","Concentration","timer")
                compactNav("call","Appel","phone")
                compactNav("prompter","Prompteur","text.viewfinder")
                Divider().padding(.vertical,6)
                compactNav("connections","Connexions","link")
                compactNav("settings","Réglages","slider.horizontal.3")
                if store.recordingID != nil { Button { Task { await store.stopRecording() } } label: { Image(systemName:"stop.circle.fill").foregroundStyle(.red).font(.system(size:24)) }.buttonStyle(.plain).help(store.stopRecordingLabel).accessibilityLabel(store.stopRecordingLabel).disabled(store.isStopping) }
            }.padding(.horizontal,8)
        }.background(Color.black.opacity(0.17))
    }
    func compactNav(_ id:String,_ title:String,_ icon:String)->some View {
        Button { store.page=id } label: { Image(systemName:icon).font(.system(size:17)).frame(width:44,height:40).foregroundStyle(store.page == id ? ninoAccent : .secondary).background(store.page == id ? ninoAccent.opacity(0.1) : .clear,in:RoundedRectangle(cornerRadius:10)) }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) { BrandMark(); VStack(alignment: .leading, spacing: 1) { Text("nino").font(.system(size: 25, weight: .semibold, design: .rounded)); Text("TON COMPAGNON").font(.system(size: 8, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary) } }.padding(.top, 18)
            VStack(spacing: 5) {
                nav("home", "Mon Nino", "house")
                nav("delivery", "Ma livraison", "checkmark.seal")
                nav("notes", "Post-it", "note.text")
                nav("agent", "Assistant", "sparkles")
                ForEach(store.profile.navigation, id: \.self) { page in
                    switch page {
                    case "today": nav(page, "Aujourd’hui", "sun.max")
                    case "library": nav(page, "Documents", "text.alignleft")
                    case "call": nav(page, "Appel en direct", "phone")
                    case "prompter": nav(page, "Prompteur", "text.viewfinder")
                    default: nav(page, "Concentration", "timer")
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("CAPTURER").font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary)
                captureButton("Enregistrer un appel", icon: "phone.arrow.up.right", call: true)
                captureButton("Note vocale", icon: "mic", call: false)
                captureButton("Dicter du texte", icon: "waveform", call: false, dictation: true)
            }
            if store.isStarting { Button("Annuler le démarrage") { store.cancelRecordingStart() }.font(.caption) }
            if let started = store.recordingStarted {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Circle().fill(.red).frame(width: 6, height: 6); Text("ENREGISTREMENT").font(.system(size: 9, weight: .bold)).tracking(1) }
                    Text(started, style: .timer).font(.system(size: 26, weight: .light, design: .monospaced))
                    Button(store.stopRecordingLabel, systemImage: "stop.fill") { Task { await store.stopRecording() } }.disabled(store.isStopping)
                }.padding(12).background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Label("Stockage local", systemImage: "externaldrive").font(.system(size: 11))
                Text("Audio conservé · traitement local").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            nav("connections", "Connexions", "link")
            nav("settings", "Réglages", "slider.horizontal.3")
        }.padding(18).background(Color.black.opacity(0.17))
    }
    func nav(_ id: String, _ label: String, _ icon: String) -> some View {
        Button { store.page = id } label: {
            HStack(spacing: 10) { Image(systemName: icon).frame(width: 18); Text(label); Spacer() }.font(.system(size: 13, weight: store.page == id ? .semibold : .regular)).padding(.horizontal, 10).padding(.vertical, 10)
                .foregroundStyle(store.page == id ? ninoAccent : .white.opacity(0.65)).background(store.page == id ? ninoAccent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
    func captureButton(_ label: String, icon: String, call: Bool, dictation: Bool = false) -> some View {
        Button { Task { await store.startRecording(call: call, dictation: dictation) } } label: { Label(label, systemImage: icon).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).disabled(!store.canCapture)
    }
    var library: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) { Text("Documents").font(.system(size: 28, weight: .semibold)); Text("Des paroles aux idées claires.").foregroundStyle(.secondary).font(.system(size: 12)) }
                Spacer()
                Button { store.chooseFiles() } label: { Label("Importer un média", systemImage: "plus").padding(.vertical, 5) }.buttonStyle(NinoPrimaryStyle()).foregroundStyle(.black).disabled(store.busyID != nil || store.recordingID != nil)
            }.padding(24)
            if store.busyID != nil {
                HStack { ProgressView().controlSize(.small); Text(store.phase).font(.system(size: 12)); Spacer(); Button("Annuler") { store.runner.cancel() }.disabled(store.copying) }.padding(.horizontal, 24).padding(.bottom, 16)
            }
            Divider()
            if store.documents.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "waveform.path").font(.system(size: 52, weight: .ultraLight)).foregroundStyle(ninoAccent)
                    Text("Une conversation mérite\nde rester.").font(.system(size: 36, weight: .medium)).tracking(-1)
                    Text("Dépose un fichier audio ou vidéo ici.\nNino garde l’original et transforme la parole en texte, sur ton Mac.").foregroundStyle(.secondary).font(.system(size: 14)).lineSpacing(5)
                    Button("Choisir un fichier") { store.chooseFiles() }.buttonStyle(.bordered)
                    Text("MP3 · M4A · WAV · MP4 · MOV").font(.system(size: 10, design: .monospaced)).tracking(1.5).foregroundStyle(.tertiary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                HSplitView {
                    VStack(spacing: 0) {
                        HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Rechercher", text: $store.search).textFieldStyle(.plain) }.padding(14)
                        Divider()
                        List(selection: $store.selected) {
                            ForEach(store.filtered) { doc in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(doc.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                                    Text(doc.created.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(.secondary)
                                    HStack(spacing: 5) { Circle().fill(doc.status == "Prêt" ? ninoAccent : doc.status == "Erreur" ? .orange : .gray).frame(width: 5, height: 5); Text(doc.status).font(.system(size: 10)).foregroundStyle(.secondary) }
                                }.padding(.vertical, 8).tag(doc.id)
                            }
                        }.listStyle(.sidebar)
                    }.frame(minWidth: 210, idealWidth: 240, maxWidth: 300)
                    if let doc = store.active { DocumentView(store: store, id: doc.id).id(doc.id).frame(minWidth: 330) }
                    else { Text("Sélectionne un document").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard store.busyID == nil, store.recordingID == nil, let first = providers.first else { return false }
            _ = first.loadObject(ofClass: URL.self) { url, _ in if let url { Task { @MainActor in await store.importFile(url) } } }
            return true
        }
    }
}

struct DocumentView: View {
    @ObservedObject var store: NinoStore
    let id: UUID
    @NinoState private var tab = "text"
    @StateObject private var playback = AudioPlayback()
    @NinoState private var sourceID: UUID?
    var doc: Document? { store.documents.first { $0.id == id } }
    var body: some View {
        if let doc {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 13) {
                    TextField("Titre", text: Binding(get: { self.doc?.title ?? "" }, set: { value in store.edit(id) { $0.title = value } })).font(.system(size: 23, weight: .semibold)).textFieldStyle(.plain)
                    HStack {
                        Text("\(doc.segments.count) segments").foregroundStyle(.secondary).font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Button { store.copy(doc.transcript) } label: { Image(systemName: "doc.on.doc") }.help("Copier la transcription").disabled(doc.segments.isEmpty)
                        Menu { ForEach(ExportFormat.allCases, id: \.self) { format in Button(format.rawValue.uppercased()) { store.export(id, format: format) } } } label: { Label("Exporter", systemImage: "square.and.arrow.up") }.disabled(doc.segments.isEmpty)
                    }
                    if !doc.sources.isEmpty {
                        HStack(spacing: 10) {
                            Button { playback.toggle() } label: { Label(playback.playing ? "Pause" : "Écouter", systemImage: playback.playing ? "pause.fill" : "play.fill") }.disabled(!playback.ready || store.recordingID == id || store.isStopping)
                            Picker("Piste", selection: Binding(get: { sourceID }, set: { sourceID = $0; loadPlayer() })) { ForEach(doc.sources) { source in Text(source.label.isEmpty ? "Audio original" : source.label).tag(Optional(source.id)) } }.labelsHidden()
                            Button { NSWorkspace.shared.open(store.repository.folder(id)) } label: { Image(systemName: "folder") }.help("Afficher les fichiers conservés")
                            Spacer()
                            Button(!store.transcriptionReady ? "Préparer la transcription" : doc.segments.isEmpty ? "Transcrire" : "Retranscrire") { Task { await store.transcribe(id) } }.disabled(store.busyID != nil || store.recordingID != nil)
                        }
                        if store.recordingID != id && !store.isStopping {
                            HStack {
                                Text(TranscriptExport.stamp(playback.position, separator: ".")).monospacedDigit()
                                Slider(value: Binding(get: { playback.position }, set: { playback.seek($0) }), in: 0...max(1, playback.duration)).disabled(!playback.ready).accessibilityLabel("Position dans l’enregistrement")
                                Text(TranscriptExport.stamp(playback.duration, separator: ".")).monospacedDigit()
                            }.font(.caption)
                            if let error = playback.error { Text(error).font(.caption).foregroundStyle(.orange) }
                        }
                    }
                    if let message = doc.error { Text(message).font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled) }
                    Picker("Contenu", selection: $tab) { Text("Transcription").tag("text"); Text("Notes").tag("notes"); Text("Résumé").tag("summary") }.pickerStyle(.segmented)
                }.padding(22)
                Divider()
                if tab == "text" {
                    if doc.segments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) { Image(systemName: "text.alignleft").font(.largeTitle).foregroundStyle(.secondary); Text(store.recordingID == id ? "À l’écoute…" : store.busyID == id ? "Le texte arrive ici." : "Ce document attend sa transcription.").font(.headline); Text("L’audio original est conservé sur ton disque et peut être écouté sans transcription.").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 22) {
                                ForEach(doc.segments) { segment in
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            Button(TranscriptExport.stamp(segment.start, separator: ".")) { seek(segment) }.font(.system(size: 10, design: .monospaced)).buttonStyle(.plain).foregroundStyle(ninoAccent)
                                            if !segment.speaker.isEmpty { TextField("Intervenant", text: binding(segment.id, \.speaker)).textFieldStyle(.plain).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).frame(maxWidth: 180) }
                                        }
                                        TextField("Texte", text: binding(segment.id, \.text), axis: .vertical).font(.system(size: 14)).lineSpacing(5).textFieldStyle(.plain)
                                    }
                                }
                            }.padding(24)
                        }
                    }
                } else if tab == "notes" {
                    TextEditor(text: Binding(get: { self.doc?.notes ?? "" }, set: { value in store.edit(id) { $0.notes = value } })).font(.system(size: 14)).padding(18).scrollContentBackground(.hidden)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { Text("Apple Intelligence · sur ce Mac").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button(store.summaryBusy ? "Résumé en cours…" : "Générer") { Task { await store.summarize(id) } }.disabled(store.summaryBusy || doc.segments.isEmpty) }
                        Button("Préparer un résumé avec mon IA…") {
                            guard !store.agent.working else { return }
                            store.agent.prepareDraft("Résume cette transcription en français : points clés, décisions, actions explicites et questions ouvertes. N’invente rien.\n\n" + doc.segments.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n"))
                            store.page = "agent"
                        }.disabled(doc.segments.isEmpty || store.agent.working)
                        Text("Le texte est d’abord ouvert dans l’assistant pour relecture. Rien n’est envoyé avant ton clic ; les textes longs doivent être divisés en parties.").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: Binding(get: { self.doc?.summary ?? "" }, set: { value in store.edit(id) { $0.summary = value } })).font(.system(size: 14)).scrollContentBackground(.hidden)
                    }.padding(20)
                }
            }.onAppear { sourceID = doc.sources.first?.id; loadPlayer() }
                .onChange(of: id) { _, _ in sourceID = self.doc?.sources.first?.id; loadPlayer() }
                .onChange(of: doc.sources.map(\.id)) { _, _ in sourceID = doc.sources.first?.id; loadPlayer() }
                .onChange(of: store.recordingID) { _, _ in loadPlayer() }
                .onChange(of: store.isStarting) { _, _ in loadPlayer() }
                .onChange(of: store.isStopping) { _, _ in loadPlayer() }
                .onChange(of: doc.status) { previous, next in if [previous, next].contains("Enregistrement") || [previous, next].contains("Préparation") { loadPlayer() } }
                .onDisappear { playback.pause() }
        }
    }
    func binding(_ segmentID: UUID, _ key: WritableKeyPath<Segment, String>) -> Binding<String> {
        Binding(get: { doc?.segments.first { $0.id == segmentID }?[keyPath: key] ?? "" }, set: { value in store.edit(id) { d in if let i = d.segments.firstIndex(where: { $0.id == segmentID }) { d.segments[i][keyPath: key] = value } } })
    }
    func loadPlayer() {
        guard let doc, store.recordingID != id, !store.isStarting, !store.isStopping,
              doc.status != "Enregistrement", doc.status != "Préparation",
              let source = doc.sources.first(where: { $0.id == sourceID }) ?? doc.sources.first else { playback.load(nil); return }
        do { playback.load(try store.repository.sourceURL(source, in: doc)) }
        catch { playback.load(nil); store.error = error.localizedDescription }
    }
    func seek(_ segment: Segment) {
        guard let doc else { return }
        if let match = doc.sources.first(where: { $0.label == segment.speaker }), sourceID != match.id { sourceID = match.id; loadPlayer() }
        let offset = doc.sources.first(where: { $0.id == sourceID })?.offset ?? 0
        playback.seek(max(0, segment.start - offset), play: true)
    }
}

struct SettingsPage: View {
    @ObservedObject var store: NinoStore
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Réglages").font(.system(size: 30, weight: .semibold))
            Text("Tes fichiers. Ton Mac. Tes choix.").foregroundStyle(.secondary)
            Form {
                Section("Mon Nino") {
                    DisplayChoiceView(store:store)
                    LabeledContent("Profil", value: store.profile.title)
                    Button("Connexions et préparation") { store.page = "connections" }
                    Button("Personnaliser mon Nino") { store.showOnboarding = true }.disabled(!store.canConfigure)
                    Picker("Présence", selection: $store.companionEnergy) {
                        ForEach(CompanionEnergy.allCases) { Text($0.title).tag($0) }
                    }.onChange(of: store.companionEnergy) { _, _ in store.saveSettings() }
                    Text("Le profil organise les raccourcis et propose une durée de concentration et une vitesse de lecture. Aucun service externe n’est connecté automatiquement.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Mises à jour") { AppUpdatesSettings(updates: store.updates) }
                Section("Transcription") {
                    ModelPreparationView(store: store, download: store.modelDownload)
                    Picker("Langue", selection: $store.language) { Text("Français").tag("fr"); Text("Détection automatique").tag("auto"); Text("Anglais").tag("en"); Text("Italien").tag("it"); Text("Espagnol").tag("es") }
                    Picker("Modèle local", selection: $store.model) { Text("Whisper Small · multilingue").tag("ggml-small.bin"); Text("Whisper Base · équilibré").tag("ggml-base.bin"); Text("Whisper Tiny · léger").tag("ggml-tiny.bin"); Text("Whisper Large Turbo · qualité (à fournir)").tag("ggml-large-v3-turbo.bin") }
                    Toggle("Accélération GPU Metal", isOn: $store.useGPU)
                    Label(store.modelReady ? "Modèle disponible" : "Modèle absent du dossier Models", systemImage: store.modelReady ? "checkmark.circle" : "exclamationmark.triangle").foregroundStyle(store.modelReady ? ninoAccent : .orange)
                }
                Section("Stockage") {
                    LabeledContent("Emplacement", value: store.root.path)
                    Text("Originaux et pistes audio conservés. Aucun effacement automatique. N’éjecte pas le disque pendant un enregistrement ou une transcription.").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("Ouvrir le dossier Nino") { NSWorkspace.shared.open(store.root) }
                }
                Section("Confidentialité") {
                    Button("Statistiques d’usage et consentement…") { store.page = "privacy" }
                    Text("Google est facultatif : les jetons sont gérés par le SDK officiel et le Trousseau macOS. Les aperçus Gmail ne se chargent que sur demande et ne sont pas transmis à l’assistant. Aucun compte Nino synchronisé n’est créé.")
                    Text("La transcription utilise Whisper localement. Le résumé optionnel utilise Apple Intelligence s’il est disponible. Les quotas interrogent les services Codex et Claude via leurs outils connectés. Aucun audio n’est envoyé pour ce suivi.")
                    Text("Appels : micro et audio système nécessitent les autorisations macOS. Informe les participants avant d’enregistrer. Les libellés « Moi » et « Appel » désignent les pistes, pas une identification automatique de chaque personne.").foregroundStyle(.secondary)
                }
                Section("Raccourcis") {
                    LabeledContent("Afficher / masquer l’encoche", value: "⌃⌥N")
                    LabeledContent("Importer un média", value: "⌘O")
                    LabeledContent("La dictée", value: "Enregistrer → arrêter → copier le texte")
                }
            }.formStyle(.grouped)
        }.padding(30).onDisappear { store.saveSettings() }
        .onChange(of: store.language) { _, _ in store.saveSettings() }.onChange(of: store.model) { _, _ in store.saveSettings() }.onChange(of: store.useGPU) { _, _ in store.saveSettings() }
    }
}
struct TimerPage: View {
    @ObservedObject var store: NinoStore
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text("Un peu d’espace\npour se concentrer.").font(.system(size: 38, weight: .medium)).tracking(-1)
            Text("Le minuteur reste accessible dans l’encoche.").foregroundStyle(.secondary)
            if let end = store.timerEnd { Text(end, style: .timer).font(.system(size: 76, weight: .ultraLight, design: .monospaced)).foregroundStyle(ninoAccent) }
            else { Text("\(Int(store.timerMinutes)):00").font(.system(size: 76, weight: .ultraLight, design: .monospaced)).foregroundStyle(ninoAccent) }
            HStack { Text("Durée"); Slider(value: $store.timerMinutes, in: 1...90, step: 1).frame(width: 220); Text("\(Int(store.timerMinutes)) min").monospacedDigit() }.disabled(store.timerEnd != nil)
            HStack { Button(store.timerEnd == nil ? "Démarrer" : "Recommencer") { store.startTimer() }.buttonStyle(NinoPrimaryStyle()).foregroundStyle(.black); if store.timerEnd != nil { Button("Arrêter") { store.stopTimer() } } }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(35)
    }
}
