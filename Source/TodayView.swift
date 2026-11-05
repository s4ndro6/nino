import SwiftUI

struct TodayView: View {
    @ObservedObject var today: TodayStore
    @ObservedObject var attention: AgentAttentionStore
    var attach: ((WorkChat) -> Void)? = nil
    @NinoState private var search = ""
    @NinoState private var preview: WorkChat?
    var filtered: [WorkChat] { today.chats.filter { search.isEmpty || ($0.title + " " + $0.project).localizedCaseInsensitiveContains(search) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Aujourd’hui").font(.system(size: 30, weight: .semibold))
                        Text("Tes limites, ton prochain objectif, tes chats de travail.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { Task { await today.refresh(force: true) } } label: {
                        Label(today.refreshing ? "Actualisation…" : "Actualiser", systemImage: "arrow.clockwise")
                    }.disabled(today.refreshing)
                }
                AgentAttentionView(attention: attention)
                HStack(alignment: .top, spacing: 14) {
                    QuotaCard(name: "Codex", source: "Compte Codex · serveur local", value: today.codex, loading: today.refreshing)
                    QuotaCard(name: "Claude", source: "Abonnement · Claude Code /usage", value: today.claude, loading: today.refreshing)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Une chose à terminer", systemImage: "scope").font(.headline)
                    TextField("Ex. Terminer la recette du ticket avant de passer au suivant", text: $today.focus).textFieldStyle(.roundedBorder)
                    Text("Ton objectif reste enregistré sur ce Mac.").font(.caption).foregroundStyle(.secondary)
                }.padding(18).background(ninoAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                HStack {
                    Text("Reprendre un chat").font(.title3.weight(.semibold))
                    Spacer()
                    TextField("Chercher un projet ou un chat", text: $search).textFieldStyle(.roundedBorder).frame(width: 260)
                }
                Text("Chats récents de ce Mac. Leur état d’exécution dans Codex n’est pas disponible ici.").font(.caption).foregroundStyle(.secondary)
                if let error = today.chatsError { Text(error).font(.caption).foregroundStyle(.orange) }
                if filtered.isEmpty { Text(today.refreshing ? "Lecture des chats…" : "Aucun chat à afficher.").foregroundStyle(.secondary).padding(.vertical, 12) }
                ForEach(filtered) { chat in
                    HStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.text.bubble.right").foregroundStyle(ninoAccent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(chat.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                            Text(chat.project).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(chat.updated, style: .relative).font(.caption).foregroundStyle(.secondary)
                        if let attach { Button { attach(chat) } label: { Image(systemName: "pin") }.help("Associer au travail en cours") }
                        Button("Lire") { preview = chat }.help("Lire les derniers échanges sans quitter Nino")
                        Button { today.copyTitle(chat) } label: { Image(systemName: "doc.on.doc") }.help("Copier le titre pour retrouver ce chat dans Codex")
                    }.padding(13).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }
                if today.copied { Text("Titre copié : colle-le dans la recherche Codex.").font(.caption).foregroundStyle(ninoAccent) }
                HStack {
                    Link("Ouvrir les limites Claude", destination: URL(string: "https://claude.ai/settings/usage")!)
                    Spacer()
                    Text("Relevés toutes les 5 min lorsque cette page est ouverte. Aucun message envoyé aux modèles.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(28)
        }.sheet(item: $preview) { ChatPreview(chat: $0) }.task {
            while !Task.isCancelled {
                await today.refresh()
                do { try await Task.sleep(for: .seconds(300)) } catch { break }
            }
        }
    }
}
struct QuotaCard: View {
    let name: String
    let source: String
    let value: QuotaSnapshot
    let loading: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(name).font(.title2.weight(.semibold)); Spacer(); Image(systemName: "chart.bar.xaxis").foregroundStyle(ninoAccent) }
            Text(source).font(.caption).foregroundStyle(.secondary)
            if value.windows.isEmpty { Text(loading ? "Lecture…" : "Indisponible").font(.title3).foregroundStyle(.secondary) }
            ForEach(Array(value.windows.enumerated()), id: \.offset) { _, window in
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text(window.id); Spacer(); Text("\(window.remaining) % restants").monospacedDigit().bold() }.font(.system(size: 12))
                    ProgressView(value: window.used, total: 100).tint(window.used >= 90 ? .orange : ninoAccent).accessibilityLabel("\(window.id), \(Int(window.used)) pour cent utilisés")
                    if let reset = window.reset {
                        if reset > Date() { Text("Remise à zéro : \(reset.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                        else { Text("Échéance passée · actualiser le relevé").font(.caption).foregroundStyle(.orange) }
                    }
                }
            }
            if let measured = value.measured {
                Text("Relevé : \(measured.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
            }
            if let error = value.error {
                Text((value.windows.isEmpty ? "" : "Dernier relevé conservé. ") + error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
    }
}
struct TodayGlance: View {
    @ObservedObject var today: TodayStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
        HStack(spacing: 8) {
            Text("C \(amount(today.codex, now: context.date))")
            Text("A \(amount(today.claude, now: context.date))")
        }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(ninoAccent)
            .help("Dernier relevé : Codex / Claude, quota restant. Ouvrir Aujourd’hui pour les dates et les fenêtres.")
    }
    }
    func amount(_ snapshot: QuotaSnapshot, now: Date) -> String {
        guard snapshot.error == nil, let date = snapshot.measured, now.timeIntervalSince(date) < 600,
              let window = snapshot.windows.first, window.reset.map({ $0 > now }) ?? true else { return "—" }
        return "\(window.remaining)%"
    }
}
