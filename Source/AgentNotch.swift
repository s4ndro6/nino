import SwiftUI

/// Received signals, not guessed progress from saved chats. Recording/timer UI stays higher priority.
struct NotchIdleGlance: View {
    @ObservedObject var updates: AppUpdates
    @ObservedObject var attention: AgentAttentionStore
    @ObservedObject var today: TodayStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if updates.hint, let release = updates.latest {
                Label("MAJ \(release.version.description)", systemImage: "arrow.down.circle.fill").font(.system(size: 10)).foregroundStyle(.cyan)
            } else if attention.pending > 0 {
                Label("\(attention.pending) à voir", systemImage: "bell.badge").font(.system(size: 11)).foregroundStyle(.orange)
            } else if attention.activeCount > 0 {
                Label("\(attention.activeCount) en cours", systemImage: "ellipsis.circle").font(.system(size: 10)).foregroundStyle(ninoAccent)
            } else { TodayGlance(today: today) }
        }
    }
}

struct AgentNotchSummary: View {
    @ObservedObject var attention: AgentAttentionStore
    @ObservedObject var work: WorkspaceStore
    var open: () -> Void
    var openWork: () -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            if let item = attention.featured {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "\(item.event.agent) · \(item.event.label)").font(.system(size: 11, weight: .semibold)).lineLimit(1)
                        Text(verbatim: item.event.message).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    if !item.read && item.event.state != "working" { Button("Vu") { attention.acknowledge(item.id) }.font(.caption) }
                    Button("Tous (\(attention.items.count))", action: open).font(.caption)
                }
            } else { NotchWorkSummary(work: work, open: openWork) }
        }
    }
}
