import Foundation

/// Local, editable starting points. Choosing a template never contacts another application.
struct WorkTemplate: Identifiable {
    let id: String
    let title: String
    let detail: String
    let software: String
    let brief: String
    let steps: [String]
    func project(profile: WorkProfile) -> WorkProject {
        var project = WorkProject()
        project.profileID = profile.rawValue; project.workflowID = id
        project.title = title; project.brief = brief
        project.tasks = steps.map { WorkStep(title: $0) }; project.nextAction = steps.first ?? ""
        return project
    }
}
extension WorkProfile {
    var isDevelopment: Bool { self == .developer || self == .vibeCoder }
    var studioLabel: String {
        switch self {
        case .editor: return "TON ATELIER VIDÉO"
        case .designer: return "TON ATELIER IMAGE"
        case .creator: return "TON STUDIO DE CONTENU"
        case .communication: return "TON ESPACE COMMUNICATION"
        case .developer, .vibeCoder: return "TON ATELIER DE DÉVELOPPEMENT"
        case .versatile: return "TON ESPACE PERSONNEL"
        }
    }
    var companionApps: String {
        switch self {
        case .editor: return "DaVinci Resolve · Premiere Pro"
        case .designer: return "Photoshop · Illustrator · Figma"
        case .creator: return "Prompteur · scripts · sous-titres"
        case .communication: return "Briefs · appels · retours"
        case .developer, .vibeCoder: return "Codex · Claude · Git · MCP"
        case .versatile: return "Notes · documents · concentration"
        }
    }
    var workflows: [WorkTemplate] {
        switch self {
        case .editor:
            return [
                WorkTemplate(id: "interview", title: "Dérusher une interview", detail: "Repère les passages utiles, puis prépare les sous-titres.", software: "DaVinci / Premiere · fichiers SRT", brief: "Sujet :\nMessage à conserver :\nDurée cible :\nLangue :\nPassages à garder (avec timecodes) :\nPassages à retirer :", steps: ["Importer une copie du média dans Nino", "Transcrire et corriger les noms propres", "Noter les passages et leurs timecodes", "Exporter le SRT et l’importer dans le logiciel de montage", "Vérifier le calage dans la timeline"]),
                WorkTemplate(id: "video-delivery", title: "Préparer une livraison vidéo", detail: "Un endroit pour les versions, les retours et le contrôle final.", software: "DaVinci / Premiere · checklist", brief: "Projet :\nVersion en cours :\nFormat / résolution / cadence :\nDurée :\nRetours client :\nLien de visionnage :\nLivrables attendus :", steps: ["Rassembler et numéroter les retours", "Appliquer les corrections dans le montage", "Contrôler son, titres et sous-titres", "Exporter les formats demandés", "Regarder le fichier exporté en entier"])
            ]
        case .designer:
            return [
                WorkTemplate(id: "visual-brief", title: "Cadrer une création visuelle", detail: "Objectif, références et contraintes avant d’ouvrir le document.", software: "Photoshop / Illustrator · brief", brief: "Objectif :\nPublic :\nMessage principal :\nSupports et dimensions :\nTextes obligatoires :\nRéférences :\nContraintes de marque :\nCritères de validation :", steps: ["Clarifier le message et le support", "Rassembler les références dans la fiche", "Préparer deux pistes dans mon outil", "Consigner les retours pour chaque piste", "Faire valider la direction"]),
                WorkTemplate(id: "visual-delivery", title: "Décliner et livrer les visuels", detail: "Suis les formats et les retours sans perdre une variante.", software: "Photoshop / Illustrator · checklist", brief: "Création source :\nListe des formats :\nNoms des variantes :\nTextes à adapter :\nRetours ouverts :\nDestination des exports :", steps: ["Lister les variantes et dimensions", "Décliner dans mon logiciel", "Relire les textes et vérifier les marges", "Contrôler chaque export à sa taille réelle", "Rassembler les sources et les livrables"])
            ]
        case .creator:
            return [WorkTemplate(id: "short-video", title: "Préparer une vidéo courte", detail: "De l’accroche au script à lire dans le prompteur.", software: "Nino · script et prompteur", brief: "Sujet :\nPublic :\nAccroche :\nUne idée principale :\nExemple concret :\nConclusion :\nDurée cible :", steps: ["Dicter ou écrire mon idée", "Préparer un script avec mon assistant", "Relire et raccourcir le script", "Le charger dans le prompteur", "Tourner puis vérifier les sous-titres"])]
        case .communication:
            return [WorkTemplate(id: "campaign", title: "Préparer une campagne", detail: "Garde le message, les supports et les validations ensemble.", software: "Nino · brief et suivi", brief: "Objectif :\nPublic :\nMessage :\nCanaux :\nLivrables :\nÉchéance :\nPersonnes qui valident :", steps: ["Valider l’objectif et le public", "Lister les supports à produire", "Préparer le brief et les messages", "Rassembler les retours", "Vérifier chaque livrable avant diffusion"])]
        case .developer:
            return [WorkTemplate(id: "dev-ticket", title: "Livrer un ticket", detail: "Brief, branche, agent et recette dans une seule fiche.", software: "Git · Codex / Claude · MCP", brief: "Problème :\nComportement attendu :\nSource de vérité :\nPérimètre :\nBranche :\nEnvironnement à vérifier :\nDéfinition de fini :", steps: ["Reproduire le problème", "Vérifier le dépôt et la branche", "Implémenter la correction", "Tester le comportement et les régressions", "Préparer les preuves de recette"])]
        case .vibeCoder:
            return [WorkTemplate(id: "build-feature", title: "Construire une fonctionnalité", detail: "Un besoin précis, des étapes courtes, un résultat à vérifier.", software: "Assistant · Codex / Claude · MCP", brief: "Pour qui :\nProblème à résoudre :\nParcours attendu :\nCe qui est hors périmètre :\nComment vérifier que ça fonctionne :", steps: ["Décrire un exemple concret", "Faire préciser les étapes par mon assistant", "Confier une étape à mon outil de code", "Essayer le résultat moi-même", "Noter les limites et la prochaine action"])]
        case .versatile:
            return [WorkTemplate(id: "personal-task", title: "Avancer sur une idée", detail: "Quelques mots et une première action suffisent.", software: "Nino · notes et focus", brief: "Ce que je veux faire :\nPourquoi :\nCe que j’ai déjà :\nCe qu’il me manque :", steps: ["Écrire le résultat attendu", "Rassembler mes références", "Choisir une action de moins de 25 minutes", "Faire le point après mon focus"])]
        }
    }
}

extension WorkProject {
    var markdown: String {
        "# \(title)\n\n## Brief\n\n\(brief)\n\n## Prochaine action\n\n\(nextAction)\n\n## Étapes\n\n"
        + tasks.map { "- [\($0.done ? "x" : " ")] \($0.title)" }.joined(separator: "\n")
        + "\n\n## Références\n\n" + links.map { "- \($0.label) : \($0.url)" }.joined(separator: "\n") + "\n"
    }
}
