import SwiftUI

/// A non-modal reader in the existing notch window. It never speaks or sends the answer.
struct NotchCallPrompter: View {
    @ObservedObject var store: NinoStore
    @ObservedObject var assistant: CallAssistant
    @ObservedObject var presentation: NotchPresentation
    var close: () -> Void
    @NinoState private var manualQuestion = ""
    @NinoState private var correctingQuestion = false
    @NinoState private var correctionRevision = UUID()
    @FocusState private var questionFocused: Bool
    @NinoState private var page = 0
    @NinoState private var playing = false
    @NinoState private var textSize: Double = 23
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var pages: [String] {
        let words = assistant.suggestion.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return [] }
        return stride(from: 0, to: words.count, by: 44).map { words[$0..<min($0 + 44, words.count)].joined(separator: " ") }
    }
    private var currentPage: Int { min(page, max(0, pages.count - 1)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Circle().fill(store.recordingID != nil ? Color.red : .gray).frame(width: 6, height: 6)
                Text(assistant.understanding ? "NINO VÉRIFIE LA QUESTION" : assistant.thinking ? "NINO PRÉPARE UNE RÉPONSE" : "TA RÉPONSE · À VÉRIFIER")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.1).foregroundStyle(ninoAccent)
                Spacer(minLength: 8)
                if let start = store.recordingStarted { Text(start, style: .timer).monospacedDigit().font(.caption2) }
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain)
                    .accessibilityLabel("Masquer le téléprompteur").help("Masquer cette réponse sans arrêter l’enregistrement. La prochaine question pourra rouvrir l’encoche.")
            }
            Text(assistant.question.isEmpty ? "En attente d’une question dans le cours…" : assistant.question)
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if let updated = assistant.answerUpdatedAt {
                Text("Dernière réponse · " + updated.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let error = assistant.answerError {
                        Text(error).font(.system(size: 16)).foregroundStyle(.orange)
                    }
                    if pages.isEmpty {
                        Text(assistant.thinking ? "Je formule une réponse courte…" : (assistant.running ? "Nino écoute et attend une question complète. Tu peux aussi la saisir ci-dessous." : "L’écoute est arrêtée. Saisis une question ou démarre un appel depuis l’encoche."))
                            .font(.system(size: 21, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text(pages[currentPage]).font(.system(size: textSize, weight: .medium))
                            .lineSpacing(6).textSelection(.enabled)
                            .id("answer-\(assistant.answerRevision)-\(currentPage)")
                    }
                    if assistant.thinking || assistant.understanding { ProgressView().controlSize(.small).accessibilityLabel("Réponse en cours") }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack(spacing: 12) {
                Button { page = max(0, currentPage - 1); playing = false } label: { Image(systemName: "chevron.left") }
                    .disabled(currentPage == 0).accessibilityLabel("Passage précédent")
                Text(pages.isEmpty ? "—" : "\(currentPage + 1) / \(pages.count)").monospacedDigit().font(.caption)
                Button { page = min(pages.count - 1, currentPage + 1); playing = false } label: { Image(systemName: "chevron.right") }
                    .disabled(currentPage + 1 >= pages.count).accessibilityLabel("Passage suivant")
                Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill") }
                    .disabled(pages.count < 2 || assistant.thinking).accessibilityLabel(playing ? "Pause lecture" : "Lecture automatique")
                Spacer()
                Button { textSize = max(19, textSize - 2) } label: { Image(systemName: "textformat.size.smaller") }.accessibilityLabel("Réduire le texte")
                Button { textSize = min(29, textSize + 2) } label: { Image(systemName: "textformat.size.larger") }.accessibilityLabel("Agrandir le texte")
                Button { store.copy(assistant.suggestion) } label: { Image(systemName: "doc.on.doc") }
                    .disabled(assistant.suggestion.isEmpty).accessibilityLabel("Copier la réponse")
            }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 12) {
                Button {
                    manualQuestion = assistant.question
                    correctingQuestion = true
                    correctionRevision = assistant.answerRevision
                    questionFocused = true
                    playing = false
                } label: { Label("Corriger la question", systemImage: "pencil") }
                    .disabled(assistant.question.isEmpty || assistant.thinking || assistant.understanding)
                    .help("Reprends la question reconnue, corrige-la puis clique sur Répondre.")
                Button { playing = false; assistant.simplifyAnswer() } label: {
                    Label("Plus simple", systemImage: "text.alignleft")
                }.disabled(!assistant.canSimplifyAnswer)
                    .help("Une réponse plus courte avec le contexte de cette réponse.")
                Spacer(minLength: 0)
            }.buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(ninoAccent)
            HStack(spacing: 8) {
                TextField(correctingQuestion ? "Corrige la question reconnue…" : "Une question à poser à Nino…", text: $manualQuestion).textFieldStyle(.roundedBorder)
                    .focused($questionFocused)
                    .onSubmit { sendQuestion() }
                if correctingQuestion {
                    Button { correctingQuestion = false; manualQuestion = "" } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Annuler la correction")
                }
                Button("Répondre") { sendQuestion() }.disabled(manualQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.font(.system(size: 12))
            HStack(spacing: 10) {
                Toggle("Réponses auto dans l’encoche", isOn: $presentation.automaticCallPrompter).toggleStyle(.checkbox)
                Spacer(minLength: 0)
                if store.recordingID != nil {
                    Button(store.isStopping ? "Arrêt…" : "Arrêter l’écoute") { Task { await store.stopRecording() } }.disabled(store.isStopping)
                }
            }.font(.system(size: 10)).foregroundStyle(.secondary)
            Text("Visible si tu partages cet écran · masquer ne coupe pas l’écoute.")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 18)
        .onChange(of: assistant.answerRevision) { _, _ in page = 0; playing = false }
        .task(id: playing) {
            guard playing else { return }
            while !Task.isCancelled && playing {
                let words = pages.isEmpty ? 1 : pages[currentPage].split(separator: " ").count
                do { try await Task.sleep(for: .seconds(max(5, Double(words) / 2.2))) } catch { return }
                guard !Task.isCancelled, playing, !assistant.thinking else { return }
                if currentPage + 1 < pages.count {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { page = currentPage + 1 }
                } else { playing = false }
            }
        }
    }
    private func sendQuestion() {
        let question = manualQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        playing = false
        if correctingQuestion {
            guard assistant.correctQuestion(question, expectedRevision: correctionRevision) else { return }
        }
        else { assistant.suggest(question) }
        manualQuestion = ""; correctingQuestion = false; questionFocused = false
    }
}
