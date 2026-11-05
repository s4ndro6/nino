import Foundation

@main struct TerminationGateTests {
    @MainActor static func main() async {
        var checks = 0
        func expect(_ result: Bool) { precondition(result); checks += 1 }
        func tick() async { try? await Task.sleep(nanoseconds: 20_000_000) }
        // An active recording blocks before any disk/MCP operation.
        let busy = TerminationGate()
        var revokeCount = 0; var replies: [Bool] = []; var issues: [String] = []
        let result = busy.request(flush: {}, blocker: { "Capture en cours" }, revoke: { _ in revokeCount += 1 }, report: { issues.append($0) }, reply: { replies.append($0) })
        expect(result == .cancel && revokeCount == 0 && replies.isEmpty && issues.count == 1)
        // A new operation starts while saving. Exactly one refusal, even with duplicate callback.
        let gate = TerminationGate()
        var completion: (@MainActor (Bool) -> Void)?
        var blocked = false; var flushes = 0
        let later = gate.request(flush: { flushes += 1 }, blocker: { blocked ? "Nouveau travail" : nil }, revoke: { completion = $0 }, report: { issues.append($0) }, reply: { replies.append($0) })
        expect(later == .later && replies.isEmpty)
        let duplicate = gate.request(flush: {}, blocker: { nil }, revoke: { _ in revokeCount += 1 }, report: { _ in }, reply: { _ in preconditionFailure() })
        expect(duplicate == .later && revokeCount == 0)
        blocked = true; completion?(true); completion?(true); await tick()
        expect(replies == [false] && flushes == 2 && issues.last == "Nouveau travail")
        // Failed disk save never approves exit.
        replies = []
        _ = gate.request(flush: {}, blocker: { nil }, revoke: { $0(false) }, report: { _ in }, reply: { replies.append($0) })
        expect(replies.isEmpty)
        await tick(); expect(replies == [false])
        // Timeout denies exit, ignores a late success, and permits a fresh attempt.
        replies = []
        _ = gate.request(timeout: 1_000_000, flush: {}, blocker: { nil }, revoke: { completion = $0 }, report: { _ in }, reply: { replies.append($0) })
        await tick(); completion?(true); await tick(); expect(replies == [false])
        replies = []
        _ = gate.request(flush: {}, blocker: { nil }, revoke: { $0(true) }, report: { _ in preconditionFailure() }, reply: { replies.append($0) })
        expect(replies.isEmpty)
        await tick(); expect(replies == [true])
        // Notes that cannot be flushed during final validation cancel the restart.
        replies = []; var noteFailed = false
        _ = gate.request(flush: {}, blocker: { noteFailed ? "Notes non sauvegardées" : nil }, revoke: { completion = $0 }, report: { issues.append($0) }, reply: { replies.append($0) })
        noteFailed = true; completion?(true); await tick()
        expect(replies == [false] && issues.last == "Notes non sauvegardées")
        print("TerminationGate: \(checks) integration assertions passed")
    }
}
