import SwiftUI
import GoogleSignIn

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
        }
    }
}