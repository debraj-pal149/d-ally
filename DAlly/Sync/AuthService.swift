import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn
import Observation
import UIKit

struct AppUser: Equatable {
    var uid: String
    var displayName: String?
    var email: String?
    var photoURL: URL?
    var providers: [String]

    var usesAppleRelay: Bool {
        email?.hasSuffix("privaterelay.appleid.com") == true
    }

    var title: String {
        if let displayName, !displayName.isEmpty { return displayName }
        if usesAppleRelay { return "Apple ID" }
        return email ?? "Signed in"
    }

    var subtitle: String? {
        if usesAppleRelay { return "Apple ID" }
        if let email, email != title { return email }
        return nil
    }
}

enum AuthError: LocalizedError {
    case cancelled
    case missingToken
    case needsRecentLogin
    case noPresenter

    var errorDescription: String? {
        switch self {
        case .cancelled: return nil
        case .missingToken: return "Sign-in did not finish. Try again."
        case .needsRecentLogin: return AppCopy.profileDeleteRecent
        case .noPresenter: return "Sign-in could not open. Try again."
        }
    }
}

struct PendingMergeChoice: Equatable {
    var uid: String
    var habitCount: Int
}

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var user: AppUser?
    private(set) var isBusy = false
    var pendingMergeChoice: PendingMergeChoice?

    private var listenerHandle: AuthStateDidChangeListenerHandle?
    private var appleCoordinator: AppleSignInCoordinator?
    private var handledUID: String?

    private init() {}

    var isSignedIn: Bool { user != nil }

    func configure() {
        guard listenerHandle == nil else { return }
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                self?.handleAuthChange(firebaseUser)
            }
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: Sign in

    func signInWithGoogle() async throws {
        guard let presenter = Self.topViewController() else { throw AuthError.noPresenter }
        isBusy = true
        defer { isBusy = false }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw AuthError.cancelled
        }
        guard let idToken = result.user.idToken?.tokenString else { throw AuthError.missingToken }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }

    func signInWithApple() async throws {
        isBusy = true
        defer { isBusy = false }

        let coordinator = AppleSignInCoordinator()
        appleCoordinator = coordinator
        defer { appleCoordinator = nil }

        let outcome = try await coordinator.signIn()
        let credential = OAuthProvider.appleCredential(
            withIDToken: outcome.idToken,
            rawNonce: outcome.nonce,
            fullName: outcome.fullName
        )
        let result = try await Auth.auth().signIn(with: credential)

        // Apple sends the name only on the first sign-in, so keep it on the account.
        if (result.user.displayName ?? "").isEmpty,
           let components = outcome.fullName {
            let name = PersonNameComponentsFormatter().string(from: components)
            if !name.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = name
                try? await change.commitChanges()
                user = Self.appUser(from: result.user)
                upsertProfile(Self.appUser(from: result.user))
            }
        }
    }

    // MARK: Sign out and delete

    func signOut(keepLocalData: Bool) throws {
        SyncEngine.shared.stop()
        if !keepLocalData {
            SyncEngine.shared.wipeLocalData()
            UserDefaults.standard.removeObject(forKey: AppStorageKey.localDataOwnerUID)
        }
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    /// Removes the cloud copy and the account. Habits on this phone stay.
    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        if let lastSignIn = firebaseUser.metadata.lastSignInDate,
           Date().timeIntervalSince(lastSignIn) > 4 * 60 {
            throw AuthError.needsRecentLogin
        }
        isBusy = true
        defer { isBusy = false }

        SyncEngine.shared.stop()
        do {
            try await SyncEngine.shared.deleteCloudData(uid: firebaseUser.uid)
            try await firebaseUser.delete()
        } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            SyncEngine.shared.start(uid: firebaseUser.uid)
            throw AuthError.needsRecentLogin
        }
        SyncEngine.clearMergeMarker(uid: firebaseUser.uid)
        UserDefaults.standard.removeObject(forKey: AppStorageKey.localDataOwnerUID)
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: Merge choice

    func resolveMergeChoice(addLocal: Bool) {
        guard let choice = pendingMergeChoice else { return }
        pendingMergeChoice = nil
        if !addLocal {
            SyncEngine.shared.wipeLocalData()
        }
        UserDefaults.standard.removeObject(forKey: AppStorageKey.localDataOwnerUID)
        SyncEngine.shared.start(uid: choice.uid)
    }

    // MARK: Internals

    private func handleAuthChange(_ firebaseUser: User?) {
        guard let firebaseUser else {
            user = nil
            handledUID = nil
            SyncEngine.shared.stop()
            return
        }
        let appUser = Self.appUser(from: firebaseUser)
        user = appUser
        guard handledUID != firebaseUser.uid else { return }
        handledUID = firebaseUser.uid
        upsertProfile(appUser)
        beginSync(for: firebaseUser.uid)
    }

    private func beginSync(for uid: String) {
        let owner = UserDefaults.standard.string(forKey: AppStorageKey.localDataOwnerUID)
        let localCount = SyncEngine.shared.localHabitCount()
        if let owner, owner != uid, localCount > 0, !SyncEngine.mergeDone(uid: uid) {
            pendingMergeChoice = PendingMergeChoice(uid: uid, habitCount: localCount)
            return
        }
        SyncEngine.shared.start(uid: uid)
    }

    private func upsertProfile(_ appUser: AppUser) {
        var data: [String: Any] = [
            "providers": appUser.providers,
            "updatedAt": Date(),
            "lastDevice": UIDevice.current.name,
            "schema": CloudCodec.schemaVersion,
        ]
        if let displayName = appUser.displayName { data["displayName"] = displayName }
        if let email = appUser.email { data["email"] = email }
        if let photoURL = appUser.photoURL { data["photoURL"] = photoURL.absoluteString }
        Firestore.firestore().collection("users").document(appUser.uid).setData(data, merge: true)
    }

    private static func appUser(from firebaseUser: User) -> AppUser {
        AppUser(
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName,
            email: firebaseUser.email,
            photoURL: firebaseUser.photoURL,
            providers: firebaseUser.providerData.map(\.providerID)
        )
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
