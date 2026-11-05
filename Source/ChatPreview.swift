import SwiftUI

struct ChatExcerpt: Identifiable {
    let id: String
    let author: String
    let text: String
    let final: Bool
}
extension DashboardReader {
    static func chatExcerpts(_ id: String) throws -> [ChatExcerpt] {
        guard UUID(uuidString: id) != nil, let path = executable("codex") else { throw NinoError("Chat Codex indisponible.") }
        let bridge = try DashboardProcess(path: path, arguments: ["app-server"], timeout: 20)
        defer { bridge.close() }
        try bridge.send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "nino", "version": "0.5.0"]]])
        _ = try bridge.response(1); try bridge.send(["method": "initialized"])
        var cursor: String?
        var messages: [ChatExcerpt] = []
        for page in 0..<4 {
            var params: [String: Any] = ["threadId": id, "limit": 20, "sortDirection": "desc"]
            if let cursor { params["cursor"] = cursor }
            try bridge.send(["id": page + 2, "method": "thread/items/list", "params": params])
            let result = try bridge.response(page + 2)
            for entry in result["data"] as? [[String: Any]] ?? [] {
                guard let item = entry["item"] as? [String: Any], let type = item["type"] as? String else { continue }
                var text = ""
                if type == "agentMessage" { text = item["text"] as? String ?? "" }
                else if type == "userMessage" {
                    text = (item["content"] as? [[String: Any]] ?? []).compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined(separator: "\n")
                }
                guard !text.isEmpty else { continue }
                messages.append(ChatExcerpt(id: item["id"] as? String ?? UUID().uuidString, author: type == "agentMessage" ? "Codex" : "Toi", text: String(text.prefix(12000)), final: item["phase"] as? String == "final_answer"))
                if messages.count == 6 { break }
            }
            cursor = result["nextCursor"] as? String
            if messages.count == 6 || cursor == nil { break }
        }
        return messages
    }
}
struct ChatPreview: View {
    let chat: WorkChat
    @Environment(\.dismiss) private var dismiss
    @NinoState private var excerpts: [ChatExcerpt] = []
    @NinoState private var loading = false
    @NinoState private var error: String?
    @NinoState private var updated: Date?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) { Text(chat.title).font(.title3.bold()).lineLimit(2); Text(chat.project).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Actualiser", systemImage: "arrow.clockwise") { Task { await refresh() } }.disabled(loading)
                Button("Fermer") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Derniers messages enregistrés · lecture seule. Le statut d’exécution en direct n’est pas disponible.").font(.caption).foregroundStyle(.secondary)
            if let updated { Text("Lu à \(updated.formatted(date: .omitted, time: .standard))").font(.caption2).foregroundStyle(.secondary) }
            if loading { ProgressView("Lecture du chat…").controlSize(.small) }
            if let error { Text(error).foregroundStyle(.orange).font(.caption) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if excerpts.isEmpty && !loading { Text("Aucun message lisible parmi les 80 derniers éléments. Actualise après la prochaine réponse.").foregroundStyle(.secondary) }
                    ForEach(excerpts) { excerpt in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(excerpt.author + (excerpt.final ? " · réponse finale enregistrée" : "")).font(.headline).foregroundStyle(ninoAccent)
                            Text(excerpt.text).font(.system(size: 13)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(16).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }.padding(24).frame(width: 780, height: 600).preferredColorScheme(.dark).task { await refresh() }
    }
    func refresh() async {
        guard !loading else { return }
        loading = true; error = nil
        let id = chat.id
        let result = await Task.detached { Result { try DashboardReader.chatExcerpts(id) } }.value
        switch result {
        case .success(let values): excerpts = values; updated = Date()
        case .failure(let failure): error = failure.localizedDescription
        }
        loading = false
    }
}
