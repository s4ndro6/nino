import Foundation
import AVFoundation

/// Decode local audio/video with macOS. Originals are never modified.
enum AudioPreparation {
    static func convert(_ source: URL, to destination: URL, checkCancellation: @escaping @Sendable () throws -> Void = {}) async throws {
        guard source.isFileURL, destination.isFileURL else { throw NinoError("Choisis un média local.") }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw NinoError("La source audio n’est pas un fichier ordinaire.") }
        // Playlists can point to remote media. Only local containers accepted by the UI.
        let supported = ["m4a", "mp3", "mp4", "mov", "wav", "aiff", "aif", "caf", "aac", "flac"]
        guard supported.contains(source.pathExtension.lowercased()) else { throw NinoError("Format non pris en charge. Exporte une piste WAV, M4A ou MP3, puis importe-la.") }
        let asset = AVURLAsset(url: source, options: [AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidAll.rawValue])
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw NinoError("Ce média ne contient aucune piste audio.") }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw NinoError("Ce format audio ne peut pas être décodé par macOS.") }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? NinoError("Lecture audio impossible.") }
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".audio-\(UUID().uuidString).wav")
        defer { reader.cancelReading(); try? FileManager.default.removeItem(at: staging) }
        guard FileManager.default.createFile(atPath: staging.path, contents: Data(repeating: 0, count: 44), attributes: [.posixPermissions: 0o600]) else { throw NinoError("Impossible de préparer la piste audio sur le disque.") }
        let file = try FileHandle(forWritingTo: staging)
        defer { try? file.close() }
        try file.seekToEnd()
        var size: UInt64 = 0
        while let sample = output.copyNextSampleBuffer() {
            try checkCancellation(); try Task.checkCancellation()
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            let count = CMBlockBufferGetDataLength(block)
            size += UInt64(count)
            guard size < UInt64(UInt32.max) - 36 else { throw NinoError("Cette piste est trop longue. Découpe-la avant de transcrire.") }
            var data = Data(count: count)
            let status = data.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count, destination: $0.baseAddress!) }
            guard status == kCMBlockBufferNoErr else { throw NinoError("Impossible de lire un bloc audio.") }
            try file.write(contentsOf: data)
        }
        try checkCancellation()
        guard reader.status == .completed, size > 0 else { throw reader.error ?? NinoError("Aucun audio décodable dans ce fichier.") }
        var header = Data()
        func ascii(_ s: String) { header.append(contentsOf: s.utf8) }
        func u32(_ n: UInt32) { var value = n.littleEndian; withUnsafeBytes(of: &value) { header.append(contentsOf: $0) } }
        func u16(_ n: UInt16) { var value = n.littleEndian; withUnsafeBytes(of: &value) { header.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(size) + 36); ascii("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(16000); u32(32000); u16(2); u16(16); ascii("data"); u32(UInt32(size))
        try file.seek(toOffset: 0); try file.write(contentsOf: header); try file.close()
        // The caller supplies a new random destination; never overwrite the source or another file.
        try FileManager.default.moveItem(at: staging, to: destination)
    }
}
