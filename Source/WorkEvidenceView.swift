import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct WorkEvidenceView: View {
    @ObservedObject var evidence: WorkEvidenceStore
    let projectID: UUID
    let projectTitle: String
    @NinoState private var repositoryURL = ""
    @NinoState private var version = ""
    @NinoState private var timecode = ""
    @NinoState private var author = ""
    @NinoState private var feedbackText = ""
    @NinoState private var sourceURL = ""
    @NinoState private var editorVisible = false
    @NinoState private var localIssue: String?
    @NinoState private var exportNotice: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Preuves & retours", systemImage: "checkmark.bubble").font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Button(editorVisible ? "Fermer" : "Ajouter un retour", systemImage: editorVisible ? "xmark" : "plus") { editorVisible.toggle() }.disabled(!evidence.ready)
            }
            Text("Un retour sur une vidéo, une correction à livrer, un relevé de CI : garde la demande et son résultat dans cette fiche.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let issue = localIssue ?? evidence.issue { Label(issue, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
            if editorVisible { editor }
            feedbackList
            Divider()
            github
        }
        .padding(20).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        .onAppear { repositoryURL = evidence.snapshot(for: projectID)?.repositoryURL ?? "" }
        .onChange(of: projectID) { _, _ in
            repositoryURL = evidence.snapshot(for: projectID)?.repositoryURL ?? ""
            version = ""; timecode = ""; author = ""; feedbackText = ""; sourceURL = ""; editorVisible = false; localIssue = nil; exportNotice = nil
        }
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack { TextField("Version · ex. V03", text: $version); TextField("Timecode · 01:23.500", text: $timecode); TextField("Auteur", text: $author) }
                VStack { TextField("Version · ex. V03", text: $version); TextField("Timecode · 01:23.500", text: $timecode); TextField("Auteur", text: $author) }
            }.textFieldStyle(.roundedBorder)
            TextField("Ce qu’il faut corriger ou vérifier…", text: $feedbackText, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
            TextField("Lien source HTTP(S), facultatif", text: $sourceURL).textFieldStyle(.roundedBorder)
            Text("Timecode en secondes, pas en images. Le retour reste local ; Nino n’écrit pas dans ton logiciel de montage.").font(.caption2).foregroundStyle(.secondary)
            Button("Enregistrer le retour") { addFeedback() }.buttonStyle(NinoPrimaryStyle())
        }
    }
    private var feedbackList: some View {
        let items = evidence.feedback(for: projectID)
        return VStack(alignment: .leading, spacing: 14) {
            if items.isEmpty { Text("Aucun retour pour cette fiche.").font(.caption).foregroundStyle(.secondary) }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top) {
                        Text([item.version, item.timecodeMilliseconds == nil ? "" : EvidenceValidation.timecode(item.timecodeMilliseconds), item.author].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(ninoAccent)
                        Spacer()
                        Menu(item.status.label) {
                            ForEach(FeedbackStatus.allCases) { status in Button(status.label) { evidence.setStatus(status, id: item.id, projectID: projectID) } }
                        }.font(.caption).fixedSize()
                    }
                    Text(item.text).font(.system(size: 13)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("Déclaré · \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(.secondary)
                        Spacer()
                        if let url = EvidenceValidation.webURL(item.sourceURL) { Link("Source non vérifiée ↗", destination: url) }
                    }.font(.caption2)
                }.padding(.vertical, 5)
                Divider()
            }
            if !items.isEmpty {
                HStack {
                    Button("Exporter Markdown", systemImage: "square.and.arrow.up") { export(csv: false) }
                    Button("CSV") { export(csv: true) }
                }.font(.caption)
                Text("Exports de retours lisibles et partageables ; aucun import natif Premiere ou DaVinci.").font(.caption2).foregroundStyle(.secondary)
            }
            if let exportNotice { Text(exportNotice).font(.caption).foregroundStyle(ninoAccent) }
        }
    }
    private var github: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("GitHub Actions · dépôt public", systemImage: "arrow.triangle.branch").font(.system(size: 14, weight: .medium))
            Text("Lecture à ta demande des cinq dernières exécutions. Aucun jeton, aucun lancement de workflow. L’URL du dépôt est envoyée à GitHub.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField("https://github.com/organisation/depot", text: $repositoryURL).textFieldStyle(.roundedBorder)
                Button { let url = repositoryURL; let id = projectID; Task { await evidence.refresh(repositoryURL: url, projectID: id) } } label: {
                    if evidence.refreshingProjectID == projectID { ProgressView().controlSize(.small) } else { Label("Relever", systemImage: "arrow.clockwise") }
                }.disabled(!evidence.ready || evidence.refreshingProjectID != nil || repositoryURL.isEmpty)
            }
            if let snapshot = evidence.snapshot(for: projectID) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text("\(snapshot.isStale(at: context.date) ? "Relevé ancien · à actualiser" : "Dernier relevé GitHub") · \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(snapshot.isStale(at: context.date) ? .orange : .secondary)
                }
                Text(snapshot.repositoryURL).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                if snapshot.runs.isEmpty { Text("Aucune exécution de workflow renvoyée par GitHub.").font(.caption) }
                ForEach(snapshot.runs) { run in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(run.name).font(.system(size: 13, weight: .medium)); Spacer(); Text(run.label).font(.caption).foregroundStyle(run.conclusion == "success" ? ninoAccent : .secondary) }
                        Text("\(run.branch) · \(String(run.sha.prefix(10))) · \(run.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
                        if let url = EvidenceValidation.webURL(run.url) { Link("Voir l’exécution GitHub ↗", destination: url).font(.caption) }
                    }.padding(.vertical, 5)
                }
                Text("Source : API GitHub. Un workflow réussi ne prouve pas à lui seul que les tests couvrent le produit ni que le site est déployé.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func addFeedback() {
        do {
            let milliseconds = try EvidenceValidation.milliseconds(timecode)
            let item = WorkFeedback(projectID: projectID, version: version.trimmingCharacters(in: .whitespacesAndNewlines), timecodeMilliseconds: milliseconds, author: author.trimmingCharacters(in: .whitespacesAndNewlines), text: feedbackText, sourceURL: sourceURL.trimmingCharacters(in: .whitespacesAndNewlines))
            try item.validate()
            if evidence.add(item) { feedbackText = ""; timecode = ""; sourceURL = ""; localIssue = nil; editorVisible = false }
        } catch { localIssue = error.localizedDescription }
    }
    private func export(csv: Bool) {
        let panel = NSSavePanel(); panel.allowedContentTypes = csv ? [.commaSeparatedText] : [.plainText]
        panel.nameFieldStringValue = csv ? "retours-nino.csv" : "retours-nino.md"
        let items = evidence.feedback(for: projectID)
        let content = csv ? FeedbackExport.csv(items) : FeedbackExport.markdown(items, title: projectTitle)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do { try content.write(to: url, atomically: true, encoding: .utf8); exportNotice = "Export enregistré : \(url.lastPathComponent)"; localIssue = nil }
            catch { localIssue = "Export impossible : \(error.localizedDescription)" }
        }
    }
}
