import SwiftUI
import GoogleSignIn
import MSAL

@main
struct CalAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                          let plist = NSDictionary(contentsOfFile: path),
                          let clientId = plist["CLIENT_ID"] as? String else {
                        print("❌ GoogleService-Info.plist not found or missing CLIENT_ID")
                        return
                    }

                    print("🔍 Bundle ID from app: \(Bundle.main.bundleIdentifier ?? "unknown")")
                    print("🔍 Client ID from plist: \(clientId)")
                    if let bundleId = plist["BUNDLE_ID"] as? String {
                        print("🔍 Bundle ID from plist: \(bundleId)")
                    }

                    let configuration = GIDConfiguration(clientID: clientId)

                    GIDSignIn.sharedInstance.configuration = configuration
                    print("✅ Google Sign-In configured")
                }
                .onOpenURL { url in
                    print("🔵 App received URL: \(url)")
                    print("🔵 URL scheme: \(url.scheme ?? "none")")

                    // Handle Google Sign-In callback
                    if url.scheme == "com.googleusercontent.apps.43431862733-2ath0e407kaj4m8n8faj5nt6orhf6vlo" {
                        print("🔵 Handling Google Sign-In callback")
                        GIDSignIn.sharedInstance.handle(url)
                    }

                    // Handle MSAL callback - check for msauth scheme (case-insensitive)
                    if url.scheme?.lowercased().hasPrefix("msauth") == true {
                        print("🔵 Handling MSAL callback for scheme: \(url.scheme ?? "")")
                        MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                    }
                }
        }
    }
}
