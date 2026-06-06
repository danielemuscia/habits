import SwiftUI

/// Schermata di login / registrazione.
struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""

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
}
