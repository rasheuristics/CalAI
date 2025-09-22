import Foundation
import GoogleSignIn

class GoogleCalendarManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false

    init() {
        checkSignInStatus()
    }

    private func checkSignInStatus() {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            isSignedIn = true
            print("✅ Google user already signed in: \(currentUser.profile?.email ?? "")")
        } else {
            isSignedIn = false
            print("❌ No Google user signed in")
        }
    }

    func signIn() {
        print("🔵 Starting Google Sign-In process...")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let presentingViewController = window.rootViewController else {
            print("❌ No presenting view controller found")
            return
        }

        print("✅ Found presenting view controller: \(presentingViewController)")
        isLoading = true

        let scopes = ["https://www.googleapis.com/auth/calendar"]
        print("🔵 Requesting scopes: \(scopes)")

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: scopes) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("❌ Google Sign-In error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    return
                }

                guard let user = result?.user else {
                    print("❌ No user returned from Google Sign-In")
                    return
                }

                self?.isSignedIn = true
                print("✅ Google Sign-In successful: \(user.profile?.email ?? "")")
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        print("✅ Google Sign-Out successful")
    }
}