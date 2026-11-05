import SwiftUI

struct NotchView: View {
    @ObservedObject var store: NinoStore
    @ObservedObject var presentation: NotchPresentation
    @ObservedObject var work: WorkspaceStore
    @ObservedObject var agent: LocalAgent
    @ObservedObject var delivery: DeliveryStore
    var hover: (Bool) -> Void
    var open: () -> Void
    var collapse: () -> Void
    @NinoState private var dropTarget = false
    @NinoState private var showAllTools = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var mood: CompanionMood {
        if store.error != nil { return .error }
        if store.copying { return .importing }
        if store.busyID != nil { return .transcribing }
        if store.summaryBusy || store.assistant.thinking || agent.working { return .thinking }
        if store.isStarting || store.recordingID != nil {
            return store.documents.first(where: { $0.id == (store.recordingID ?? store.selected) })?.title.hasPrefix("Appel") == true ? .call : .dictate
        }
        if presentation.preview != .idle { return presentation.preview }
        if presentation.reading { return .read }
        if store.timerEnd != nil { return .timer }
        if delivery.running { return .thinking }
        if work.sharing, let event = work.activity, !event.stale {
            if event.state == "working" { return .thinking }
            if event.state == "completed" { return .success }
            if event.state == "failed" { return .error }
        }
        if store.notice != nil { return .success }
        return .idle
    }
    private var deliveryContext: Bool {
        !showAllTools && !presentation.showTimer && !presentation.showCallPrompter && !presentation.demo &&
        !store.isStarting && !store.isStopping && store.recordingID == nil && store.busyID == nil &&
        !store.copying && store.error == nil &&
        (delivery.engaged || store.page == "delivery" || [.editor, .designer, .communication, .creator].contains(store.profile))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { if presentation.expanded { collapse() } else { hover(true) } } label: {
                    HStack(spacing: 3) {
                        CompanionView(mood: mood, energy: store.companionEnergy).frame(width: 42, height: presentation.topHeight)
                        Text("nino").font(.system(size: 12, weight: .semibold, design: .rounded))
                    }.frame(width: 96, height: presentation.topHeight)
                }.buttonStyle(.plain).help("Ouvrir ou replier les outils de Nino")
                Spacer().frame(width: presentation.cameraWidth)
                Button { if store.recordingID != nil { store.openCallAssistant?() } else if store.timerEnd != nil && store.recordingID == nil { presentation.showTimer = true; hover(true) } else if store.updates.hint { navigate("settings"); store.updates.showDetails = true } else { navigate("today") } } label: {
                    Group {
                        if let started = store.recordingStarted {
                            HStack(spacing: 5) { Circle().fill(.red).frame(width: 5,height: 5); Text(started, style: .timer).font(.system(size: 10)).monospacedDigit() }
                        } else if let end = store.timerEnd {
                            Label { Text(end, style: .timer).monospacedDigit() } icon: { Image(systemName: "timer") }.font(.system(size: 11)).foregroundStyle(ninoAccent)
                        } else { NotchIdleGlance(updates: store.updates, attention: store.attention, today: store.today) }
                    }.frame(width: 104, height: presentation.topHeight)
                }.buttonStyle(.plain).help(store.timerEnd != nil ? "Ouvrir le minuteur" : "Ouvrir Aujourd’hui")
            }.frame(height: presentation.topHeight)
            if presentation.expanded {
                if presentation.showCallPrompter {
                    NotchCallPrompter(store: store, assistant: store.assistant, presentation: presentation, close: collapse)
                        .frame(height: 390)
                } else if deliveryContext {
                    DeliveryNotch(delivery: delivery, configure: { navigate("delivery") }, tools: { showAllTools = true })
                } else {
                VStack(spacing: 12) {
                    if presentation.showTimer { NotchTimerControls(store: store) { presentation.showTimer = false }.frame(height: 90) } else {
                    HStack(spacing: 18) {
                        CompanionView(mood: dropTarget ? .importing : mood, demo: presentation.demo, energy: store.companionEnergy).frame(width: 108, height: 90)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(presentation.demo ? "Les gestes de Nino" : store.isStarting ? "Démarrage…" : store.busyID != nil ? "Transcription…" : store.latestTranscript != nil && store.recordingID == nil ? "Transcription disponible" : mood.label).font(.system(size: 19, weight: .semibold, design: .rounded))
                            if let date = store.recordingStarted { Label { Text(date, style: .timer).monospacedDigit() } icon: { Circle().fill(.red).frame(width: 6,height: 6) } }
                            else { Text(store.busyID != nil ? store.phase : "Ton compagnon, juste ici.").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2) }
                            if store.recordingID != nil {
                                Label(store.microphoneLevel > 0.015 ? "Voix détectée" : "Enregistrement actif", systemImage: "waveform").font(.system(size: 11)).foregroundStyle(ninoAccent)
                            }
                            Button(presentation.demo ? "Arrêter l’aperçu" : "Voir les gestes") { presentation.demo.toggle() }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(ninoAccent).help("Aperçu des animations, sans activer le micro")
                        }.frame(maxWidth: .infinity,alignment: .leading)
                    }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        tool("Appel", "phone", .call, enabled: store.canCapture) { Task { await store.startRecording(call: true, fromNotch: true) } }
                        tool("Dicter", "mic", .dictate, enabled: store.canCapture) { Task { await store.startRecording(call: false, dictation: true) } }
                        tool("Prompteur", "book", .read) { if store.script.isEmpty { navigate("prompter") } else { store.openPrompter?() } }
                        tool("Importer", "square.and.arrow.down", .importing, enabled: store.canCapture) { collapse(); open(); store.chooseFiles() }
                        tool("Documents", "doc.text", .documents) { navigate("library") }
                        tool("Note vocale", "waveform", .dictate, enabled: store.canCapture) { Task { await store.startRecording(call: false) } }
                        tool("Minuteur", "timer", .timer) { presentation.showTimer.toggle() }
                        tool("Post-it", "note.text", .documents) { if let id = store.notes.create(projectID: store.work.current?.id) { store.openStickyNote?(id) } }
                    }
                    if store.isStarting {
                        HStack { ProgressView().controlSize(.small); Text("Vérification des autorisations…").font(.caption); Button("Annuler") { store.cancelRecordingStart() }.font(.caption) }.frame(height: 58)
                    } else if store.recordingID != nil {
                        VStack(spacing: 7) {
                            NotchLiveStatus(assistant: store.assistant)
                            HStack(spacing: 10) {
                                if let id = store.recordingID, store.documents.first(where: { $0.id == id })?.sources.contains(where: { $0.label == "Appel" }) == true {
                                    Button("Voir le direct", systemImage: "rectangle.topthird.inset.filled") { store.openCallAssistant?() }.buttonStyle(.bordered).help("Afficher les paroles et l’aide de Nino, sans modifier l’enregistrement")
                                }
                                Button(store.isStopping ? "Finalisation…" : "Arrêter et transcrire", systemImage: "stop.fill") { Task { await store.stopRecording() } }.buttonStyle(.borderedProminent).tint(.red).disabled(store.isStopping)
                            }
                        }.frame(height: 58)
                    } else if store.busyID != nil {
                        HStack { ProgressView().controlSize(.small); Text(store.phase).font(.caption); Spacer(); Button("Annuler") { store.runner.cancel() }.disabled(store.copying) }.frame(height: 58)
                    } else if let error = store.error {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error).lineLimit(2).font(.system(size:11)).foregroundStyle(.orange)
                            HStack {
                                if store.needsScreenPermission { Button("Ouvrir les autorisations") { store.openScreenPermissionSettings() } }
                                Button("Détails") { open() }
                                Button("Fermer") { store.error = nil }
                            }.font(.caption)
                        }.frame(height: 58)
                    } else if let doc = store.latestTranscript {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(doc.transcript).font(.system(size: 11)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            HStack {
                                Button("Copier le texte", systemImage: "doc.on.doc") { store.copy(doc.transcript) }
                                Spacer()
                                Button("Voir la transcription", systemImage: "text.alignleft") { store.selected = doc.id; navigate("library") }
                            }.font(.system(size: 11)).foregroundStyle(ninoAccent)
                        }.frame(height: 58)
                    } else {
                        AgentNotchSummary(attention: store.attention, work: store.work, open: { navigate("today") }, openWork: { navigate("home") }).frame(height: 58)
                    }
                    HStack {
                        Label("Sur ton Mac",systemImage:"lock.shield").foregroundStyle(.secondary)
                        Button("Livraison", systemImage: "checkmark.seal") { showAllTools = false; navigate("delivery") }
                        Button(presentation.snowEnabled ? "Neige : oui" : "Neige : non", systemImage: "snowflake") { presentation.snowEnabled.toggle() }
                        Spacer()
                        Button("Mon travail",systemImage:"rectangle.stack") { navigate("home") }.buttonStyle(.plain)
                    }.font(.system(size:10))
                }.padding(.horizontal,20).padding(.bottom,16).frame(height:390,alignment:.top)
                }
            }
        }.frame(maxWidth:.infinity, maxHeight:.infinity,alignment:.top)
            .background(Color.black.opacity(presentation.showCallPrompter && !reduceTransparency ? 0.72 : 1), in: UnevenRoundedRectangle(bottomLeadingRadius: presentation.expanded ? 26 : 12, bottomTrailingRadius: presentation.expanded ? 26 : 12))
            .foregroundStyle(.white).preferredColorScheme(.dark)
            .onHover(perform: hover)
            .onChange(of: presentation.expanded) { _, expanded in if !expanded { presentation.demo = false; presentation.preview = .idle; showAllTools = false } }
            .onDrop(of: [.fileURL], isTargeted: $dropTarget) { providers in
                if deliveryContext {
                    guard !delivery.running, providers.count == 1, let first = providers.first else { return false }
                    _ = first.loadObject(ofClass: URL.self) { url, _ in Task { @MainActor in if let url, !delivery.running { delivery.select(folder: url) } } }
                    return true
                }
                guard store.canCapture,let first = providers.first else { return false }
                _ = first.loadObject(ofClass: URL.self) { url,_ in if let url { Task { @MainActor in guard store.canCapture else { return }; await store.importFile(url) } } }
                return true
            }
    }
    func navigate(_ page: String) { store.page = page; collapse(); open() }
    func tool(_ label: String, _ symbol: String, _ mood: CompanionMood, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button { presentation.demo = false; presentation.preview = mood; action() } label: {
            VStack(spacing:7) { Image(systemName:symbol).font(.system(size:18,weight:.regular)); Text(label).font(.system(size:10,weight:.medium)) }
                .frame(maxWidth:.infinity).frame(height:58)
                .background(presentation.preview == mood && mood != .idle ? ninoAccent.opacity(0.18) : .white.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
        }.buttonStyle(.plain).disabled(!enabled).onHover { inside in presentation.preview = inside ? mood : .idle }
    }
}

struct NotchLiveStatus: View {
    @ObservedObject var assistant: CallAssistant
    var body: some View {
        Text(assistant.running ? (assistant.transcript.isEmpty ? "Écoute du son du Mac…" : String(assistant.transcript.suffix(160))) : "Audio conservé · texte disponible après arrêt")
            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
    }
}

struct NotchTimerControls: View {
    @ObservedObject var store: NinoStore
    var close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Minuteur", systemImage: "timer").font(.headline)
                Spacer()
                if let end = store.timerEnd { Text(end, style: .timer).font(.title2.monospacedDigit()).foregroundStyle(ninoAccent) }
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain).help("Revenir au compagnon")
            }
            if store.timerEnd == nil {
                HStack(spacing: 8) {
                    ForEach([5, 15, 25, 45], id: \.self) { minutes in
                        Button("\(minutes) min") { store.timerMinutes = Double(minutes) }
                            .buttonStyle(.plain).padding(.horizontal, 9).padding(.vertical, 7)
                            .foregroundStyle(store.timerMinutes == Double(minutes) ? Color.black : .white)
                            .background(store.timerMinutes == Double(minutes) ? ninoAccent : .white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    }
                    Spacer()
                    Button("Démarrer") { store.startTimer() }.buttonStyle(NinoPrimaryStyle())
                }.font(.system(size: 11))
            } else {
                HStack { Text("Tu peux refermer l’encoche.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Arrêter") { store.stopTimer() }.buttonStyle(.bordered) }
            }
        }.padding(.horizontal, 4)
    }
}
