import Foundation
import Supabase

/// Stato di autenticazione dell'app.
@MainActor
final class AuthViewModel: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedIn(userId: UUID)
    }

    @Published var state: State = .loading
    @Published var errorMessage: String?
    @Published var isWorking = false

    private let auth = AuthService()
    private var listenerTask: Task<Void, Never>?

    var currentUserId: UUID? {
        if case let .signedIn(userId) = state { return userId }
        return nil
    }

    init() {
        listenerTask = Task { await observeAuthChanges() }
    }

    deinit {
        listenerTask?.cancel()
    }

    private func observeAuthChanges() async {
        // Stato iniziale dalla sessione in cache.
        if let session = await auth.currentSession() {
            state = .signedIn(userId: session.user.id)
        } else {
            state = .signedOut
        }

        for await change in auth.authStateChanges {
            if let session = change.session {
                state = .signedIn(userId: session.user.id)
            } else if change.event == .signedOut {
                state = .signedOut
            }
        }
    }

    func signIn(email: String, password: String) async {
        await perform { try await self.auth.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) async {
        await perform {
            try await self.auth.signUp(email: email, password: password)
            // Se la conferma email è disattivata, l'utente è già loggato.
        }
    }

    func signOut() async {
        await perform { try await self.auth.signOut() }
    }

    private func perform(_ action: @escaping () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
