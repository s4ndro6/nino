import Foundation
import AppKit
import Combine
import AVFoundation
import Speech
import CoreGraphics

/// Resolves exactly once, including cancellation before registration and late OS callbacks.
final class PermissionReply<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?
    func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result) }
        else { self.continuation = continuation; lock.unlock() }
    }
    func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation; self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
    static func wait(timeout: TimeInterval = 30, request: @escaping (@escaping @Sendable (Value) -> Void) -> Void) async throws -> Value {
        let reply = PermissionReply<Value>()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                reply.install(continuation)
                guard !Task.isCancelled else { reply.resolve(.failure(CancellationError())); return }
                let deadline = DispatchWorkItem { reply.resolve(.failure(VoicePermissionError.timeout)) }
                // A busy UI (or a command-line test runner) must not postpone the timeout.
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout, execute: deadline)
                request { value in deadline.cancel(); reply.resolve(.success(value)) }
            }
        }, onCancel: { reply.resolve(.failure(CancellationError())) })
    }
}

enum VoicePermissionError: LocalizedError {
    case timeout, microphone, speech
    var errorDescription: String? {
        switch self {
        case .timeout: return "macOS n’a pas répondu à temps. Tu peux annuler ou reprendre la préparation ; aucun enregistrement n’a démarré."
        case .microphone: return "Le micro n’est pas autorisé. Active Nino dans Confidentialité et sécurité → Microphone."
        case .speech: return "La reconnaissance vocale n’est pas autorisée. Le direct et le suivi vocal restent désactivés ; l’enregistrement et Whisper restent disponibles."
        }
    }
}

@MainActor final class VoicePermissions: ObservableObject {
    enum Kind { case microphone, speech, systemAudio }
    static let shared = VoicePermissions()
    @Published private(set) var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published private(set) var speech = SFSpeechRecognizer.authorizationStatus()
    @Published private(set) var screen = CGPreflightScreenCaptureAccess()
    @Published private(set) var preparing = false
    @Published private(set) var phase: String?
    @Published private(set) var message: String?
    private var microphoneRequest: (UUID, Task<Void, Error>)?
    private var speechRequest: (UUID, Task<Void, Error>)?
    private var preparation = UUID()
    private var activationObserver: NSObjectProtocol?
    private init() {
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func refresh() {
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        speech = SFSpeechRecognizer.authorizationStatus()
        screen = CGPreflightScreenCaptureAccess()
    }
    func ensureMicrophone() async throws {
        try Task.checkCancellation(); refresh()
        if microphone == .authorized { return }
        guard microphone == .notDetermined else { throw VoicePermissionError.microphone }
        if let request = microphoneRequest { try await awaitRequest(request.1); return }
        let id = UUID()
        let task = Task { @MainActor in
            let granted = try await PermissionReply<Bool>.wait { callback in AVCaptureDevice.requestAccess(for: .audio, completionHandler: callback) }
            try Task.checkCancellation(); self.refresh()
            guard granted else { throw VoicePermissionError.microphone }
        }
        microphoneRequest = (id, task)
        defer { if microphoneRequest?.0 == id { microphoneRequest = nil } }
        try await awaitRequest(task)
    }
    func ensureSpeech() async throws {
        try Task.checkCancellation(); refresh()
        if speech == .authorized { return }
        guard speech == .notDetermined else { throw VoicePermissionError.speech }
        if let request = speechRequest { try await awaitRequest(request.1); return }
        let id = UUID()
        let task = Task { @MainActor in
            let granted = try await PermissionReply<SFSpeechRecognizerAuthorizationStatus>.wait { callback in SFSpeechRecognizer.requestAuthorization(callback) }
            try Task.checkCancellation(); self.refresh()
            guard granted == .authorized else { throw VoicePermissionError.speech }
        }
        speechRequest = (id, task)
        defer { if speechRequest?.0 == id { speechRequest = nil } }
        try await awaitRequest(task)
    }
    private func awaitRequest(_ task: Task<Void, Error>) async throws {
        try await withTaskCancellationHandler(operation: { try await task.value; try Task.checkCancellation() }, onCancel: { task.cancel() })
    }
    /// Explicit preparation action only. Does not start audio capture.
    func prepareVoice() async {
        guard !preparing else { return }
        let token = UUID(); preparation = token; preparing = true; message = nil
        defer { if preparation == token { preparing = false; phase = nil; refresh() } }
        do {
            phase = "Microphone"; try await ensureMicrophone()
            guard preparation == token else { return }
            phase = "Reconnaissance vocale"
            do { try await ensureSpeech() }
            catch is CancellationError { throw CancellationError() }
            catch { message = error.localizedDescription }
            try Task.checkCancellation(); guard preparation == token else { return }
            phase = "Son du Mac"; refresh()
            if !screen { _ = CGRequestScreenCaptureAccess(); refresh() }
            if !screen { message = "Pour entendre les appels au casque, active Nino dans les réglages d’enregistrement de l’écran et des sons du système. macOS peut demander de rouvrir Nino." }
            else if message == nil { message = "La voix est prête. L’écoute démarre uniquement lorsque tu lances une note vocale ou un appel." }
        } catch is CancellationError { if preparation == token { message = "Préparation annulée. Aucun enregistrement n’a démarré." } }
        catch { if preparation == token { message = error.localizedDescription } }
    }
    func cancelPendingRequest() {
        preparation = UUID(); microphoneRequest?.1.cancel(); speechRequest?.1.cancel()
        microphoneRequest = nil; speechRequest = nil; preparing = false; phase = nil
        message = "Préparation annulée. Les autorisations déjà accordées sont conservées."; refresh()
    }
    func openSettings(for kind: Kind) {
        let pane: String
        switch kind { case .microphone: pane = "Privacy_Microphone"; case .speech: pane = "Privacy_SpeechRecognition"; case .systemAudio: pane = "Privacy_ScreenCapture" }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}
