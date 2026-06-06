import Foundation
import Supabase

/// Wrapper sulle API di autenticazione di Supabase.
struct AuthService {
    private var auth: AuthClient { SupabaseManager.shared.client.auth }

    /// Sessione corrente, se presente (token valido in cache).
    func currentSession() async -> Session? {
        try? await auth.session
    }

    func signUp(email: String, password: String) async throws {
        _ = try await auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await auth.signOut()
    }

    /// Stream degli eventi di autenticazione (login/logout/refresh).
    var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { continuation in
            let task = Task {
                for await change in auth.authStateChanges {
                    continuation.yield((change.event, change.session))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
