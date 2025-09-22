import Foundation
// MSAL import temporarily commented out until package is added to project
// import MSAL

struct OutlookAccount: Identifiable, Codable {
    let id: String
    let email: String
    let displayName: String
    let tenantId: String?

    var shortDisplayName: String {
        return displayName.isEmpty ? email : displayName
    }
}

struct OutlookCalendar: Identifiable, Codable {
    let id: String
    let name: String
    let owner: String
    let isDefault: Bool
    let color: String?

    var displayName: String {
        return isDefault ? "\(name) (Default)" : name
    }
}

struct OutlookEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let description: String?
    let calendarId: String
    let organizer: String?

    var duration: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

class OutlookCalendarManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var currentAccount: OutlookAccount?
    @Published var availableCalendars: [OutlookCalendar] = []
    @Published var selectedCalendar: OutlookCalendar?
    @Published var showCalendarSelection = false
    @Published var showAccountManagement = false
    @Published var showCredentialInput = false
    @Published var signInError: String?
    @Published var outlookEvents: [OutlookEvent] = []

    private let selectedCalendarKey = "selectedOutlookCalendarId"
    private let currentAccountKey = "currentOutlookAccount"

    init() {
        // Temporarily disabled until MSAL package is added
        print("⚠️ OutlookCalendarManager initialized but MSAL package not available")
        loadSavedData()
    }

    func signIn() {
        print("🔵 Starting Outlook Sign-In process...")
        signInError = nil

        // Show credential input form
        showCredentialInput = true
    }

    func signInWithCredentials(email: String, password: String) {
        print("🔵 Attempting sign-in with email: \(email)")
        isLoading = true
        signInError = nil

        // Simulate authentication process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            // Simulate validation
            if self?.validateCredentials(email: email, password: password) == true {
                // Create account from provided credentials
                let userAccount = OutlookAccount(
                    id: UUID().uuidString,
                    email: email,
                    displayName: self?.extractDisplayName(from: email) ?? email,
                    tenantId: self?.extractTenant(from: email)
                )

                self?.currentAccount = userAccount
                self?.isSignedIn = true
                self?.isLoading = false
                self?.showCredentialInput = false

                // Save account info
                self?.saveAccountInfo(userAccount)

                print("✅ Outlook Sign-In successful: \(userAccount.email)")

                // After successful sign-in, fetch available calendars
                self?.fetchCalendars()
            } else {
                self?.isLoading = false
                self?.signInError = "Invalid email or password. Please check your credentials and try again."
                print("❌ Outlook Sign-In failed: Invalid credentials")
            }
        }
    }

    private func validateCredentials(email: String, password: String) -> Bool {
        // Basic validation - in real implementation this would use MSAL
        let isValidEmail = email.contains("@") && email.contains(".")
        let isValidPassword = password.count >= 6

        // For demo purposes, accept any valid-looking email and password
        return isValidEmail && isValidPassword
    }

    private func extractDisplayName(from email: String) -> String {
        let localPart = email.components(separatedBy: "@").first ?? ""
        let nameParts = localPart.components(separatedBy: ".")

        if nameParts.count >= 2 {
            let firstName = nameParts[0].capitalized
            let lastName = nameParts[1].capitalized
            return "\(firstName) \(lastName)"
        } else {
            return localPart.capitalized
        }
    }

    private func extractTenant(from email: String) -> String? {
        let domain = email.components(separatedBy: "@").last ?? ""
        let tenantName = domain.components(separatedBy: ".").first
        return tenantName?.lowercased()
    }

    func signOut() {
        let accountEmail = currentAccount?.email ?? "Unknown"

        isSignedIn = false
        currentAccount = nil
        availableCalendars = []
        selectedCalendar = nil
        showCalendarSelection = false
        showAccountManagement = false
        showCredentialInput = false
        signInError = nil

        // Clear all saved data
        UserDefaults.standard.removeObject(forKey: selectedCalendarKey)
        UserDefaults.standard.removeObject(forKey: currentAccountKey)

        print("✅ Outlook Sign-Out successful: \(accountEmail)")
    }

    func fetchCalendars() {
        print("🔵 Fetching available Outlook calendars...")
        isLoading = true

        // Simulate Microsoft Graph API call to fetch calendars
        // In real implementation: GET https://graph.microsoft.com/v1.0/me/calendars
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let currentAccount = self?.currentAccount else { return }

            // Simulated calendar data using current account
            let simulatedCalendars = [
                OutlookCalendar(
                    id: "primary",
                    name: "Calendar",
                    owner: currentAccount.email,
                    isDefault: true,
                    color: "#0078d4"
                ),
                OutlookCalendar(
                    id: "work_cal_001",
                    name: "Work Projects",
                    owner: currentAccount.email,
                    isDefault: false,
                    color: "#d83b01"
                ),
                OutlookCalendar(
                    id: "personal_cal_001",
                    name: "Personal Events",
                    owner: currentAccount.email,
                    isDefault: false,
                    color: "#107c10"
                ),
                OutlookCalendar(
                    id: "team_cal_001",
                    name: "Team Meetings",
                    owner: "team@company.com",
                    isDefault: false,
                    color: "#5c2d91"
                )
            ]

            self?.availableCalendars = simulatedCalendars
            self?.isLoading = false

            // If no calendar was previously selected, show selection UI
            if self?.selectedCalendar == nil {
                self?.showCalendarSelection = true
            }

            print("✅ Found \(simulatedCalendars.count) Outlook calendars")
        }
    }

    func selectCalendar(_ calendar: OutlookCalendar) {
        selectedCalendar = calendar
        showCalendarSelection = false

        // Save selection to UserDefaults
        if let data = try? JSONEncoder().encode(calendar) {
            UserDefaults.standard.set(data, forKey: selectedCalendarKey)
        }

        print("✅ Selected Outlook calendar: \(calendar.displayName)")
        print("✅ Outlook Calendar integration fully configured")
    }

    func showCalendarSelectionSheet() {
        if !availableCalendars.isEmpty {
            showCalendarSelection = true
        } else {
            fetchCalendars()
        }
    }

    private func loadSavedData() {
        loadCurrentAccount()
        loadSelectedCalendar()
    }

    private func loadCurrentAccount() {
        if let data = UserDefaults.standard.data(forKey: currentAccountKey),
           let account = try? JSONDecoder().decode(OutlookAccount.self, from: data) {
            currentAccount = account
            isSignedIn = true
            print("✅ Loaded previously signed-in account: \(account.email)")
        }
    }

    private func loadSelectedCalendar() {
        if let data = UserDefaults.standard.data(forKey: selectedCalendarKey),
           let calendar = try? JSONDecoder().decode(OutlookCalendar.self, from: data) {
            selectedCalendar = calendar
            print("✅ Loaded previously selected calendar: \(calendar.displayName)")
        }
    }

    private func saveAccountInfo(_ account: OutlookAccount) {
        if let data = try? JSONEncoder().encode(account) {
            UserDefaults.standard.set(data, forKey: currentAccountKey)
        }
    }

    func showAccountManagementSheet() {
        showAccountManagement = true
    }

    func switchAccount() {
        // For now, just sign out and let user sign in with different account
        signOut()
    }

    func fetchEvents(from startDate: Date = Date(), to endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()) {
        guard let selectedCalendar = selectedCalendar,
              let currentAccount = currentAccount else {
            print("❌ No calendar or account selected for Outlook events")
            return
        }

        print("🔵 Fetching Outlook events from \(selectedCalendar.displayName)...")
        isLoading = true

        // Simulate Microsoft Graph API call to fetch events
        // In real implementation: GET https://graph.microsoft.com/v1.0/me/calendars/{calendarId}/events
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            let simulatedEvents = [
                OutlookEvent(
                    id: "outlook_event_1",
                    title: "Team Standup",
                    startDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date(),
                    location: "Conference Room A",
                    description: "Daily team synchronization meeting",
                    calendarId: selectedCalendar.id,
                    organizer: currentAccount.email
                ),
                OutlookEvent(
                    id: "outlook_event_2",
                    title: "Project Review",
                    startDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()) ?? Date(),
                    location: "Teams Meeting",
                    description: "Quarterly project review and planning",
                    calendarId: selectedCalendar.id,
                    organizer: "manager@company.com"
                ),
                OutlookEvent(
                    id: "outlook_event_3",
                    title: "Client Presentation",
                    startDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()) ?? Date(),
                    location: "Client Office",
                    description: "Product demo for potential client",
                    calendarId: selectedCalendar.id,
                    organizer: currentAccount.email
                )
            ]

            self?.outlookEvents = simulatedEvents
            self?.isLoading = false
            print("✅ Fetched \(simulatedEvents.count) Outlook events")
        }
    }
}