import Speech
import AVFoundation

/// Owns all Speech state on one queue; never opens a microphone or network fallback.
final class LiveCallSpeech {
    private let queue = DispatchQueue(label: "app.nino.live-speech")
    private let recognizer: SFSpeechRecognizer
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timer: DispatchSourceTimer?
    private var running = false
    private var generation = UUID()
    private var latest = ""
    private var failures = 0
    private let onText: (String, Bool) -> Void
    private let onStatus: (String) -> Void
    init(recognizer: SFSpeechRecognizer, onText: @escaping (String, Bool) -> Void, onStatus: @escaping (String) -> Void) {
        self.recognizer = recognizer; self.onText = onText; self.onStatus = onStatus
    }
    @MainActor static func authorizedRecognizer(language: String) async throws -> SFSpeechRecognizer {
        try await VoicePermissions.shared.ensureSpeech()
        try Task.checkCancellation()
        let locales = ["fr":"fr-FR", "en":"en-US", "it":"it-IT", "es":"es-ES", "de":"de-DE"]
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locales[language] ?? language)), recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            throw NinoError("Reconnaissance locale indisponible pour cette langue. Aucun audio ne sera envoyé au cloud ; l’enregistrement peut continuer. Pour le transcrire ensuite, prépare un modèle Whisper dans Connexions.")
        }
        return recognizer
    }
    func start() { queue.async { [self] in running = true; failures = 0; begin() } }
    func append(_ buffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(buffer), CMSampleBufferGetNumSamples(buffer) > 0 else { return }
        queue.async { [self] in guard running else { return }; request?.appendAudioSampleBuffer(buffer) }
    }
    private func begin() {
        guard running else { return }
        let token = UUID(); generation = token; latest = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true; request.addsPunctuation = true
        self.request = request
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            let text = result?.bestTranscription.formattedString
            let final = result?.isFinal == true
            self.queue.async { [self] in
                guard self.running, self.generation == token else { return }
                if let text, !text.isEmpty { self.latest = text; self.failures = 0; self.onText(text, false) }
                if final || error != nil {
                    if error != nil { self.failures += 1 }
                    self.finishRequest(commit: true)
                    if self.failures >= 3 { self.running = false; self.onStatus("Le direct s’est interrompu. L’enregistrement continue ; la transcription finale reste disponible après l’appel.") }
                    else {
                        self.queue.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.begin() }
                    }
                }
            }
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 45)
        timer.setEventHandler { [weak self] in guard let self, self.running else { return }; self.finishRequest(commit: true); self.begin() }
        self.timer = timer; timer.resume()
    }
    private func finishRequest(commit: Bool) {
        generation = UUID(); timer?.cancel(); timer = nil
        request?.endAudio(); task?.cancel(); request = nil; task = nil
        if commit && !latest.isEmpty { onText(latest, true) }
        latest = ""
    }
    func stop() { queue.async { [self] in running = false; finishRequest(commit: false) } }
    deinit { timer?.cancel(); task?.cancel() }
}
