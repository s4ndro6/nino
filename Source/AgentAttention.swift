import SwiftUI

/// Observed MCP signals only. A saved chat is never interpreted as an active run.
@MainActor final class AgentAttentionStore: ObservableObject {
    struct Item: Identifiable {
        var event: WorkActivity
        var projectTitle: String
        var read = false
        var id: UUID { event.id }
    }
    @Published private(set) var items: [Item] = []
    var pending: Int { items.filter { !$0.read && $0.event.state != "working" }.count }
    func receive(_ event: WorkActivity, projectTitle: String) {
        guard !items.contains(where: { $0.id == event.id }) else { return }
        // One latest signal per agent/session/project; keep other observed sessions.
        items.removeAll { $0.event.projectID == event.projectID && $0.event.sessionID == event.sessionID && $0.event.agent == event.agent }
        items.insert(Item(event: event, projectTitle: projectTitle), at: 0)
        if items.count > 50 { items.removeLast(items.count - 50) }
    }
    func acknowledge(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].read = true
    }
}

struct AgentAttentionView: View {
    @ObservedObject var attention: AgentAttentionStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label("À ton attention", systemImage: "bell.badge").font(.headline); Spacer(); Text("\(attention.pending)").monospacedDigit().foregroundStyle(ninoAccent) }
            Text("Signaux reçus via le partage MCP pendant cette session de Nino. Les chats non connectés n’exposent pas leur progression.").font(.caption).foregroundStyle(.secondary)
            if attention.items.isEmpty {
                Text("Aucun signal reçu. Active le partage dans une fiche et connecte le MCP Nino à ton outil pour recevoir ses états.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(attention.items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.event.state == "failed" ? "exclamationmark.circle" : item.event.state == "completed" ? "checkmark.circle" : "bubble.left")
                        .foregroundStyle(item.event.state == "failed" ? Color.orange : ninoAccent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: item.projectTitle).font(.subheadline.weight(.semibold))
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            Text("\(item.event.agent) · \(item.event.label)").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(verbatim: item.event.message).font(.callout).textSelection(.enabled).lineLimit(4)
                        Text(item.event.reportedAt, format: .dateTime.hour().minute()).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !item.read && item.event.state != "working" { Button("Vu") { attention.acknowledge(item.id) } }
                    else if item.read { Text("Vu").font(.caption).foregroundStyle(.secondary) }
                }.padding(12).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            }
        }.padding(18).background(ninoAccent.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }
}
