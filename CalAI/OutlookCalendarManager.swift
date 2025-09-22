import Foundation
import MSAL

class OutlookCalendarManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false

    private var applicationContext: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?

    private let scopes = ["https://graph.microsoft.com/calendars.readwrite"]

    init() {
        setupMSAL()
        checkSignInStatus()
    }

    private func setupMSAL() {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "MSALClientID") as? String else {
            print("❌ MSALClientID not found in Info.plist")
            return
        }

        do {
            let authority = try MSALAADAuthority(url: URL(string: "https://login.microsoftonline.com/common")!)
            let config = MSALPublicClientApplicationConfig(clientId: clientId, redirectUri: "msauth.com.calai.CalAI://auth", authority: authority)
            self.applicationContext = try MSALPublicClientApplication(configuration: config)
            print("✅ MSAL configured successfully")
        } catch {
            print("❌ Failed to create MSAL application: \(error)")
        }
    }

    private func checkSignInStatus() {
        guard let applicationContext = applicationContext else { return }

        do {
            let accounts = try applicationContext.allAccounts()
            if let account = accounts.first {
                self.currentAccount = account
                self.isSignedIn = true
                print("✅ Outlook user already signed in: \(account.username ?? "")")
            } else {
                self.isSignedIn = false
                print("❌ No Outlook user signed in")
            }
        } catch {
            print("❌ Failed to get accounts: \(error)")
            self.isSignedIn = false
        }
    }

    func signIn() {
        guard let applicationContext = applicationContext else {
            print("❌ MSAL application context not available")
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            print("❌ No presenting view controller found")
            return
        }

        print("🔵 Starting Outlook Sign-In process...")
        isLoading = true

        let webViewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
        let interactiveParameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webViewParameters)

        applicationContext.acquireToken(with: interactiveParameters) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    print("❌ Outlook Sign-In error: \(error)")
                    return
                }

                guard let result = result else {
                    print("❌ No result returned from Outlook Sign-In")
                    return
                }

                self?.currentAccount = result.account
                self?.isSignedIn = true
                print("✅ Outlook Sign-In successful: \(result.account.username ?? "")")
            }
        }
    }

    func signOut() {
        guard let applicationContext = applicationContext,
              let account = currentAccount else {
            print("❌ No account to sign out")
            return
        }

        do {
            let signoutParameters = MSALSignoutParameters(webviewParameters: MSALWebviewParameters(authPresentationViewController: UIViewController()))
            try applicationContext.signout(with: account, signoutParameters: signoutParameters) { [weak self] success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Outlook Sign-Out error: \(error)")
                    } else {
                        self?.isSignedIn = false
                        self?.currentAccount = nil
                        print("✅ Outlook Sign-Out successful")
                    }
                }
            }
        } catch {
            print("❌ Failed to sign out: \(error)")
        }
    }

    private func getAccessToken(completion: @escaping (String?) -> Void) {
        guard let applicationContext = applicationContext,
              let account = currentAccount else {
            completion(nil)
            return
        }

        let silentParameters = MSALSilentTokenParameters(scopes: scopes, account: account)

        applicationContext.acquireTokenSilent(with: silentParameters) { result, error in
            if let error = error {
                print("❌ Failed to get access token: \(error)")
                completion(nil)
                return
            }

            completion(result?.accessToken)
        }
    }
}