import Foundation

final class ProcessRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var active: Process?
    private var cancelled = false
    func reset() { lock.lock(); cancelled = false; lock.unlock() }
    func cancel() { lock.lock(); cancelled = true; let process = active; lock.unlock(); if process?.isRunning == true { process?.terminate() } }
    func checkCancellation() throws { lock.lock(); let stopped = cancelled; lock.unlock(); if stopped { throw CancellationError() } }
    func run(_ executable: String, _ arguments: [String], log: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard FileManager.default.isExecutableFile(atPath: executable) else { throw NinoError("Outil introuvable : \(executable)") }
                    FileManager.default.createFile(atPath: log.path, contents: nil)
                    let output = try FileHandle(forWritingTo: log)
                    defer { try? output.close() }
                    let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
                    process.standardOutput = output; process.standardError = output
                    // No shell: media filenames and text are never evaluated as commands.
                    self.lock.lock()
                    if self.cancelled { self.lock.unlock(); throw CancellationError() }
                    self.active = process
                    do { try process.run() } catch { self.active = nil; self.lock.unlock(); throw error }
                    self.lock.unlock()
                    process.waitUntilExit()
                    self.lock.lock(); self.active = nil; let cancelled = self.cancelled; self.lock.unlock()
                    if cancelled { throw CancellationError() }
                    guard process.terminationStatus == 0 else {
                        let details = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
                        throw NinoError("L’outil audio a échoué (\(process.terminationStatus)). \(String(details.suffix(900)))")
                    }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
