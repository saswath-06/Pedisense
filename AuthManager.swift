import SwiftUI
import Supabase
import GoogleSignIn
import Combine
import CryptoKit

class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var userEmail: String = ""
    @Published var userId: String = ""
    @Published var isLoading = false
    @Published var error: String?
    
    private let client = SupabaseManager.shared.client
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        Task {
            do {
                let session = try await client.auth.session
                await MainActor.run {
                    isLoggedIn = true
                    userEmail = session.user.email ?? ""
                    userId = session.user.id.uuidString
                    SupabaseManager.shared.updateUserId(userId)
                    print("Existing session found: \(userEmail)")
                }
            } catch {
                await MainActor.run {
                    isLoggedIn = false
                    print("No existing session")
                }
            }
        }
    }
    
    // MARK: - Email Auth
    
    func signUp(email: String, password: String) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let result = try await client.auth.signUp(email: email, password: password)
                await MainActor.run {
                    isLoggedIn = true
                    userEmail = email
                    userId = result.user.id.uuidString
                    SupabaseManager.shared.updateUserId(userId)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    func signIn(email: String, password: String) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let session = try await client.auth.signIn(email: email, password: password)
                await MainActor.run {
                    isLoggedIn = true
                    userEmail = email
                    userId = session.user.id.uuidString
                    SupabaseManager.shared.updateUserId(userId)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    
    // MARK: - Google Auth
    
    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("Nonce generation failed") }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func signOut() {
            Task {
                do {
                    try await client.auth.signOut()
                    GIDSignIn.sharedInstance.signOut()
                    await MainActor.run {
                        isLoggedIn = false
                        userEmail = ""
                        userId = ""
                    }
                } catch {
                    print("Sign out error: \(error)")
                }
            }
        }
    
    func signInWithGoogle() {
        isLoading = true
        error = nil
        
        let nonce = randomNonce()
        let hashedNonce = sha256(nonce)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            error = "Cannot find root view controller"
            isLoading = false
            return
        }
        
        let config = GIDConfiguration(clientID: GIDSignIn.sharedInstance.configuration?.clientID ?? "")
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: nil, nonce: hashedNonce) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.error = "Failed to get Google ID token"
                    self.isLoading = false
                }
                return
            }
            
            Task {
                do {
                    let session = try await self.client.auth.signInWithIdToken(
                        credentials: .init(
                            provider: .google,
                            idToken: idToken,
                            nonce: nonce
                        )
                    )
                    
                    await MainActor.run {
                        self.isLoggedIn = true
                        self.userEmail = session.user.email ?? user.profile?.email ?? ""
                        self.userId = session.user.id.uuidString
                        SupabaseManager.shared.updateUserId(self.userId)
                        self.isLoading = false
                        print("Google sign in success: \(self.userEmail)")
                    }
                } catch {
                    await MainActor.run {
                        self.error = error.localizedDescription
                        self.isLoading = false
                        print("Supabase Google auth error: \(error)")
                    }
                }
            }
        }
    }
}
