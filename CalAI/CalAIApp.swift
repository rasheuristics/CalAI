import SwiftUI
import GoogleSignIn
import MSAL
import UserNotifications
import CoreLocation
import UIKit

@main
struct HeuCalendarAIApp: App {
    init() {
        // Initialize crash reporting first
        setupCrashReporting()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Defer Google Sign-In setup to avoid blocking UI
                    DispatchQueue.global(qos: .userInitiated).async {
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

                        DispatchQueue.main.async {
                            GIDSignIn.sharedInstance.configuration = configuration
                            print("✅ Google Sign-In configured")
                        }
                    }

                    // Defer manager initialization to avoid blocking UI
                    DispatchQueue.main.async {
                        // Initialize managers (but don't request permissions yet)
                        // Permissions will be requested during onboarding
                        let _ = SmartNotificationManager.shared
                        let _ = TravelTimeManager.shared
                    }
                }
                .onOpenURL { url in
                    print("🔵 App received URL: \(url)")
                    print("🔵 URL scheme: \(url.scheme ?? "none")")

                    // Handle Google Sign-In callback
                    if url.scheme == "com.googleusercontent.apps.11336654779-aoaksvj4o8cle0vhca7cmq8ej6vdeujh" {
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

    // MARK: - Crash Reporting Setup

    private func setupCrashReporting() {
        // Initialize crash reporter
        let crashReporter = CrashReporter.shared

        // Check user preference
        let isEnabled = UserDefaults.standard.object(forKey: "crashReportingEnabled") as? Bool ?? true
        crashReporter.setEnabled(isEnabled)

        // Set app context
        crashReporter.setCustomValue(Bundle.main.appVersion, forKey: "app_version")
        crashReporter.setCustomValue(Bundle.main.buildNumber, forKey: "build_number")

        // Log app launch
        crashReporter.leaveBreadcrumb("App launched")

        print("✅ Crash reporting initialized (enabled: \(isEnabled))")
    }
}
