import Foundation

/// Profiles configure existing tools; they never grant permissions or connect accounts.
enum WorkProfile: String, CaseIterable, Identifiable {
    case developer, vibeCoder, creator, editor, designer, communication, versatile
    var id: String { rawValue }
    var title: String {
        switch self {
        case .developer: return "Développeur"
        case .vibeCoder: return "Vibe codeur"
        case .creator: return "Créateur de contenu"
        case .editor: return "Montage vidéo"
        case .designer: return "Design & image"
        case .communication: return "Communication"
        case .versatile: return "Un peu de tout"
        }
    }
    var icon: String {
        switch self {
        case .developer: return "curlybraces"
        case .vibeCoder: return "sparkles"
        case .creator: return "camera"
        case .editor: return "film"
        case .designer: return "paintpalette"
        case .communication: return "bubble.left.and.bubble.right"
        case .versatile: return "square.grid.2x2"
        }
    }
    var detail: String {
        switch self {
        case .developer: return "Tes quotas, tes chats et du temps pour coder."
        case .vibeCoder: return "Dicte tes idées, retrouve tes échanges, avance par étapes."
        case .creator: return "De l’idée parlée au script prêt à lire."
        case .editor: return "Du dérushage à la livraison, garde chaque retour en vue."
        case .designer: return "Un brief clair, des variantes suivies, des exports vérifiés."
        case .communication: return "Garde une trace des échanges et prépare tes prises de parole."
        case .versatile: return "Capture une idée, retrouve un document, concentre-toi."
        }
    }
    var focusMinutes: Double { switch self { case .developer, .editor, .designer: return 45; case .communication: return 15; default: return 25 } }
    var readingSpeed: Double { switch self { case .creator: return 135; case .communication: return 115; default: return 125 } }
    var navigation: [String] {
        switch self {
        case .developer, .vibeCoder: return ["today", "timer", "library", "call", "prompter"]
        case .creator: return ["prompter", "library", "timer", "call", "today"]
        case .editor: return ["library", "timer", "prompter", "call", "today"]
        case .designer: return ["library", "timer", "call", "prompter", "today"]
        case .communication: return ["call", "library", "prompter", "timer", "today"]
        case .versatile: return ["library", "timer", "today", "call", "prompter"]
        }
    }
    var tools: [String] {
        switch self {
        case .developer: return ["today","dictate","timer","call"]
        case .vibeCoder: return ["dictate","today","timer","documents"]
        case .creator: return ["voice","prompter","import","documents"]
        case .editor: return ["import","documents","timer","voice"]
        case .designer: return ["documents","voice","timer","call"]
        case .communication: return ["call","dictate","prompter","documents"]
        case .versatile: return ["voice","documents","timer","import"]
        }
    }
}

enum CompanionEnergy: String, CaseIterable, Identifiable {
    case calm, lively
    var id: String { rawValue }
    var title: String { self == .calm ? "Discret" : "Joueur" }
    var detail: String { self == .calm ? "Des gestes doux, sans promenade." : "Il se promène et réagit à ton activité." }
}
