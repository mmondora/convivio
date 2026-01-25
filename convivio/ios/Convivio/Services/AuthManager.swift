//
//  AuthManager.swift
//  Convivio
//
//  Gestione autenticazione con Firebase Auth
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var error: AuthError?
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let db = Firestore.firestore()
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let user = user {
                    self.user = user
                    self.isAuthenticated = true
                    await self.ensureUserDocument(user)
                } else {
                    self.user = nil
                    self.isAuthenticated = false
                }
                
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign In Methods
    
    func signInWithApple() async {
        // Apple Sign In implementation would go here
        // Using ASAuthorizationController
    }
    
    func signInWithGoogle() async {
        // Google Sign In implementation would go here
    }
    
    func signInWithEmail(email: String, password: String) async {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await ensureUserDocument(result.user)
        } catch {
            self.error = AuthError(message: error.localizedDescription)
        }
    }
    
    func signUpWithEmail(email: String, password: String, displayName: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            
            await createUserDocument(result.user, displayName: displayName)
        } catch {
            self.error = AuthError(message: error.localizedDescription)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            self.error = AuthError(message: error.localizedDescription)
        }
    }
    
    func resetPassword(email: String) async {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            self.error = AuthError(message: error.localizedDescription)
        }
    }
    
    // MARK: - User Document Management
    
    private func ensureUserDocument(_ user: User) async {
        let docRef = db.collection("users").document(user.uid)
        
        do {
            let doc = try await docRef.getDocument()
            if !doc.exists {
                await createUserDocument(user, displayName: user.displayName ?? "Utente")
            }
        } catch {
            print("Error checking user document: \(error)")
        }
    }
    
    private func createUserDocument(_ user: User, displayName: String) async {
        let userData: [String: Any] = [
            "email": user.email ?? "",
            "displayName": displayName,
            "photoUrl": user.photoURL?.absoluteString ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(user.uid).setData(userData)
        } catch {
            print("Error creating user document: \(error)")
        }
    }
    
    // MARK: - Apple Sign In Helpers
    
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    func handleAppleSignIn(authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            self.error = AuthError(message: "Errore durante l'autenticazione Apple")
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        do {
            let result = try await Auth.auth().signIn(with: credential)
            
            // Get display name from Apple credential
            var displayName = "Utente"
            if let fullName = appleIDCredential.fullName {
                let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                if !parts.isEmpty {
                    displayName = parts.joined(separator: " ")
                }
            }
            
            await ensureUserDocument(result.user)
        } catch {
            self.error = AuthError(message: error.localizedDescription)
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

// MARK: - Auth Error

struct AuthError: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - User Extension

extension User {
    var displayNameOrEmail: String {
        displayName ?? email ?? "Utente"
    }
}
