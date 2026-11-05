import AVFoundation
import ScreenCaptureKit
import CoreMedia

// Each track is written on one serial queue. No screen images are written to disk.
final class TrackWriter {
    let url: URL
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private(set) var firstTime: Double?
    private(set) var failure: Error?
    private(set) var samples = 0
    var finalized: Bool { writer?.status == .completed && samples > 0 }
    init(url: URL) { self.url = url }
    func append(_ buffer: CMSampleBuffer) {
        guard failure == nil, CMSampleBufferDataIsReady(buffer) else { return }
        do {
            if writer == nil {
                let w = try AVAssetWriter(outputURL: url, fileType: .m4a)
                let i = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128000])
                i.expectsMediaDataInRealTime = true
                guard w.canAdd(i) else { throw NinoError("Format audio non pris en charge.") }
                w.add(i)
                guard w.startWriting() else { throw w.error ?? NinoError("Impossible d’écrire la piste audio.") }
                let time = CMSampleBufferGetPresentationTimeStamp(buffer)
                w.startSession(atSourceTime: time)
                firstTime = time.seconds; writer = w; input = i
            }
            guard let input, input.isReadyForMoreMediaData else { throw NinoError("Le disque ne suit pas le débit audio. L’enregistrement est interrompu pour éviter une perte silencieuse.") }
            guard input.append(buffer) else { throw writer?.error ?? NinoError("Échec d’écriture audio.") }
            samples += 1
        } catch { failure = error }
    }
    #if NINO_TESTING
    func simulateCaptureError() { failure = NinoError("Erreur de capture injectée pour le test de récupération.") }
    #endif
    func finish() async throws -> Bool {
        guard let writer, let input, samples > 0 else {
            if let failure { throw failure }
            return false
        }
        // Finalize recoverable samples even after a capture/backpressure error.
        if writer.status == .writing {
            input.markAsFinished()
            await writer.finishWriting()
        }
        guard writer.status == .completed else { throw writer.error ?? NinoError("Finalisation audio impossible. Les fichiers incomplets restent disponibles.") }
        if let failure { throw failure }
        return true
    }
}

struct CaptureStopResult {
    let sources: [AudioSource]
    let warning: Error?
}

final class CallCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    let queue = DispatchQueue(label: "app.nino.audio-capture")
    private var mic: TrackWriter!
    private var system: TrackWriter!
    var onSystemAudio: ((CMSampleBuffer) -> Void)?
    var onError: ((Error) -> Void)?
    private var errorReported = false
    private let stateLock = NSLock()
    private var stoppedError: Error?
    func start(folder: URL) async throws {
        try await VoicePermissions.shared.ensureMicrophone()
        try Task.checkCancellation()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        try Task.checkCancellation()
        guard let display = content.displays.first else { throw NinoError("Aucun écran disponible pour la capture audio système.") }
        let own = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = 2; config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.capturesAudio = true; config.captureMicrophone = true
        config.sampleRate = 48000; config.channelCount = 1
        config.excludesCurrentProcessAudio = true
        mic = TrackWriter(url: folder.appendingPathComponent("micro.m4a"))
        system = TrackWriter(url: folder.appendingPathComponent("appel.m4a"))
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        self.stream = stream
        do {
            try await stream.startCapture()
            try Task.checkCancellation()
            if let failure = lastStoppedError() { throw failure }
        }
        catch {
            try? await stream.stopCapture()
            self.stream = nil
            throw error
        }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if type == .audio { system.append(sampleBuffer); onSystemAudio?(sampleBuffer) }
        if type == .microphone { mic.append(sampleBuffer) }
        if !errorReported, let failure = mic.failure ?? system.failure { errorReported = true; onError?(failure) }
    }
    private func lastStoppedError() -> Error? { stateLock.lock(); defer { stateLock.unlock() }; return stoppedError }
    func stream(_ stream: SCStream, didStopWithError error: Error) { stateLock.lock(); stoppedError = error; stateLock.unlock(); onError?(error) }
    func stop() async throws -> [AudioSource] {
        let result = await stopPreservingAudio()
        if let warning = result.warning { throw warning }
        return result.sources
    }
    func stopPreservingAudio() async -> CaptureStopResult {
        var stopError: Error?
        do { try await stream?.stopCapture() } catch { stopError = error }
        stream = nil
        guard let mic, let system else { return CaptureStopResult(sources: [], warning: stopError) }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in queue.async { c.resume() } }
        var result: [AudioSource] = []
        let origin = min(mic.firstTime ?? .greatestFiniteMagnitude, system.firstTime ?? .greatestFiniteMagnitude)
        var finalError: Error?
        for (track, label) in [(mic, "Moi"), (system, "Appel")] {
            do { _ = try await track.finish() } catch { finalError = error }
            // A failed track can still contain finalized, usable audio. Keep its reference.
            if track.finalized { result.append(AudioSource(filename: track.url.lastPathComponent, label: label, offset: max(0, (track.firstTime ?? origin) - origin))) }
        }
        let missing: Error? = result.count == 2 ? nil : NinoError("Une piste de l’appel manque. Les fichiers capturés sont conservés ; vérifie le micro et le son système avant de recommencer.")
        return CaptureStopResult(sources: result, warning: finalError ?? stopError ?? missing)
    }
}
