import Foundation
import SwiftUI
let ninoAccent = Color.green
@main struct AgentAttentionTests {
    @MainActor static func main() {
        let inbox = AgentAttentionStore(), project = UUID(), session = UUID()
        func event(_ state: String, sessionID: UUID? = nil) -> WorkActivity {
            WorkActivity(schemaVersion: 1, id: UUID(), projectID: project, sessionID: sessionID ?? session, state: state, message: "Test synthétique", agent: "Test", reportedAt: Date())
        }
        let active = event("working")
        inbox.receive(active, projectTitle: "Projet A")
        inbox.receive(active, projectTitle: "Projet A")
        precondition(inbox.items.count == 1 && inbox.pending == 0)
        precondition(inbox.activeCount == 1 && inbox.featured?.id == active.id)
        var stale = event("working", sessionID: UUID()); stale.reportedAt = Date().addingTimeInterval(-600)
        inbox.receive(stale, projectTitle: "Ancien signal")
        precondition(inbox.activeCount == 1 && inbox.featured?.id == active.id)
        let waiting = event("waiting")
        inbox.receive(waiting, projectTitle: "Projet A")
        precondition(inbox.items.count == 2 && inbox.pending == 1)
        inbox.acknowledge(waiting.id)
        inbox.receive(waiting, projectTitle: "Projet A")
        precondition(inbox.pending == 0)
        inbox.receive(event("completed"), projectTitle: "Projet A")
        precondition(inbox.pending == 1)
        for _ in 0..<55 { inbox.receive(event("failed", sessionID: UUID()), projectTitle: "Projet A") }
        precondition(inbox.items.count == 50 && inbox.pending == 50)
        print("AgentAttentionTests PASS: deduplication, transitions, acknowledgment, session isolation, bounds")
    }
}
