import Foundation
import AVFoundation
import CryptoKit

@main struct VoicePipelineTests {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("nino-voice-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let modelFile = root.appendingPathComponent("model.bin")
        let content = Data("synthetic model fixture".utf8)
        let hash = SHA256.hash(data: content).map { String(format: "%02x", $0) }.joined()
        let fixture = LocalWhisperModel(id: "fixture", title: "Fixture", bytes: Int64(content.count), sha256: hash)
        try content.write(to: modelFile); try fixture.verify(modelFile)
        try Data(repeating: 0, count: content.count).write(to: modelFile)
        do { try fixture.verify(modelFile); fatalError("Corrupt model accepted") } catch is NinoError {}
        try Data([1]).write(to: modelFile)
        do { try fixture.verify(modelFile); fatalError("Truncated model accepted") } catch is NinoError {}
        let linked = root.appendingPathComponent("linked.bin")
        try fm.createSymbolicLink(at: linked, withDestinationURL: modelFile)
        do { try fixture.verify(linked); fatalError("Symlink accepted") } catch is NinoError {}
        try content.write(to: modelFile)
        do { try fixture.verify(modelFile) { throw CancellationError() }; fatalError("Cancelled verification accepted") } catch is CancellationError {}
        precondition(!TranscriptionRuntime.modelReady(modelFile))

        let source = root.appendingPathComponent("note.m4a")
        try createAudio(source)
        let before = try Data(contentsOf: source)
        let target = root.appendingPathComponent("converted.wav")
        try await AudioPreparation.convert(source, to: target)
        let wav = try AVAudioFile(forReading: target)
        precondition(wav.fileFormat.sampleRate == 16000 && wav.fileFormat.channelCount == 1)
        precondition(wav.length >= 15000 && wav.length <= 18000)
        let after = try Data(contentsOf: source); precondition(after == before)
        let cancelled = root.appendingPathComponent("cancelled.wav")
        do { try await AudioPreparation.convert(source, to: cancelled) { throw CancellationError() }; fatalError("Cancellation ignored") } catch is CancellationError {}
        precondition(!fm.fileExists(atPath: cancelled.path))
        let playlist = root.appendingPathComponent("remote.m3u8")
        try Data("#EXTM3U\nhttps://example.com/audio.m4a".utf8).write(to: playlist)
        do { try await AudioPreparation.convert(playlist, to: cancelled); fatalError("Playlist accepted") } catch is NinoError {}

        let playback = AudioPlayback()
        playback.load(root.appendingPathComponent("unfinished.m4a"))
        precondition(!playback.ready && playback.error != nil)
        // Same controller can load the finalized audio after a recording ends.
        playback.load(source)
        for _ in 0..<100 where !playback.ready { try await Task.sleep(for: .milliseconds(20)) }
        precondition(playback.ready && playback.error == nil)
        precondition(playback.duration > 0)
        playback.seek(0.5)
        precondition(playback.position == 0.5)
        playback.pause(); playback.load(nil)
        precondition(!playback.ready && !playback.playing)
        print("PASS voice: SHA256, truncated/corrupt/symlink/cancelled models; AAC → 16k mono WAV; original preserved; conversion cancelled; playlist rejected; playback reload after finalization, seek and stop. No microphone opened.")
    }
    static func createAudio(_ url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 96000])
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        for i in 0..<44100 { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 440 * 2 * .pi / 44100) * 0.02) }
        try file.write(from: buffer)
    }
}
