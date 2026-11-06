import SwiftUI

@MainActor final class IntelligenceSettings: ObservableObject {
    @Published var provider: IntelligenceProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: "intelligence.provider")
            model = defaults.string(forKey: "intelligence.model." + provider.rawValue) ?? ""
            models = []; message = nil
        }
    }
    @Published var model: String { didSet { defaults.set(model, forKey: "intelligence.model." + provider.rawValue) } }
    @Published var models: [String] = []
    @Published var message: String?
    @Published var checking = false
    @Published var generating = false
    private let defaults: UserDefaults
    let keys: IntelligenceKeychain
    private var checkTask: Task<Void, Never>?
    init(defaults: UserDefaults = .standard, keys: IntelligenceKeychain = IntelligenceKeychain()) {
        self.defaults = defaults; self.keys = keys
        let provider = IntelligenceProvider(rawValue: defaults.string(forKey: "intelligence.provider") ?? "") ?? .apple
        self.provider = provider; self.model = defaults.string(forKey: "intelligence.model." + provider.rawValue) ?? ""
    }
    var busy: Bool { checking || generating }
    func save(_ key: String) -> Bool {
        guard !busy else { return false }
        do { try keys.save(key.trimmingCharacters(in: .whitespacesAndNewlines), for: provider); message = "Clé enregistrée dans le Trousseau. Vérifie la connexion pour charger les modèles."; return true }
        catch { message = error.localizedDescription; return false }
    }
    func removeKey() {
        guard !busy else { return }
        do { try keys.remove(provider); models = []; message = "Clé retirée du Trousseau de Nino. Pour la révoquer chez le fournisseur, utilise son tableau de bord." }
        catch { message = error.localizedDescription }
    }
    func verify() {
        guard !busy, provider != .apple else { return }
        let selected = provider; checking = true; message = nil
        checkTask = Task {
            defer { checking = false }
            do {
                guard let key = try keys.read(selected) else { throw NinoError("Enregistre d’abord ta clé API dans Nino.") }
                let request = try IntelligenceAPI.request(provider: selected, key: key)
                let data = try await IntelligenceAPI().send(request)
                let result = try IntelligenceAPI.models(from: data, provider: selected)
                try Task.checkCancellation()
                models = result
                message = "Clé acceptée · \(result.count) modèles proposés. Choisis un modèle de texte compatible. Ce test ne génère aucun texte et ne vérifie pas tes crédits de génération."
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
        }
    }
    func cancelCheck() { checkTask?.cancel() }
}

struct IntelligenceConnectionView: View {
    @ObservedObject var settings: IntelligenceSettings
    @NinoState private var key = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Une IA pour tes brouillons", systemImage: "sparkles").font(.title3.weight(.semibold))
            Text("Choisis le moteur de l’assistant. Les enregistrements et les réponses automatiques d’appel restent locaux.").font(.caption).foregroundStyle(.secondary)
            Picker("Fournisseur", selection: $settings.provider) {
                ForEach(IntelligenceProvider.allCases) { Text($0.title).tag($0) }
            }.disabled(settings.busy)
            if settings.provider != .apple {
                Text("Seul le texte que tu envoies depuis l’assistant est transmis à \(settings.provider == .openai ? "OpenAI" : "Anthropic"). La facturation API est séparée de ton abonnement ChatGPT ou Claude. Nino n’inclut pas de crédits.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                SecureField("Coller une clé API pour l’enregistrer ou la remplacer", text: $key).textFieldStyle(.roundedBorder).disabled(settings.busy)
                ViewThatFits {
                    HStack { keyActions }
                    VStack(alignment: .leading) { keyActions }
                }.disabled(settings.busy)
                HStack {
                    Button(settings.checking ? "Vérification…" : "Vérifier la clé et charger les modèles") { settings.verify() }.disabled(settings.busy)
                    if settings.checking { Button("Annuler") { settings.cancelCheck() } }
                }
                if !settings.models.isEmpty {
                    Picker("Modèles retournés par l’API", selection: $settings.model) {
                        Text("Choisir…").tag("")
                        if !settings.model.isEmpty && !settings.models.contains(settings.model) { Text(settings.model).tag(settings.model) }
                        ForEach(settings.models, id: \.self) { Text($0).tag($0) }
                    }.disabled(settings.busy)
                }
                TextField("Identifiant du modèle de texte", text: $settings.model).textFieldStyle(.roundedBorder).disabled(settings.busy)
                Text("Tu peux saisir l’identifiant si ton modèle n’apparaît pas dans la liste. La compatibilité sera vérifiée lors de ta demande. Clé conservée uniquement dans le Trousseau de ce Mac.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Aucun compte ni clé nécessaire. macOS 26 et Apple Intelligence activé sont requis pour les réponses locales ; la transcription Whisper reste indépendante.").font(.caption).foregroundStyle(.secondary)
            }
            if let message = settings.message { Text(message).font(.caption).foregroundStyle(ninoAccent).textSelection(.enabled) }
        }.padding(20).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: settings.provider) { _, _ in key = "" }
            .onDisappear { key = "" }
    }
    @ViewBuilder private var keyActions: some View {
        Button("Enregistrer la clé") { if settings.save(key) { key = "" } }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Retirer la clé de Nino", role: .destructive) { settings.removeKey(); key = "" }
        Link("Obtenir une clé API ↗", destination: settings.provider.keyURL)
    }
}
