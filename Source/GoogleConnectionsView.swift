import SwiftUI

struct GoogleConnectionsView: View {
    @ObservedObject var account: GoogleAccount
    @NinoState private var confirmRevoke = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: account.identity == nil ? "person.crop.circle" : "person.crop.circle.badge.checkmark").font(.system(size: 24)).foregroundStyle(ninoAccent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(account.identity == nil ? "Ton compte Google" : "Compte connecté").font(.system(size: 19, weight: .semibold, design: .rounded))
                    Text(account.identity == nil ? (account.unavailableReason == nil ? "Choisis ton compte dans Google. Nino ne reçoit pas ton mot de passe." : "Disponible après activation par l’éditeur. Tu n’as rien à configurer dans Google Cloud.") : "\(account.identity?.name ?? "") · \(account.identity?.email ?? "")")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let reason = account.unavailableReason {
                Label("Pas encore activé", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                Text(reason).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if account.identity == nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { signIn; restore }
                    VStack(alignment: .leading, spacing: 12) { signIn; restore }
                }
                Text("Seuls ton nom et ton adresse servent à afficher ton compte ici. Ils ne sont pas envoyés à un serveur Nino. La connexion ne crée pas de compte Nino synchronisé.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "envelope").foregroundStyle(ninoAccent)
                    Text("Gmail").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(account.gmailAuthorized ? "Lecture autorisée" : "Non connecté").font(.caption).foregroundStyle(.secondary)
                }
                Text("L’autorisation Google donne accès à ta boîte en lecture. Nino charge seulement les cinq derniers aperçus, à ta demande. Aucun envoi, aucune suppression et aucun accès automatique de l’assistant.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if account.gmailAuthorized {
                    Button("Lire mes derniers mails") { account.loadMail() }.buttonStyle(NinoPrimaryStyle()).disabled(account.busy)
                } else {
                    Button("Connecter Gmail en lecture") { account.connectGmail() }.buttonStyle(NinoPrimaryStyle()).disabled(account.busy)
                }
                if !account.messages.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(account.messages) { mail in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(verbatim: mail.subject).font(.system(size: 13, weight: .medium))
                                Text(verbatim: mail.sender).font(.caption).foregroundStyle(.secondary)
                                Text(verbatim: mail.snippet).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(4)
                            }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                        }
                        Button("Effacer ces aperçus") { account.clearMail() }.buttonStyle(.plain).font(.caption)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { disconnect; revoke }
                    VStack(alignment: .leading, spacing: 12) { disconnect; revoke }
                }
            }
            if account.busy {
                HStack(spacing: 9) { ProgressView().controlSize(.small); Text(account.activity).font(.caption); if account.canCancel { Button("Annuler") { account.cancel() }.font(.caption) } }
                    .accessibilityElement(children: .combine)
            }
            if let message = account.message { Text(message).font(.caption).foregroundStyle(ninoAccent).fixedSize(horizontal: false, vertical: true) }
            if let issue = account.issue { Text(issue).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08)))
            .confirmationDialog("Révoquer l’accès Google de Nino ?", isPresented: $confirmRevoke, titleVisibility: .visible) {
                Button("Déconnecter et révoquer les accès", role: .destructive) { account.disconnect() }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Nino sera déconnecté et ses autorisations Google seront révoquées. Aucun mail ne sera supprimé.") }
    }
    private var signIn: some View {
        Button("Continuer avec Google") { account.signIn() }.buttonStyle(NinoPrimaryStyle()).disabled(!account.canConnect)
    }
    private var restore: some View {
        Button("Reprendre ma connexion") { account.restore() }.buttonStyle(.plain).font(.caption).disabled(!account.canConnect)
    }
    private var disconnect: some View {
        Button("Se déconnecter") { account.signOut() }.buttonStyle(.plain).font(.caption).disabled(account.busy)
    }
    private var revoke: some View {
        Button("Révoquer les accès Google…") { confirmRevoke = true }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary).disabled(account.busy)
    }
}
