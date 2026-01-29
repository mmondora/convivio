import Foundation
import FirebaseAuth
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var error: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isLoading = false
            }
        }
    }

    // MARK: - Anonymous Sign In

    func signInAnonymously() async throws {
        isLoading = true
        error = nil

        do {
            let result = try await Auth.auth().signInAnonymously()
            currentUser = result.user
            isAuthenticated = true
        } catch {
            self.error = "Errore accesso anonimo: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    // MARK: - Sign In

    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = result.user
            isAuthenticated = true
        } catch {
            self.error = mapAuthError(error)
            throw error
        }

        isLoading = false
    }

    // MARK: - Sign Up

    func signUpWithEmail(email: String, password: String, displayName: String) async throws {
        isLoading = true
        error = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            currentUser = result.user
            isAuthenticated = true
        } catch {
            self.error = mapAuthError(error)
            throw error
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            self.error = "Errore durante il logout"
            throw error
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            self.error = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }

        do {
            try await user.delete()
            currentUser = nil
            isAuthenticated = false
        } catch {
            self.error = mapAuthError(error)
            throw error
        }
    }

    // MARK: - Error Mapping

    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Password errata"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Email non valida"
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Email già in uso"
        case AuthErrorCode.weakPassword.rawValue:
            return "Password troppo debole (minimo 6 caratteri)"
        case AuthErrorCode.userNotFound.rawValue:
            return "Utente non trovato"
        case AuthErrorCode.networkError.rawValue:
            return "Errore di rete. Controlla la connessione."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Troppi tentativi. Riprova più tardi."
        case AuthErrorCode.userDisabled.rawValue:
            return "Account disabilitato"
        default:
            return "Errore di autenticazione: \(error.localizedDescription)"
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

enum AuthError: Error {
    case notAuthenticated
}
