import Foundation
import AVFoundation
import Combine

@MainActor final class AudioPlayback: ObservableObject {
    @Published private(set) var playing = false
    @Published private(set) var ready = false
    @Published private(set) var position = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var error: String?
    private let player = AVPlayer()
    private var observation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var periodic: Any?
    private var generation = UUID()
    private var pendingSeek: (seconds: Double, play: Bool)?
    init() {
        periodic = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.position = time.seconds.isFinite ? max(0, time.seconds) : 0
                self.playing = self.player.rate > 0
            }
        }
    }
    deinit {
        if let periodic { player.removeTimeObserver(periodic) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
    func load(_ url: URL?) {
        pause(); observation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver); self.endObserver = nil }
        generation = UUID(); let token = generation
        ready = false; error = nil; position = 0; duration = 0; pendingSeek = nil
        player.replaceCurrentItem(with: nil)
        guard let url else { return }
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else { error = "L’audio n’est plus accessible sur le disque."; return }
        let asset = AVURLAsset(url: url, options: [AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue])
        let item = AVPlayerItem(asset: asset)
        observation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.ready = item.status == .readyToPlay
                if item.status == .failed { self.error = "Lecture impossible : " + (item.error?.localizedDescription ?? "format audio non pris en charge"); self.pause() }
                let seconds = item.duration.seconds
                self.duration = seconds.isFinite ? max(0, seconds) : 0
                if self.ready, let pending = self.pendingSeek { self.pendingSeek = nil; self.seek(pending.seconds, play: pending.play) }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, self.generation == token else { return }; self.playing = false; self.position = self.duration }
        }
        player.replaceCurrentItem(with: item)
    }
    func toggle() {
        guard ready else { return }
        if playing { pause(); return }
        if duration > 0 && position >= duration - 0.1 { player.seek(to: .zero) }
        player.play(); playing = true
    }
    func pause() { player.pause(); playing = false }
    func seek(_ seconds: Double, play: Bool = false) {
        guard seconds.isFinite else { return }
        guard ready else { pendingSeek = (seconds, play); return }
        let target = min(max(0, seconds), duration > 0 ? duration : seconds)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600)); position = target
        if play { player.play(); playing = true }
    }
}
