import Foundation

@main struct PermissionTests {
    static func main() async throws {
        let immediate = try await PermissionReply<Int>.wait(timeout: 0.1) { callback in callback(42); callback(99) }
        precondition(immediate == 42, "First callback must win")
        let started = Date()
        do {
            _ = try await PermissionReply<Int>.wait(timeout: 0.03) { callback in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) { callback(7); callback(8) }
            }
            preconditionFailure("Missing timeout")
        } catch VoicePermissionError.timeout {}
        precondition(Date().timeIntervalSince(started) < 0.5, "No group may await the pending OS callback")
        let cancelled = Task {
            try await PermissionReply<Int>.wait(timeout: 2) { callback in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) { callback(3) }
            }
        }
        try await Task.sleep(for: .milliseconds(10)); cancelled.cancel()
        do { _ = try await cancelled.value; preconditionFailure("Missing cancellation") } catch is CancellationError {}
        // Cancellation before continuation registration must also resolve safely.
        let reply = PermissionReply<Int>()
        reply.resolve(.failure(CancellationError()))
        do {
            let _: Int = try await withCheckedThrowingContinuation { reply.install($0) }
            preconditionFailure("Pre-registration cancellation was lost")
        } catch is CancellationError {}
        let race = PermissionReply<Int>()
        let value: Int = try await withCheckedThrowingContinuation { continuation in
            race.install(continuation)
            DispatchQueue.concurrentPerform(iterations: 50) { race.resolve(.success($0)) }
        }
        precondition((0..<50).contains(value))
        try await Task.sleep(for: .milliseconds(140)) // Late callbacks must not double-resume or crash.
        print("PASS permission waits: success, duplicate callbacks, timeout, cancellation, pre-registration cancellation, concurrent callbacks, late callbacks")
    }
}
