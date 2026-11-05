import SwiftUI
import Combine
import Speech
import AVFoundation

@MainActor final class VoiceFollower: ObservableObject {
    @Published var active = false
    @Published var error: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapped = false
    private var generation = UUID()
    private var starting = false
    func start(language: String, onWords: @escaping ([String]) -> Void) async {
        guard !starting else { return }
        stop(); starting = true
        defer { starting = false }
        let currentGeneration = generation
        do {
            try await VoicePermissions.shared.ensureMicrophone()
            guard generation == currentGeneration else { return }
            try await VoicePermissions.shared.ensureSpeech()
            try Task.checkCancellation()
        } catch {
            if generation == currentGeneration { self.error = error is CancellationError ? nil : error.localizedDescription }
            return
        }
        guard generation == currentGeneration else { return }
        let locale = language == "en" ? "en-US" : language == "it" ? "it-IT" : language == "es" ? "es-ES" : "fr-FR"
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.supportsOnDeviceRecognition else { error = "La reconnaissance locale n’est pas disponible pour cette langue. Utilise la vitesse fixe."; return }
        do {
            let request = SFSpeechAudioBufferRecognitionRequest(); request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true
            self.request = request
            let input = engine.inputNode; let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else { throw NinoError("Aucun microphone disponible.") }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }; tapped = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.generation == currentGeneration else { return }
                    if let result { onWords(result.bestTranscription.segments.map(\.substring)) }
                    if let error { self.error = error.localizedDescription; self.stop() }
                    else if result?.isFinal == true { self.stop() }
                }
            }
            engine.prepare(); try engine.start(); active = true
        } catch { self.error = error.localizedDescription; stop() }
    }
    func stop() { generation = UUID(); engine.stop(); if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }; request?.endAudio(); task?.cancel(); task = nil; request = nil; active = false }
}

enum ScriptAlignment {
    static func normalize(_ word: String) -> String { word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")).filter { $0.isLetter || $0.isNumber } }
    static func nextIndex(script: [String], spoken: [String], current: Int) -> Int? {
        let heard = spoken.suffix(4).map(normalize).filter { !$0.isEmpty }
        guard !heard.isEmpty, !script.isEmpty else { return nil }
        let words = script.map(normalize)
        let lower = max(0, current - 8), upper = min(script.count, current + 45)
        var best: (index: Int, score: Int)?
        for end in lower..<upper {
            var score = 0
            for offset in 0..<min(heard.count, end + 1) {
                if words[end - offset] == heard[heard.count - offset - 1] { score += 1 } else { break }
            }
            if score >= min(2, heard.count), score > (best?.score ?? 0) { best = (end + 1, score) }
        }
        return best.map { min(script.count - 1, $0.index) }
    }
}
struct PrompterSettingsView: View {
    @ObservedObject var store: NinoStore
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { VStack(alignment: .leading, spacing: 6) { Text("Le fil de tes idées.").font(.system(size: 30, weight: .semibold)); Text("Un prompteur sous la caméra, à ton rythme.").foregroundStyle(.secondary) }; Spacer(); Button("Ouvrir le prompteur", systemImage: "text.viewfinder") { store.saveSettings(); store.openPrompter?() }.buttonStyle(NinoPrimaryStyle()).foregroundStyle(.black).disabled(store.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            TextEditor(text: $store.script).font(.system(size: 18)).lineSpacing(7).padding(14).scrollContentBackground(.hidden).background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Importer un texte") {
                    let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText, .utf8PlainText]
                    if panel.runModal() == .OK, let url = panel.url {
                        do { store.script = try String(contentsOf: url, encoding: .utf8); store.saveSettings() } catch { store.error = error.localizedDescription }
                    }
                }
                if let doc = store.active { Button("Utiliser le document sélectionné") { store.script = doc.transcript; store.saveSettings() }.disabled(doc.segments.isEmpty) }
                Spacer(); Text("\(store.script.split(whereSeparator: \.isWhitespace).count) mots").foregroundStyle(.secondary).monospacedDigit()
            }
            HStack { Text("Vitesse"); Slider(value: $store.wpm, in: 50...240, step: 5).frame(width: 180); Text("\(Int(store.wpm)) mots/min").monospacedDigit(); Spacer(); Text("Taille"); Slider(value: $store.fontSize, in: 20...48, step: 1).frame(width: 140); Toggle("Miroir", isOn: $store.mirror) }
            Text("Espace : pause · Flèches : avancer / reculer · Échap : fermer. Le suivi vocal est facultatif et local. Vérifie le cadrage avant un partage d’écran : ce prompteur ne garantit pas d’être invisible dans toutes les applications.").font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(28).onDisappear { store.saveSettings() }
    }
}
struct PrompterView: View {
    @ObservedObject var store: NinoStore
    @StateObject private var voice = VoiceFollower()
    @NinoState private var position = 0
    @NinoState private var playing = false
    @NinoState private var lastStep = Date()
    var close: () -> Void
    var words: [String] { store.script.split(whereSeparator: \.isWhitespace).map(String.init) }
    let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                BrandMark(size: 23); Text("PROMPTEUR").font(.system(size: 9, weight: .bold)).tracking(2)
                Spacer()
                Button { position = 0; lastStep = Date() } label: { Image(systemName: "backward.end") }.help("Revenir au début")
                Button { playing.toggle(); voice.stop(); lastStep = Date() } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }.keyboardShortcut(.space, modifiers: [])
                Button {
                    playing = false
                    if voice.active { voice.stop() } else { Task { await voice.start(language: store.language) { spoken in if let next = ScriptAlignment.nextIndex(script: words, spoken: spoken, current: position) { position = next } } } }
                } label: { Image(systemName: voice.active ? "mic.fill" : "mic") }.foregroundStyle(voice.active ? ninoAccent : .white).help("Suivre ma voix localement").disabled(!store.canCapture)
                Button { voice.stop(); close() } label: { Image(systemName: "xmark") }.keyboardShortcut(.escape, modifiers: [])
            }.buttonStyle(.plain)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(stride(from: 0, to: words.count, by: 7)), id: \.self) { start in
                            let end = min(words.count, start + 7)
                            Text(words[start..<end].joined(separator: " ")).font(.system(size: store.fontSize, weight: position >= start && position < end ? .semibold : .regular)).foregroundStyle(position >= start && position < end ? ninoAccent : .white.opacity(start < position ? 0.28 : 0.75)).frame(maxWidth: .infinity, alignment: .leading).id(start)
                                .onTapGesture { position = start; lastStep = Date() }
                        }
                        Color.clear.frame(height: 100)
                    }.padding(.vertical, 20)
                }.scrollIndicators(.hidden).scaleEffect(x: store.mirror ? -1 : 1, y: 1)
                    .onChange(of: position) { _, new in withAnimation(.easeInOut(duration: 0.25)) { reader.scrollTo(new / 7 * 7, anchor: .top) } }
            }
            HStack { Text(voice.active ? "Suivi vocal local" : "\(Int(store.wpm)) mots/min"); Spacer(); Text("\(min(position + 1, words.count)) / \(words.count)").monospacedDigit() }.font(.system(size: 10)).foregroundStyle(.secondary)
            if let error = voice.error { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
        }.padding(20).background(Color.black).preferredColorScheme(.dark)
        .onReceive(tick) { now in guard playing, !words.isEmpty, now.timeIntervalSince(lastStep) >= 60 / store.wpm else { return }; if position + 1 < words.count { position += 1; lastStep = now } else { playing = false } }
        .onMoveCommand { direction in if direction == .down || direction == .right { position = min(words.count - 1, position + 7) }; if direction == .up || direction == .left { position = max(0, position - 7) } }
        .onDisappear { voice.stop() }
        .onChange(of: store.isStarting) { _, starting in if starting { voice.stop() } }
    }
}
