#if canImport(UIKit)
import UIKit
import GoogleSignIn
import Observation

@MainActor
@Observable
final class GoogleAuthController {
    private(set) var currentUser: GIDGoogleUser?

    var accessToken: String? {
        currentUser?.accessToken.tokenString
    }

    var isSignedIn: Bool { currentUser != nil }

    // MARK: - Sign in / out

    func signIn() {
        guard let root = rootViewController() else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: root) { [weak self] result, _ in
            self?.currentUser = result?.user
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
    }

    // MARK: - Session restore

    func restorePreviousSignIn() async {
        currentUser = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    // MARK: - Token refresh

    /// アクセストークンが期限切れならリフレッシュして返す
    func freshAccessToken() async throws -> String? {
        guard let user = currentUser else { return nil }
        try await user.refreshTokensIfNeeded()
        return user.accessToken.tokenString
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
#endif
