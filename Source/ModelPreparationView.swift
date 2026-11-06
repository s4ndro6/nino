import SwiftUI

struct ModelPreparationView: View {
    @ObservedObject var store: NinoStore
    @ObservedObject var download: TranscriptionModelDownload
    @NinoState private var selected = "base"
    @NinoState private var skipped = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ta voix, sur ton Mac", systemImage: "waveform").font(.headline)
            Text("Enregistrer et réécouter une note ne demande aucun modèle. Pour transformer la parole en texte, choisis un modèle local ou passe cette étape.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if store.transcriptionReady {
                Label("Transcription prête · \(store.model)", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(ninoAccent)
            } else if !TranscriptionRuntime.ready {
                Text("Le moteur intégré manque dans cette installation. Installe la dernière version complète de Nino.").font(.caption).foregroundStyle(.orange)
            }
            if download.running {
                ProgressView(value: download.progress).tint(ninoAccent)
                HStack {
                    Text("\(Int(download.progress * 100)) %").monospacedDigit()
                    Spacer()
                    Button("Annuler le téléchargement") { download.cancel() }
                }.font(.caption)
            } else {
                Picker("Modèle multilingue", selection: $selected) {
                    ForEach(LocalWhisperModel.choices) { choice in Text(choice.title).tag(choice.id) }
                }.font(.caption)
                Text("Équilibré : meilleur point de départ. Léger : plus rapide, moins précis. Français et autres langues inclus.").font(.caption2).foregroundStyle(.secondary)
                HStack {
                    Button("Télécharger le modèle") {
                        skipped = false
                        store.downloadModel(LocalWhisperModel.choices.first { $0.id == selected } ?? .base)
                    }.buttonStyle(.borderedProminent).tint(ninoAccent).disabled(!store.canConfigure || !TranscriptionRuntime.ready)
                    Button("Plus tard") { skipped = true }.buttonStyle(.bordered)
                }.font(.caption)
            }
            if let message = download.message { Text(message).font(.caption).foregroundStyle(ninoAccent).fixedSize(horizontal: false, vertical: true) }
            if skipped { Text("Tu peux continuer sans modèle. Reviens dans Connexions et préparation quand tu voudras transcrire.").font(.caption).foregroundStyle(.secondary) }
            Text("Téléchargement depuis Hugging Face, uniquement avec ce bouton. L’audio reste sur ton disque. Le modèle est conservé après les mises à jour.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(ninoAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
