import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var showResetPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.purple.gradient)

                        Text("Convivio")
                            .font(.largeTitle.bold())

                        Text("La tua cantina personale")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)

                    // Form
                    VStack(spacing: 16) {
                        if isSignUp {
                            TextField("Nome", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .autocapitalization(.words)
                        }

                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isSignUp ? .newPassword : .password)
                    }
                    .padding(.horizontal, 32)

                    // Error
                    if let error = authManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 32)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            Task { await authenticate() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Registrati" : "Accedi")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.purple.gradient)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || !isFormValid)

                        Button {
                            withAnimation {
                                isSignUp.toggle()
                                authManager.error = nil
                            }
                        } label: {
                            Text(isSignUp
                                 ? "Hai già un account? Accedi"
                                 : "Non hai un account? Registrati")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                        }

                        if !isSignUp {
                            Button {
                                showResetPassword = true
                            } label: {
                                Text("Password dimenticata?")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)

                        Button {
                            Task { await signInAnonymously() }
                        } label: {
                            HStack {
                                Image(systemName: "person.fill.questionmark")
                                Text("Continua senza account")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6

        if isSignUp {
            return emailValid && passwordValid && !displayName.isEmpty
        }
        return emailValid && passwordValid
    }

    private func authenticate() async {
        isLoading = true

        do {
            if isSignUp {
                try await authManager.signUpWithEmail(
                    email: email,
                    password: password,
                    displayName: displayName
                )
            } else {
                try await authManager.signInWithEmail(
                    email: email,
                    password: password
                )
            }
        } catch {
            // Error is handled by AuthManager
        }

        isLoading = false
    }

    private func signInAnonymously() async {
        isLoading = true

        do {
            try await authManager.signInAnonymously()
        } catch {
            // Error is handled by AuthManager
        }

        isLoading = false
    }
}

struct ResetPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isLoading = false
    @State private var isSent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isSent {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Email inviata!")
                            .font(.title2.bold())

                        Text("Controlla la tua casella di posta per reimpostare la password.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Text("Inserisci la tua email per ricevere il link di reset password.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)

                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()

                    if let error = authManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task {
                            isLoading = true
                            do {
                                try await authManager.sendPasswordReset(email: email)
                                isSent = true
                            } catch {
                                // Error handled by AuthManager
                            }
                            isLoading = false
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Invia email")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.purple.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !email.contains("@"))
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthManager.shared)
}
