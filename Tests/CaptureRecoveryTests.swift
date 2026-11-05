import Foundation
import AVFoundation
import CoreMedia

@main struct CaptureTest {
    static func main() async throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let writer = TrackWriter(url: output)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: true)!
        var description: CMAudioFormatDescription?
        var asbd = format.streamDescription.pointee
        guard CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description) == noErr else { fatalError("format") }
        for n in 0..<2000 {
            let frames = 1024
            let samples = (0..<frames).map { Float(sin(Double(n * frames + $0) * 2 * Double.pi * 440 / 48000) * 0.1) }
            let data = samples.withUnsafeBytes { Data($0) }
            var block: CMBlockBuffer?
            guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: data.count, blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: 0, blockBufferOut: &block) == noErr else { fatalError("block") }
            _ = data.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: data.count) }
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48000), presentationTimeStamp: CMTime(value: Int64(n * frames), timescale: 48000), decodeTimeStamp: .invalid)
            var size = 4; var buffer: CMSampleBuffer?
            guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: description, sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &buffer) == noErr else { fatalError("buffer") }
            writer.append(buffer!)
            if writer.failure != nil { break }
        }
        guard writer.samples > 0 else { throw writer.failure ?? NinoError("No audio sample accepted") }
        writer.simulateCaptureError()
        do { _ = try await writer.finish(); fatalError("Expected capture error") } catch {
            guard writer.samples > 0 else { throw error }
            print("EXPECTED capture error surfaced: \(error.localizedDescription)")
        }
        precondition(writer.finalized, "Finalized audio must remain discoverable after a track warning")
        let file = try AVAudioFile(forReading: output)
        guard file.length > 0 else { fatalError("No recoverable audio") }
        print("PASS finalized audio remains readable after stress: \(file.length) frames / \(writer.samples) buffers")
    }
}
