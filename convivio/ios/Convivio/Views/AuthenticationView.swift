//
//  AuthenticationView.swift
//  Convivio
//
//  Schermata di login e registrazione
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Convivio")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("La tua cantina personale\ncon intelligenza artificiale")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Auth buttons
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authManager.prepareAppleSignIn()
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                Task {
                                    await authManager.handleAppleSignIn(authorization: authorization)
                                }
                            case .failure(let error):
                                print("Apple Sign In failed: \(error)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(8)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("oppure")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // Email sign in
                    Button {
                        showingSignUp = false
                    } label: {
                        Label("Accedi con email", systemImage: "envelope")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    
                    // Sign up
                    Button {
                        showingSignUp = true
                    } label: {
                        Text("Non hai un account? Registrati")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .sheet(isPresented: .constant(email.isEmpty ? false : true)) {
                EmailAuthSheet(
                    isSignUp: $showingSignUp,
                    email: $email,
                    password: $password,
                    displayName: $displayName,
                    isLoading: $isLoading
                ) {
                    Task {
                        isLoading = true
                        if showingSignUp {
                            await authManager.signUpWithEmail(email: email, password: password, displayName: displayName)
                        } else {
                            await authManager.signInWithEmail(email: email, password: password)
                        }
                        isLoading = false
                    }
                }
            }
            .alert(item: $authManager.error) { error in
                Alert(
                    title: Text("Errore"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// MARK: - Email Auth Sheet

struct EmailAuthSheet: View {
    @Binding var isSignUp: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var displayName: String
    @Binding var isLoading: Bool
    let onSubmit: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if isSignUp {
                    Section {
                        TextField("Nome", text: $displayName)
                            .textContentType(.name)
                            .focused($focusedField, equals: .name)
                    }
                }
                
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)
                    
                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                }
                
                Section {
                    Button {
                        onSubmit()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Registrati" : "Accedi")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
                
                if !isSignUp {
                    Section {
                        Button("Password dimenticata?") {
                            // TODO: Password reset
                        }
                        .font(.subheadline)
                    }
                }
            }
            .navigationTitle(isSignUp ? "Registrati" : "Accedi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSignUp ? "Accedi invece" : "Registrati invece") {
                        isSignUp.toggle()
                    }
                    .font(.subheadline)
                }
            }
            .onAppear {
                focusedField = isSignUp ? .name : .email
            }
        }
    }
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        let nameValid = !isSignUp || !displayName.isEmpty
        return emailValid && passwordValid && nameValid
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthManager.shared)
}
