import SwiftUI

/// Gate di autenticazione: mostra login o l'app a seconda dello stato.
struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        switch auth.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
        case .signedOut:
            AuthView()
        case .signedIn(let userId):
            MainTabView(userId: userId)
                .id(userId) // ricrea lo stato al cambio utente
        }
    }
}
