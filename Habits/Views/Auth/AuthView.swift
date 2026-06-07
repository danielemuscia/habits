import SwiftUI
import AuthenticationServices
import CryptoKit

/// Schermata di login / registrazione.
struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    /// Nonce in chiaro generato per la richiesta Apple corrente; serve poi a
    /// Supabase per validare l'identity token.
    @State private var appleNonce: String?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !auth.isWorking
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Habits")
                    .font(.largeTitle.bold())
                Text("Costruisci abitudini, un giorno alla volta.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    if isSignUp {
                        await auth.signUp(email: email, password: password)
                    } else {
                        await auth.signIn(email: email, password: password)
                    }
                }
            } label: {
                Group {
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(isSignUp ? "Registrati" : "Accedi").bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSubmit ? Color.green : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSubmit)

            HStack {
                VStack { Divider() }
                Text("oppure")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                VStack { Divider() }
            }

            SignInWithAppleButton(.continue) { request in
                let nonce = Self.randomNonceString()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = Self.sha256(nonce)
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(auth.isWorking)

            Button {
                withAnimation { isSignUp.toggle() }
                auth.errorMessage = nil
            } label: {
                Text(isSignUp ? "Hai già un account? Accedi" : "Non hai un account? Registrati")
                    .font(.footnote)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    /// Estrae l'identity token dal risultato Apple e lo passa a Supabase.
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else {
                auth.errorMessage = "Accesso con Apple non riuscito."
                return
            }
            Task { await auth.signInWithApple(idToken: idToken, nonce: nonce) }
        case .failure(let error):
            // L'annullamento da parte dell'utente non è un errore da mostrare.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            auth.errorMessage = error.localizedDescription
        }
    }

    /// Nonce casuale crittograficamente sicuro (inviato in chiaro a Supabase).
    private static func randomNonceString(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes fallito: \(status)")
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA256 del nonce, inviato ad Apple nella richiesta.
    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
